import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/image_picker_section.dart';
import '../widgets/custom_text_field.dart';
import '../models/wardrobe_item.dart';
import '../services/wardrobe_service.dart';

class AddItemScreen extends StatefulWidget {
  final VoidCallback onBack;
  final WardrobeItem? initialItem;

  const AddItemScreen({super.key, required this.onBack, this.initialItem});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Color? _selectedColor;
  final WardrobeService _wardrobeService = WardrobeService();
  final ImagePicker _imagePicker = ImagePicker();

  // Color picker's preset palette (approx 30 common clothing colors arranged roughly by hue circle)
  static const List<Color> _pickerColors = [
    Color(0xFFB71C1C), // deep red
    Color(0xFFD32F2F), // red
    Color(0xFFEF5350), // light red
    Color(0xFFFF7043), // coral
    Color(0xFFFB8C00), // orange
    Color(0xFFF9A825), // mustard
    Color(0xFFFDD835), // yellow
    Color(0xFFAFB42B), // lime olive
    Color(0xFF7CB342), // green
    Color(0xFF4CAF50), // medium green
    Color(0xFF388E3C), // dark green
    Color(0xFF009688), // teal
    Color(0xFF00ACC1), // cyan
    Color(0xFF0288D1), // light blue
    Color(0xFF1976D2), // royal blue
    Color(0xFF303F9F), // indigo
    Color(0xFF512DA8), // purple
    Color(0xFF6A1B9A), // deep purple
    Color(0xFFD81B60), // pink
    Color(0xFF8E24AA), // magenta
    Color(0xFF6D4C41), // brown
    Color(0xFF795548), // chestnut
    Color(0xFFBDBDBD), // light grey
    Color(0xFF9E9E9E), // grey
    Color(0xFF616161), // charcoal
    Color(0xFF455A64), // slate
    Color(0xFF263238), // dark slate
    Color(0xFF000000), // black
    Color(0xFFFFFFFF), // white
    Color(0xFFFFE0B2), // beige
  ];

  String? _selectedImagePath;
  bool _isLoading = false;

  String _selectedCategory = 'Tops';
  String _selectedSubcategory = 'T-Shirts';
  String _selectedFormality = 'Casual';
  List<dynamic> _rawCategories = [];
  List<String> _categories = [];
  List<String> _subcategories = [];
  final Map<String, String> _subLabelToId = {}; // map label -> id for subtypes

  // Attributes data & options
  Map<String, dynamic> _subtypesAttributes = {};
  Set<String> _materialsOptions = {};
  Set<String> _formalityOptions = {};
  Set<String> _styleTagsOptions = {};
  Set<String> _fitOptions = {};
  Map<String, List<String>> _activityGroups = {};
  List<String> _activityGroupOrder = [];
  final TextEditingController _optimalSearchController =
      TextEditingController();
  final TextEditingController _unsuitableSearchController =
      TextEditingController();

  // Selected attribute values
  final Set<String> _selectedMaterials = {};
  final Set<String> _selectedStyleTags = {};
  final Set<String> _selectedOptimalActivities = {};
  final Set<String> _selectedUnsuitable = {};
  String _selectedFit = '';
  int _selectedWarmth = 1;
  int _selectedWater = 0;
  int _selectedWind = 0;
  int _selectedBreath = 5;
  int _selectedStretch = 2;
  final TextEditingController _minTempController = TextEditingController();
  final TextEditingController _maxTempController = TextEditingController();

  final List<String> _formalityLevels = [
    'Casual',
    'Smart Casual',
    'Business',
    'Formal',
  ];

  @override
  void initState() {
    super.initState();
    // If opened in edit mode, prefill synchronous controllers so fields display immediately
    if (widget.initialItem != null) {
      _nameController.text = widget.initialItem!.name;
      _descriptionController.text = widget.initialItem!.description;
      _selectedImagePath = widget.initialItem!.imagePath;
      _selectedCategory = widget.initialItem!.category;
      _selectedSubcategory = widget.initialItem!.subcategory;
      _selectedFormality = widget.initialItem!.formalityLevel;

      // Try to parse color if provided as hex (#rrggbb)
      final cstr = widget.initialItem!.color.trim();
      if (cstr.startsWith('#') && (cstr.length == 7 || cstr.length == 9)) {
        try {
          final hex = cstr.replaceFirst('#', '');
          final value = int.parse(hex, radix: 16);
          _selectedColor = Color(
            cstr.length == 7 ? (0xFF000000 | value) : value,
          );
        } catch (_) {}
      }
    }

    _initAsync();
  }

  Future<void> _initAsync() async {
    await _loadSubtypesAttributes();
    await _loadCategoryData();
    await _loadActivityOptions();

    // If we were opened in edit mode, pre-populate the form from the initial item
    if (widget.initialItem != null) {
      _populateFromInitial(widget.initialItem!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _optimalSearchController.dispose();
    _unsuitableSearchController.dispose();
    _minTempController.dispose();
    _maxTempController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    _clearForm();
    widget.onBack();
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedImagePath = null;
      _selectedColor = null;
      _selectedCategory = 'Tops';
      _selectedSubcategory = 'T-Shirts';
      _selectedFormality = 'Casual';

      _selectedMaterials.clear();
      _selectedStyleTags.clear();
      _selectedOptimalActivities.clear();
      _selectedUnsuitable.clear();
      _optimalSearchController.clear();
      _unsuitableSearchController.clear();
      _selectedFit = '';
      _selectedWarmth = 1;
      _selectedWater = 0;
      _selectedWind = 0;
      _selectedBreath = 5;
      _selectedStretch = 2;
      _minTempController.clear();
      _maxTempController.clear();
    });
  }

  Future<void> _handleAddToWardrobe() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the item')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final tags = widget.initialItem != null
          ? widget.initialItem!.tags
          : <String>[];

      final isEditing = widget.initialItem != null;
      final item = WardrobeItem(
        id: isEditing
            ? widget.initialItem!.id
            : DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
        color: _selectedColor != null
            ? '#${_selectedColor!.value.toRadixString(16).padLeft(8, '0').substring(2)}'
            : '',
        formalityLevel: _selectedFormality,
        tags: tags,
        attributes: {
          'materials': _selectedMaterials.toList(),
          'warmth_level': _selectedWarmth,
          'water_resistance': _selectedWater,
          'wind_resistance': _selectedWind,
          'breathability': _selectedBreath,
          'stretch': _selectedStretch,
          'formality': _selectedFormality,
          'style_tags': _selectedStyleTags.toList(),
          'fit': _selectedFit,
        },
        usageConstraints: {
          'weather_min_temp': int.tryParse(_minTempController.text.trim()),
          'weather_max_temp': int.tryParse(_maxTempController.text.trim()),
          'optimal_activities': _selectedOptimalActivities.toList(),
          'unsuitable_for': _selectedUnsuitable.toList(),
        },
        imagePath: _selectedImagePath,
        createdAt: isEditing ? widget.initialItem!.createdAt : DateTime.now(),
        isFavorite: isEditing ? (widget.initialItem!.isFavorite) : false,
        isInWash: isEditing ? (widget.initialItem!.isInWash) : false,
      );

      final success = isEditing
          ? await _wardrobeService.updateWardrobeItem(item)
          : await _wardrobeService.addWardrobeItem(item);

      if (!mounted) return;

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? 'Item updated successfully!'
                    : 'Item added to wardrobe successfully!',
              ),
            ),
          );
        }
        _clearForm();
        if (mounted) {
          widget.onBack();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add/update item. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCameraPress() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (!mounted) return;
      if (image != null) {
        await _saveImage(image);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing camera: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleGalleryPress() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (!mounted) return;
      if (image != null) {
        await _saveImage(image);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing gallery: ${e.toString()}')),
      );
    }
  }

  Future<void> _openColorDialog(BuildContext context) async {
    final Color? picked = await showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: _pickerColors.map((c) {
                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop(c);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedColor = picked;
      });
    }
  }

  Future<void> _openSubcategoryChooser(BuildContext context) async {
    final subtypesData = await loadSubtypesJson();
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final query = controller.text.trim().toLowerCase();

            List<Widget> buildGroups() {
              final groups = _rawCategories.cast<Map<String, dynamic>>();
              final List<Widget> widgets = [];
              for (final g in groups) {
                final gid = g['id'] as String;
                final label = g['label'] as String;
                final items = (subtypesData['subtypes'][gid] as List)
                    .cast<Map<String, dynamic>>();
                final filteredItems = query.isEmpty
                    ? items
                    : items.where((s) {
                        final lab = (s['label'] as String).toLowerCase();
                        return lab.contains(query) ||
                            label.toLowerCase().contains(query);
                      }).toList();
                if (filteredItems.isEmpty) continue;

                widgets.add(
                  ExpansionTile(
                    title: Text(label),
                    children: filteredItems.map((s) {
                      final subLabel = s['label'] as String;
                      final subId = s['id'] as String;
                      return ListTile(
                        title: Text(subLabel),
                        onTap: () {
                          // set chosen subcategory and related category
                          setState(() {
                            _selectedSubcategory = subLabel;
                            _selectedCategory = label;
                            _subLabelToId[subLabel] = subId;
                          });

                          // apply defaults if available
                          if (_subtypesAttributes.isNotEmpty) {
                            _applyDefaultsForSubcategory(subId);
                          }

                          Navigator.of(context).pop();
                        },
                      );
                    }).toList(),
                  ),
                );
              }
              return widgets;
            }

            return AlertDialog(
              title: const Text('Select Subcategory'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        filled: false,
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search categories or subcategories',
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: ListView(children: buildGroups())),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveImage(XFile image) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = File('${directory.path}/$fileName');

      await File(image.path).copy(savedImage.path);

      if (!mounted) return;
      setState(() {
        _selectedImagePath = savedImage.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadCategoryData() async {
    // Load both JSON files
    final categoriesData = await loadCategoriesJson();
    final subtypesData = await loadSubtypesJson();

    final categoriesJson = categoriesData['categories'] as List;

    // Flatten all groups into a single list
    final allGroups = categoriesJson
        .expand((category) => category['groups'] as List)
        .toList();

    setState(() {
      // Save raw groups so we can map back label → id
      _rawCategories = allGroups;

      // TOP-LEVEL CATEGORIES = all group labels
      _categories = allGroups.map((g) => g['label'] as String).toList();

      // Select category - respect initial item if present
      if (widget.initialItem != null &&
          _categories.contains(widget.initialItem!.category)) {
        _selectedCategory = widget.initialItem!.category;
      } else {
        _selectedCategory = _categories.first;
      }

      // Get selected group ID
      final selectedGroup = allGroups.firstWhere(
        (g) => g['label'] == _selectedCategory,
      );
      final selectedGroupId = selectedGroup['id'];

      // SUBCATEGORIES = entries in subtypes.json for the group id
      final subtypeList = (subtypesData['subtypes'][selectedGroupId] as List);
      _subLabelToId.clear();
      _subcategories = subtypeList.map((s) {
        final id = s['id'] as String;
        final label = s['label'] as String;
        _subLabelToId[label] = id;
        return label;
      }).toList();

      

      // If we have an initial item, try to pick that subcategory if it exists
      if (widget.initialItem != null &&
          _subcategories.contains(widget.initialItem!.subcategory)) {
        _selectedSubcategory = widget.initialItem!.subcategory;
      } else {
        _selectedSubcategory = _subcategories.first;
      }

      print("Selected subcategory: $_selectedSubcategory");
      print("Subcategory mapping:");
      print(_subLabelToId);
      print(_subtypesAttributes);

      // apply defaults if we already loaded attributes
      final initialId = _subLabelToId[_selectedSubcategory];
      if (initialId != null && _subtypesAttributes.isNotEmpty) {
        _applyDefaultsForSubcategory(initialId);
      }
    });
  }

  Future<Map<String, dynamic>> loadCategoriesJson() async {
    final String response = await rootBundle.loadString(
      'assets/categories.json',
    ); // adjust path if needed
    final data = json.decode(response) as Map<String, dynamic>;
    return data;
  }

  Future<Map<String, dynamic>> loadSubtypesJson() async {
    final String response = await rootBundle.loadString(
      'assets/subcategories.json',
    );
    return json.decode(response);
  }

  Future<void> _loadSubtypesAttributes() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/subtypes_attributes.json',
      );
      final Map<String, dynamic> data =
          json.decode(response) as Map<String, dynamic>;
      final Set<String> mats = {};
      final Set<String> forms = {};
      final Set<String> tags = {};
      final Set<String> fits = {};

      data.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          final attrs = (v['attributes'] as Map<String, dynamic>?) ?? {};
          final materials = attrs['materials'] as List<dynamic>?;
          if (materials != null)
            mats.addAll(materials.map((e) => e.toString()));
          final form = attrs['formality']?.toString();
          if (form != null) forms.add(form);
          final sty = attrs['style_tags'] as List<dynamic>?;
          if (sty != null) tags.addAll(sty.map((e) => e.toString()));
          final fit = attrs['fit']?.toString();
          if (fit != null) fits.add(fit);
        }
      });

      setState(() {
        _subtypesAttributes = data;
        _materialsOptions = mats;
        _formalityOptions = forms;
        _styleTagsOptions = tags;
        _fitOptions = fits;
      });
    } catch (e) {
      print('Error loading subtype attributes: $e');
    }
  }

  Future<void> _loadActivityOptions() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/activities.json',
      );
      final Map<String, dynamic> data =
          json.decode(response) as Map<String, dynamic>;
      final Map<String, List<String>> groups = {};
      if (data.containsKey('activities')) {
        final activities = data['activities'] as Map<String, dynamic>;
        activities.forEach((category, groupMap) {
          if (groupMap is Map<String, dynamic>) {
            groupMap.forEach((groupKey, subList) {
              if (subList is List) {
                groups.putIfAbsent(groupKey, () => []);
                groups[groupKey]!.addAll(subList.map((e) => e.toString()));
              }
            });
          }
        });
      }
      // remove duplicates and sort
      final cleaned = <String, List<String>>{};
      groups.forEach((k, v) {
        final unique = v.toSet().toList()..sort();
        cleaned[k] = unique;
      });

      setState(() {
        _activityGroups = cleaned;
        _activityGroupOrder = cleaned.keys.toList()..sort();
      });
    } catch (e) {
      print('Failed to load activity options: $e');
    }
  }

  void _applyDefaultsForSubcategory(String subId) {
    final entry = _subtypesAttributes[subId] as Map<String, dynamic>?;
    if (entry == null) return;
    final attrs = (entry['attributes'] as Map<String, dynamic>?) ?? {};
    final usage = (entry['usage_constraints'] as Map<String, dynamic>?) ?? {};

    setState(() {
      _selectedMaterials.clear();
      final mats =
          (attrs['materials'] as List<dynamic>?)?.map((e) => e.toString()) ??
          [];
      _selectedMaterials.addAll(mats);

      _selectedStyleTags.clear();
      final tags =
          (attrs['style_tags'] as List<dynamic>?)?.map((e) => e.toString()) ??
          [];
      _selectedStyleTags.addAll(tags);

      final formDefault = (attrs['formality']?.toString() ?? '').trim();
      if (formDefault.isNotEmpty) {
        final match = _formalityLevels.firstWhere(
          (f) => f.toLowerCase() == formDefault.toLowerCase(),
          orElse: () => '',
        );
        if (match.isNotEmpty) _selectedFormality = match;
      }

      final fitDefault = (attrs['fit']?.toString() ?? '').trim();
      if (fitDefault.isNotEmpty) {
        final matchFit = _fitOptions.firstWhere(
          (f) => f.toLowerCase() == fitDefault.toLowerCase(),
          orElse: () => '',
        );
        if (matchFit.isNotEmpty) _selectedFit = matchFit;
      }

      _selectedWarmth = (attrs['warmth_level'] is num)
          ? (attrs['warmth_level'] as num).toInt()
          : _selectedWarmth;
      _selectedWater = (attrs['water_resistance'] is num)
          ? (attrs['water_resistance'] as num).toInt()
          : _selectedWater;
      _selectedWind = (attrs['wind_resistance'] is num)
          ? (attrs['wind_resistance'] as num).toInt()
          : _selectedWind;
      _selectedBreath = (attrs['breathability'] is num)
          ? (attrs['breathability'] as num).toInt()
          : _selectedBreath;
      _selectedStretch = (attrs['stretch'] is num)
          ? (attrs['stretch'] as num).toInt()
          : _selectedStretch;

      _minTempController.text = usage['weather_min_temp']?.toString() ?? '';
      _maxTempController.text = usage['weather_max_temp']?.toString() ?? '';

      _selectedOptimalActivities.clear();
      final optimal =
          (usage['optimal_activities'] as List<dynamic>?)?.map(
            (e) => e.toString(),
          ) ??
          [];
      _selectedOptimalActivities.addAll(optimal);

      _selectedUnsuitable.clear();
      final unsuitable =
          (usage['unsuitable_for'] as List<dynamic>?)?.map(
            (e) => e.toString(),
          ) ??
          [];
      _selectedUnsuitable.addAll(unsuitable);

      // If attributes contain a color hint, set swatch
      final colorHint = (attrs['color'] ?? usage['color'])?.toString();
      if (colorHint != null && colorHint.startsWith('#')) {
        try {
          final hex = colorHint.replaceFirst('#', '');
          final value = int.parse(hex, radix: 16);
          _selectedColor = Color(
            colorHint.length == 7 ? (0xFF000000 | value) : value,
          );
        } catch (_) {}
      }
    });
  }

  void _populateFromInitial(WardrobeItem item) {
    // Basic text fields
    _nameController.text = item.name;
    _descriptionController.text = item.description;
    _selectedImagePath = item.imagePath;

    // Try to parse color into swatch (hex like #RRGGBB)
    final cstr = item.color.trim();
    if (cstr.startsWith('#') && (cstr.length == 7 || cstr.length == 9)) {
      try {
        final hex = cstr.replaceFirst('#', '');
        final value = int.parse(hex, radix: 16);
        _selectedColor = Color(cstr.length == 7 ? (0xFF000000 | value) : value);
      } catch (_) {
        _selectedColor = null;
      }
    }

    // Basic selections
    _selectedCategory = item.category;
    _selectedSubcategory = item.subcategory;
    _selectedFormality = item.formalityLevel;

    // First apply defaults from subtypes_attributes.json if available
    final id = _subLabelToId[_selectedSubcategory];
    if (id != null && _subtypesAttributes.isNotEmpty) {
      _applyDefaultsForSubcategory(id);
    }

    // Then overwrite with stored attributes from the item
    final attrs = item.attributes ?? {};
    if (attrs.isNotEmpty) {
      final mats =
          (attrs['materials'] as List<dynamic>?)?.map((e) => e.toString()) ??
          [];
      if (mats.isNotEmpty) {
        _selectedMaterials.clear();
        _selectedMaterials.addAll(mats);
      }

      final sty =
          (attrs['style_tags'] as List<dynamic>?)?.map((e) => e.toString()) ??
          [];
      if (sty.isNotEmpty) {
        _selectedStyleTags.clear();
        _selectedStyleTags.addAll(sty);
      }

      if (attrs.containsKey('fit')) {
        _selectedFit = attrs['fit']?.toString() ?? _selectedFit;
      }
      if (attrs.containsKey('warmth_level')) {
        _selectedWarmth = (attrs['warmth_level'] as num).toInt();
      }
      if (attrs.containsKey('water_resistance')) {
        _selectedWater = (attrs['water_resistance'] as num).toInt();
      }
      if (attrs.containsKey('wind_resistance')) {
        _selectedWind = (attrs['wind_resistance'] as num).toInt();
      }
      if (attrs.containsKey('breathability')) {
        _selectedBreath = (attrs['breathability'] as num).toInt();
      }
      if (attrs.containsKey('stretch')) {
        _selectedStretch = (attrs['stretch'] as num).toInt();
      }
      if (attrs.containsKey('formality')) {
        final formStored = attrs['formality']?.toString() ?? '';
        if (formStored.isNotEmpty) {
          final match = _formalityLevels.firstWhere(
            (f) => f.toLowerCase() == formStored.toLowerCase(),
            orElse: () => '',
          );
          if (match.isNotEmpty) _selectedFormality = match;
        }
      }
    }

    final usage = item.usageConstraints ?? {};
    if (usage.isNotEmpty) {
      if (usage.containsKey('weather_min_temp')) {
        _minTempController.text = usage['weather_min_temp']?.toString() ?? '';
      }
      if (usage.containsKey('weather_max_temp')) {
        _maxTempController.text = usage['weather_max_temp']?.toString() ?? '';
      }

      if (usage.containsKey('optimal_activities')) {
        final optimal =
            (usage['optimal_activities'] as List<dynamic>?)?.map(
              (e) => e.toString(),
            ) ??
            [];
        _selectedOptimalActivities.clear();
        _selectedOptimalActivities.addAll(optimal);
      }

      if (usage.containsKey('unsuitable_for')) {
        final unsuitable =
            (usage['unsuitable_for'] as List<dynamic>?)?.map(
              (e) => e.toString(),
            ) ??
            [];
        _selectedUnsuitable.clear();
        _selectedUnsuitable.addAll(unsuitable);
      }
    }

    setState(() {});
  }

  // Add a dropdown for selecting formality level
  Widget _buildFormalityDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedFormality,
      decoration: const InputDecoration(labelText: 'Formality Level'),
      items: _formalityLevels.map((level) {
        return DropdownMenuItem<String>(value: level, child: Text(level));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedFormality = value!;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.initialItem != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isEditing ? 'Edit Clothing' : 'Add to Wardrobe',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _handleCancel,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImagePickerSection(
                onCameraPressed: _handleCameraPress,
                onGalleryPressed: _handleGalleryPress,
                imagePath: _selectedImagePath,
              ),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'Name',
                controller: _nameController,
                hintText: 'e.g. "Blue Denim Jacket"',
              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'Description',
                controller: _descriptionController,
                hintText: 'Add details about this item...',
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              // Subcategory chooser (opens dialog with categories and expandable subcategories)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.list_alt_rounded),
                      label: Row(
                        children: [
                          Expanded(child: Text(_selectedSubcategory)),
                          const SizedBox(width: 8),
                          Text(
                            _selectedCategory,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () => _openSubcategoryChooser(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Color selector — show only the selected color swatch and open dialog to change
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openColorDialog(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _selectedColor ?? Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _selectedColor != null
                                ? theme.colorScheme.primary
                                : Colors.black12,
                            width: _selectedColor != null ? 3 : 1,
                          ),
                        ),
                        child: _selectedColor == null
                            ? const Icon(Icons.color_lens_outlined)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedColor != null
                            ? '#${_selectedColor!.value.toRadixString(16).padLeft(8, '0').substring(2)}'
                            : 'No color selected',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openColorDialog(context),
                      child: const Text('Choose Color'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Attributes editor (preselected from subtype defaults)
              ExpansionTile(
                initiallyExpanded: false,
                title: const Text('(Advanced) Attributes & Usage'),
                childrenPadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 8,
                ),
                children: [
                  // Materials
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Materials', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _materialsOptions.map((m) {
                            final sel = _selectedMaterials.contains(m);
                            return FilterChip(
                              label: Text(m.replaceAll('_', ' ')),
                              selected: sel,
                              onSelected: (s) {
                                setState(() {
                                  if (s) {
                                    _selectedMaterials.add(m);
                                  } else {
                                    _selectedMaterials.remove(m);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  // Numeric attributes
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedWarmth,
                          decoration: const InputDecoration(
                            filled: false,
                            labelText: 'Warmth',
                          ),
                          items: List.generate(
                            6,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text(i.toString()),
                            ),
                          ),
                          onChanged: (v) {
                            if (v != null)
                              setState(() {
                                _selectedWarmth = v;
                              });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedWater,
                          decoration: const InputDecoration(labelText: 'Water', filled: false),
                          items: List.generate(
                            6,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text(i.toString()),
                            ),
                          ),
                          onChanged: (v) {
                            if (v != null)
                              setState(() {
                                _selectedWater = v;
                              });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedWind,
                          decoration: const InputDecoration(labelText: 'Wind', filled: false),
                          items: List.generate(
                            6,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text(i.toString()),
                            ),
                          ),
                          onChanged: (v) {
                            if (v != null)
                              setState(() {
                                _selectedWind = v;
                              });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedBreath,
                          decoration: const InputDecoration(
                            filled: false,
                            labelText: 'Breathability',
                          ),
                          items: List.generate(
                            6,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text(i.toString()),
                            ),
                          ),
                          onChanged: (v) {
                            if (v != null)
                              setState(() {
                                _selectedBreath = v;
                              });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedStretch,
                    decoration: const InputDecoration(labelText: 'Stretch', filled: false),
                    items: List.generate(
                      6,
                      (i) =>
                          DropdownMenuItem(value: i, child: Text(i.toString())),
                    ),
                    onChanged: (v) {
                      if (v != null)
                        setState(() {
                          _selectedStretch = v;
                        });
                    },
                  ),

                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFit.isNotEmpty ? _selectedFit : null,
                    decoration: const InputDecoration(labelText: 'Fit', filled: false),
                    items: _fitOptions
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null)
                        setState(() {
                          _selectedFit = v;
                        });
                    },
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedFormality,
                    decoration: const InputDecoration(
                      labelText: 'Formality Level',
                      filled: false
                    ),
                    items: _formalityLevels.map((level) {
                      return DropdownMenuItem<String>(
                        value: level,
                        child: Text(level),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFormality = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 8),
                  Text('Style Tags', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _styleTagsOptions.map((t) {
                      final isSel = _selectedStyleTags.contains(t);
                      return FilterChip(
                        label: Text(t),
                        selected: isSel,
                        onSelected: (s) {
                          setState(() {
                            if (s) {
                              _selectedStyleTags.add(t);
                            } else {
                              _selectedStyleTags.remove(t);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),
                  Text('Usage Constraints', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minTempController,
                          decoration: const InputDecoration(
                            labelText: 'Min Temp',
                            filled: false
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _maxTempController,
                          decoration: const InputDecoration(
                            labelText: 'Max Temp',
                            filled: false
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),

                  ExpansionTile(
                    title: Row(
                      children: [
                        Icon(
                          Icons.fitness_center_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text('Optimal Activities'),
                      ],
                    ),
                    initiallyExpanded: false,
                    childrenPadding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 8,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: TextField(
                          controller: _optimalSearchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            filled: false,
                            hintText: 'Search activities',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._activityGroupOrder.map((group) {
                        final acts = _activityGroups[group] ?? [];
                        final search = _optimalSearchController.text
                            .trim()
                            .toLowerCase();
                        final displayActs = search.isEmpty
                            ? acts
                            : acts
                                  .where(
                                    (a) => a.toLowerCase().contains(search),
                                  )
                                  .toList();
                        if (displayActs.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6.0,
                            horizontal: 12.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    group.replaceAll('_', ' '),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${displayActs.length})',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: displayActs.map((act) {
                                  final isSel = _selectedOptimalActivities
                                      .contains(act);
                                  return FilterChip(
                                    label: Text(act.replaceAll('_', ' ')),
                                    selected: isSel,
                                    selectedColor: theme.colorScheme.primary,
                                    checkmarkColor: theme.colorScheme.onPrimary,
                                    backgroundColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    labelStyle: TextStyle(
                                      color: isSel
                                          ? theme.colorScheme.onPrimary
                                          : null,
                                    ),
                                    onSelected: (s) {
                                      setState(() {
                                        if (s) {
                                          _selectedOptimalActivities.add(act);
                                        } else {
                                          _selectedOptimalActivities.remove(
                                            act,
                                          );
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),

                  ExpansionTile(
                    title: Row(
                      children: [
                        Icon(
                          Icons.block_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text('Unsuitable For'),
                      ],
                    ),
                    initiallyExpanded: false,
                    childrenPadding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 8,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: TextField(
                          controller: _unsuitableSearchController,
                          decoration: InputDecoration(
                            filled: false,
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search activities',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._activityGroupOrder.map((group) {
                        final acts = _activityGroups[group] ?? [];
                        final search = _unsuitableSearchController.text
                            .trim()
                            .toLowerCase();
                        final displayActs = search.isEmpty
                            ? acts
                            : acts
                                  .where(
                                    (a) => a.toLowerCase().contains(search),
                                  )
                                  .toList();
                        if (displayActs.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6.0,
                            horizontal: 12.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    group.replaceAll('_', ' '),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${displayActs.length})',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: displayActs.map((act) {
                                  final isSel = _selectedUnsuitable.contains(
                                    act,
                                  );
                                  return FilterChip(
                                    label: Text(act.replaceAll('_', ' ')),
                                    selected: isSel,
                                    selectedColor: theme.colorScheme.primary,
                                    checkmarkColor: theme.colorScheme.onPrimary,
                                    backgroundColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    labelStyle: TextStyle(
                                      color: isSel
                                          ? theme.colorScheme.onPrimary
                                          : null,
                                    ),
                                    onSelected: (s) {
                                      setState(() {
                                        if (s) {
                                          _selectedUnsuitable.add(act);
                                        } else {
                                          _selectedUnsuitable.remove(act);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleCancel,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final isEditing = widget.initialItem != null;
                        return FilledButton.icon(
                          onPressed: _isLoading ? null : _handleAddToWardrobe,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  isEditing ? Icons.save : Icons.add_rounded,
                                ),
                          label: Text(
                            _isLoading
                                ? (isEditing ? 'Saving...' : 'Adding...')
                                : (isEditing ? 'Save' : 'Add to wardrobe'),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                            ), // Increase height
                            minimumSize: const Size.fromHeight(
                              48,
                            ), // Enforce button height
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
