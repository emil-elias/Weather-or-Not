import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/image_picker_section.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_dropdown.dart';
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
  final TextEditingController _colorController = TextEditingController();
  final WardrobeService _wardrobeService = WardrobeService();
  final ImagePicker _imagePicker = ImagePicker();

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
  final TextEditingController _optimalSearchController = TextEditingController();
  final TextEditingController _unsuitableSearchController = TextEditingController(); 

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
      _colorController.text = widget.initialItem!.color;
      _selectedImagePath = widget.initialItem!.imagePath;
      _selectedCategory = widget.initialItem!.category;
      _selectedSubcategory = widget.initialItem!.subcategory;
      _selectedFormality = widget.initialItem!.formalityLevel; 
    }

    _initAsync();
  }

  Future<void> _initAsync() async {
    await _loadCategoryData();
    await _loadSubtypesAttributes();
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
    _colorController.dispose();
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
    _colorController.clear();
    setState(() {
      _selectedImagePath = null;
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
      final tags = widget.initialItem != null ? widget.initialItem!.tags : <String>[];

      final isEditing = widget.initialItem != null;
      final item = WardrobeItem(
        id: isEditing ? widget.initialItem!.id : DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
        color: _colorController.text.trim(),
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
      );

      final success = isEditing ? await _wardrobeService.updateWardrobeItem(item) : await _wardrobeService.addWardrobeItem(item);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Item updated successfully!' : 'Item added to wardrobe successfully!')),
        );
        _clearForm();
        widget.onBack();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add/update item. Please try again.'),
          ),
        );
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

  Future<void> _saveImage(XFile image) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = File('${directory.path}/$fileName');

      await File(image.path).copy(savedImage.path);

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
      _categories = allGroups
        .map((g) => g['label'] as String)
        .toList();

      // Select category - respect initial item if present
      if (widget.initialItem != null && _categories.contains(widget.initialItem!.category)) {
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
      if (widget.initialItem != null && _subcategories.contains(widget.initialItem!.subcategory)) {
        _selectedSubcategory = widget.initialItem!.subcategory;
      } else {
        _selectedSubcategory = _subcategories.first;
      }

      // apply defaults if we already loaded attributes
      final initialId = _subLabelToId[_selectedSubcategory];
      if (initialId != null && _subtypesAttributes.isNotEmpty) {
        _applyDefaultsForSubcategory(initialId);
      }
    });
  }


  
  Future<Map<String, dynamic>> loadCategoriesJson() async {
    final String response =
        await rootBundle.loadString('assets/categories.json'); // adjust path if needed
    final data = json.decode(response) as Map<String, dynamic>;
    return data;
  }

  Future<Map<String, dynamic>> loadSubtypesJson() async {
    final String response = 
      await rootBundle.loadString('assets/subcategories.json');
    return json.decode(response);
  }

  Future<void> _loadSubtypesAttributes() async {
    try {
      final String response = await rootBundle.loadString('assets/subtypes_attributes.json');
      final Map<String, dynamic> data = json.decode(response) as Map<String, dynamic>;
      final Set<String> mats = {};
      final Set<String> forms = {};
      final Set<String> tags = {};
      final Set<String> fits = {};

      data.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          final attrs = (v['attributes'] as Map<String, dynamic>?) ?? {};
          final materials = attrs['materials'] as List<dynamic>?;
          if (materials != null) mats.addAll(materials.map((e) => e.toString()));
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
      print('Failed to load subtype attributes: $e');
    }
  }

  Future<void> _loadActivityOptions() async {
    try {
      final String response = await rootBundle.loadString('assets/activities.json');
      final Map<String, dynamic> data = json.decode(response) as Map<String, dynamic>;
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
      groups.forEach((k,v) {
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
      final mats = (attrs['materials'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
      _selectedMaterials.addAll(mats);

      _selectedStyleTags.clear();
      final tags = (attrs['style_tags'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
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

      _selectedWarmth = (attrs['warmth_level'] is num) ? (attrs['warmth_level'] as num).toInt() : _selectedWarmth;
      _selectedWater = (attrs['water_resistance'] is num) ? (attrs['water_resistance'] as num).toInt() : _selectedWater;
      _selectedWind = (attrs['wind_resistance'] is num) ? (attrs['wind_resistance'] as num).toInt() : _selectedWind;
      _selectedBreath = (attrs['breathability'] is num) ? (attrs['breathability'] as num).toInt() : _selectedBreath;
      _selectedStretch = (attrs['stretch'] is num) ? (attrs['stretch'] as num).toInt() : _selectedStretch;

      _minTempController.text = usage['weather_min_temp']?.toString() ?? '';
      _maxTempController.text = usage['weather_max_temp']?.toString() ?? '';

      _selectedOptimalActivities.clear();
      final optimal = (usage['optimal_activities'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
      _selectedOptimalActivities.addAll(optimal);

      _selectedUnsuitable.clear();
      final unsuitable = (usage['unsuitable_for'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
      _selectedUnsuitable.addAll(unsuitable);
    });
  }

  void _populateFromInitial(WardrobeItem item) {
    // Basic text fields
    _nameController.text = item.name;
    _descriptionController.text = item.description;
    _colorController.text = item.color;
    _selectedImagePath = item.imagePath;

    // Basic selections
    _selectedCategory = item.category;
    _selectedSubcategory = item.subcategory;
    _selectedFormality = item.formalityLevel;

    // Attributes
    final attrs = item.attributes ?? {};
    _selectedMaterials.clear();
    final mats = (attrs['materials'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
    _selectedMaterials.addAll(mats);

    _selectedStyleTags.clear();
    final sty = (attrs['style_tags'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
    _selectedStyleTags.addAll(sty);

    _selectedFit = attrs['fit']?.toString() ?? _selectedFit;
    _selectedWarmth = (attrs['warmth_level'] is num) ? (attrs['warmth_level'] as num).toInt() : _selectedWarmth;
    _selectedWater = (attrs['water_resistance'] is num) ? (attrs['water_resistance'] as num).toInt() : _selectedWater;
    _selectedWind = (attrs['wind_resistance'] is num) ? (attrs['wind_resistance'] as num).toInt() : _selectedWind;
    _selectedBreath = (attrs['breathability'] is num) ? (attrs['breathability'] as num).toInt() : _selectedBreath;
    _selectedStretch = (attrs['stretch'] is num) ? (attrs['stretch'] as num).toInt() : _selectedStretch;

    final usage = item.usageConstraints ?? {};
    _minTempController.text = usage['weather_min_temp']?.toString() ?? '';
    _maxTempController.text = usage['weather_max_temp']?.toString() ?? '';

    _selectedOptimalActivities.clear();
    final optimal = (usage['optimal_activities'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
    _selectedOptimalActivities.addAll(optimal);

    _selectedUnsuitable.clear();
    final unsuitable = (usage['unsuitable_for'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
    _selectedUnsuitable.addAll(unsuitable);

    // if there is a matching subtype id for the subcategory, ensure defaults are applied first
    final id = _subLabelToId[_selectedSubcategory];
    if (id != null && _subtypesAttributes.isNotEmpty) {
      _applyDefaultsForSubcategory(id);
      // Then overwrite with explicit item attributes (already applied above)
    }

    setState(() {});
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
              Row(
                children: [
                  Expanded(
                    child: CustomDropdown(
                      label: 'Category',
                      value: _selectedCategory,
                      items: _categories,
                      prefixIcon: Icons.category_outlined,
                      onChanged: (value) async {
                        setState(() {
                          _selectedCategory = value!;
                        });

                        // Find the matching group
                        final selectedGroup =
                            _rawCategories.firstWhere((g) => g['label'] == value);

                        final selectedGroupId = selectedGroup['id'];

                        // Load subtypes.json
                        final subtypesData = await loadSubtypesJson();

                        // Update subcategories for this selected top-level category
                        final subtypes =
                            (subtypesData['subtypes'][selectedGroupId] as List)
                                .map((s) => s['label'] as String)
                                .toList();

                        setState(() {
                          _subcategories = subtypes;
                          _selectedSubcategory = _subcategories.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdown(
                      label: 'Subcategory',
                      value: _selectedSubcategory,
                      items: _subcategories,
                      prefixIcon: Icons.list_alt_rounded,
                      onChanged: (value) async {
                        final newVal = value!;
                        setState(() {
                          _selectedSubcategory = newVal;
                        });

                        final id = _subLabelToId[newVal];
                        if (id != null && _subtypesAttributes.isNotEmpty) {
                          _applyDefaultsForSubcategory(id);
                        } else {
                          // Try to discover the id from subtypes json if missing
                          try {
                            final subtypesData = await loadSubtypesJson();
                            String? foundId;
                            final subtypesMap = subtypesData['subtypes'] as Map<String, dynamic>;
                            for (final entry in subtypesMap.entries) {
                              final list = entry.value as List;
                              for (final s in list) {
                                if ((s['label'] as String) == newVal) {
                                  foundId = s['id'] as String;
                                  break;
                                }
                              }
                              if (foundId != null) break;
                            }
                            if (foundId != null) {
                              _subLabelToId[newVal] = foundId;
                              if (_subtypesAttributes.isNotEmpty) _applyDefaultsForSubcategory(foundId);
                            }
                          } catch (_) {}
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'Color',
                controller: _colorController,
                hintText: 'e.g. "Blue"',
                prefixIcon: const Icon(Icons.palette_outlined),
              ),
              const SizedBox(height: 24),

              // Attributes editor (preselected from subtype defaults)
              ExpansionTile(
                initiallyExpanded: true,
                title: const Text('Attributes & Usage'),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
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
                              label: Text(m),
                              selected: sel,
                              onSelected: (s) { setState(() { if (s) {
                                _selectedMaterials.add(m);
                              } else {
                                _selectedMaterials.remove(m);
                              } }); },
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
                      Expanded(child: DropdownButtonFormField<int>(
                        initialValue: _selectedWarmth,
                        decoration: const InputDecoration(labelText: 'Warmth'),
                        items: List.generate(6, (i) => DropdownMenuItem(value: i, child: Text(i.toString()))),
                        onChanged: (v) { if (v != null) setState(() { _selectedWarmth = v; }); },
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: DropdownButtonFormField<int>(
                        initialValue: _selectedWater,
                        decoration: const InputDecoration(labelText: 'Water'),
                        items: List.generate(6, (i) => DropdownMenuItem(value: i, child: Text(i.toString()))),
                        onChanged: (v) { if (v != null) setState(() { _selectedWater = v; }); },
                      )),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: DropdownButtonFormField<int>(
                        initialValue: _selectedWind,
                        decoration: const InputDecoration(labelText: 'Wind'),
                        items: List.generate(6, (i) => DropdownMenuItem(value: i, child: Text(i.toString()))),
                        onChanged: (v) { if (v != null) setState(() { _selectedWind = v; }); },
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: DropdownButtonFormField<int>(
                        initialValue: _selectedBreath,
                        decoration: const InputDecoration(labelText: 'Breathability'),
                        items: List.generate(6, (i) => DropdownMenuItem(value: i, child: Text(i.toString()))),
                        onChanged: (v) { if (v != null) setState(() { _selectedBreath = v; }); },
                      )),
                    ],
                  ),

                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedStretch,
                    decoration: const InputDecoration(labelText: 'Stretch'),
                    items: List.generate(6, (i) => DropdownMenuItem(value: i, child: Text(i.toString()))),
                    onChanged: (v) { if (v != null) setState(() { _selectedStretch = v; }); },
                  ),



                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFit.isNotEmpty ? _selectedFit : null,
                    decoration: const InputDecoration(labelText: 'Fit'),
                    items: _fitOptions.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) { if (v != null) setState(() { _selectedFit = v; }); },
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
                        onSelected: (s) { setState(() { if (s) {
                          _selectedStyleTags.add(t);
                        } else {
                          _selectedStyleTags.remove(t);
                        } }); },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),
                  Text('Usage Constraints', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _minTempController, decoration: const InputDecoration(labelText: 'Min Temp'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _maxTempController, decoration: const InputDecoration(labelText: 'Max Temp'), keyboardType: TextInputType.number)),
                    ],
                  ),

                  ExpansionTile(
                    title: Row(children: [Icon(Icons.fitness_center_outlined, size:20, color: theme.colorScheme.primary), const SizedBox(width:8), Text('Optimal Activities')]),
                    initiallyExpanded: false,
                    childrenPadding: const EdgeInsets.symmetric(horizontal:0, vertical:8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: TextField(
                          controller: _optimalSearchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search activities',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._activityGroupOrder.map((group) {
                        final acts = _activityGroups[group] ?? [];
                        final search = _optimalSearchController.text.trim().toLowerCase();
                        final displayActs = search.isEmpty ? acts : acts.where((a) => a.toLowerCase().contains(search)).toList();
                        if (displayActs.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical:6.0, horizontal: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Text(group.replaceAll('_', ' '), style: theme.textTheme.bodySmall), const SizedBox(width:8), Text('(${displayActs.length})', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))]),
                              const SizedBox(height:8),
                              Wrap(
                                spacing: 8,
                                children: displayActs.map((act) {
                                  final isSel = _selectedOptimalActivities.contains(act);
                                  return FilterChip(
                                    label: Text(act),
                                    selected: isSel,
                                    selectedColor: theme.colorScheme.primary,
                                    checkmarkColor: theme.colorScheme.onPrimary,
                                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                    labelStyle: TextStyle(color: isSel ? theme.colorScheme.onPrimary : null),
                                    onSelected: (s) { setState(() { if (s) {
                                      _selectedOptimalActivities.add(act);
                                    } else {
                                      _selectedOptimalActivities.remove(act);
                                    } }); },
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
                    title: Row(children: [Icon(Icons.block_outlined, size:20, color: theme.colorScheme.primary), const SizedBox(width:8), Text('Unsuitable For')]),
                    initiallyExpanded: false,
                    childrenPadding: const EdgeInsets.symmetric(horizontal:0, vertical:8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: TextField(
                          controller: _unsuitableSearchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search activities',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._activityGroupOrder.map((group) {
                        final acts = _activityGroups[group] ?? [];
                        final search = _unsuitableSearchController.text.trim().toLowerCase();
                        final displayActs = search.isEmpty ? acts : acts.where((a) => a.toLowerCase().contains(search)).toList();
                        if (displayActs.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical:6.0, horizontal: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Text(group.replaceAll('_', ' '), style: theme.textTheme.bodySmall), const SizedBox(width:8), Text('(${displayActs.length})', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))]),
                              const SizedBox(height:8),
                              Wrap(
                                spacing: 8,
                                children: displayActs.map((act) {
                                  final isSel = _selectedUnsuitable.contains(act);
                                  return FilterChip(
                                    label: Text(act),
                                    selected: isSel,
                                    selectedColor: theme.colorScheme.primary,
                                    checkmarkColor: theme.colorScheme.onPrimary,
                                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                    labelStyle: TextStyle(color: isSel ? theme.colorScheme.onPrimary : null),
                                    onSelected: (s) { setState(() { if (s) {
                                      _selectedUnsuitable.add(act);
                                    } else {
                                      _selectedUnsuitable.remove(act);
                                    } }); },
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(isEditing ? Icons.save : Icons.add_rounded),
                        label: Text(_isLoading
                            ? (isEditing ? 'Saving...' : 'Adding...')
                            : (isEditing ? 'Save' : 'Add to wardrobe')),
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
