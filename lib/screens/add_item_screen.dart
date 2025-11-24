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

  const AddItemScreen({super.key, required this.onBack});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
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

  
  
  final List<String> _formalityLevels = [
    'Casual',
    'Smart Casual',
    'Business',
    'Formal',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _colorController.dispose();
    _tagsController.dispose();
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
    _tagsController.clear();
    setState(() {
      _selectedImagePath = null;
      _selectedCategory = 'Tops';
      _selectedSubcategory = 'T-Shirts';
      _selectedFormality = 'Casual';
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
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final item = WardrobeItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
        color: _colorController.text.trim(),
        formalityLevel: _selectedFormality,
        tags: tags,
        imagePath: _selectedImagePath,
        createdAt: DateTime.now(),
      );

      final success = await _wardrobeService.addWardrobeItem(item);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added to wardrobe successfully!')),
        );
        _clearForm();
        widget.onBack();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add item. Please try again.'),
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

      // Select first group as default
      _selectedCategory = _categories.first;

      // Get selected group ID
      final selectedGroup = allGroups.firstWhere(
        (g) => g['label'] == _selectedCategory,
      );
      final selectedGroupId = selectedGroup['id'];

      // SUBCATEGORIES = entries in subtypes.json for the group id
      _subcategories = (subtypesData['subtypes'][selectedGroupId] as List)
        .map((s) => s['label'] as String)
        .toList();

      _selectedSubcategory = _subcategories.first;
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



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Add to Wardrobe',
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
                      onChanged: (value) {
                        setState(() {
                          _selectedSubcategory = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Color',
                      controller: _colorController,
                      hintText: 'e.g. "Blue"',
                      prefixIcon: const Icon(Icons.palette_outlined),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdown(
                      label: 'Formality level',
                      value: _selectedFormality,
                      items: _formalityLevels,
                      prefixIcon: Icons.style_outlined,
                      onChanged: (value) {
                        setState(() {
                          _selectedFormality = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'Tags',
                controller: _tagsController,
                hintText: 'Add tags separated by commas',
                maxLines: 2,
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
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _handleAddToWardrobe,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_rounded),
                      label: Text(_isLoading ? 'Adding...' : 'Add to wardrobe'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                        ), // Increase height
                        minimumSize: const Size.fromHeight(
                          48,
                        ), // Enforce button height
                      ),
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
