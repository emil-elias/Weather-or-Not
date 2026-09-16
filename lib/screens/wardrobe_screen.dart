import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'add_item_screen.dart';
import 'wardrobe_item_detail_screen.dart';
import '../models/wardrobe_item.dart';
import '../models/saved_outfit.dart';
import '../services/wardrobe_service.dart';
import '../widgets/outfit_details_sheet.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchNotifier = ValueNotifier<String>('');
  final WardrobeService _wardrobeService = WardrobeService();

  bool _showAddItemScreen = false;
  List<WardrobeItem> _wardrobeItems = [];
  List<SavedOutfit> _savedOutfits = [];
  bool _isLoading = false;
  bool _isLoadingOutfits = false;

  Map<String, dynamic> _categoriesData = {};
  Map<String, dynamic> _subcategoriesData = {};
  List<Map<String, String>> _categoryOptions = [];
  List<Map<String, String>> _subcategoryOptions = [];

  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedFormalityLevel;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 || _tabController.index == 2) {
        _loadSavedOutfits();
      }
    });

    /*_searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        // Trigger setState only when the keyboard is dismissed
        setState(() {});
      }
    });*/

    _searchController.addListener(() {
      /*if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        setState(() {});
      });*/
      _searchNotifier.value = _searchController.text;
    });
    _loadCategoryData();
    _loadWardrobeItems();
    _loadSavedOutfits();
  }

  Future<void> _loadWardrobeItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await _wardrobeService.getWardrobeItems();
      if (mounted) {
        setState(() {
          _wardrobeItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSavedOutfits() async {
    setState(() {
      _isLoadingOutfits = true;
    });

    try {
      final outfits = await _wardrobeService.getSavedOutfits();
      if (mounted) {
        setState(() {
          _savedOutfits = outfits;
          _isLoadingOutfits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOutfits = false;
        });
      }
    }
  }

  Future<void> _loadCategoryData() async {
    try {
      final categoriesJson = await rootBundle.loadString(
        'assets/categories.json',
      );
      final subcategoriesJson = await rootBundle.loadString(
        'assets/subcategories.json',
      );

      final categoriesData = json.decode(categoriesJson);
      final subcategoriesData = json.decode(subcategoriesJson);

      if (mounted) {
        setState(() {
          _categoriesData = categoriesData;
          _subcategoriesData = subcategoriesData;

          _categoryOptions = (_categoriesData['categories'] as List)
              .map(
                (cat) => {
                  'id': cat['id'] as String,
                  'label': cat['label'] as String,
                },
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading category data: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchNotifier.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _navigateToAddItem() {
    setState(() {
      _showAddItemScreen = true;
    });
  }

  void _navigateBackToList() {
    setState(() {
      _showAddItemScreen = false;
    });
    _loadWardrobeItems();
  }

  List<WardrobeItem> _getFilteredItems() {
    var items = _wardrobeItems;

    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      items = items
          .where((item) => item.name.toLowerCase().contains(query))
          .toList();
    }

    if (_selectedCategory != null) {
      // Get all group labels for this category
      final categoryId = _categoryOptions.firstWhere(
        (cat) => cat['label'] == _selectedCategory,
        orElse: () => {'id': '', 'label': ''},
      )['id'];

      if (categoryId != null &&
          categoryId.isNotEmpty &&
          _categoriesData.isNotEmpty) {
        final category = (_categoriesData['categories'] as List).firstWhere(
          (cat) => cat['id'] == categoryId,
          orElse: () => {'groups': []},
        );

        final groupLabels = (category['groups'] as List)
            .map((g) => (g['label'] as String).toLowerCase())
            .toSet();

        items = items
            .where((item) => groupLabels.contains(item.category.toLowerCase()))
            .toList();
      }
    }

    if (_selectedSubcategory != null) {
      items = items
          .where(
            (item) =>
                item.subcategory.toLowerCase() ==
                _selectedSubcategory!.toLowerCase(),
          )
          .toList();
    }

    if (_selectedFormalityLevel != null) {
      items = items
          .where(
            (item) =>
                item.formalityLevel.toLowerCase() ==
                _selectedFormalityLevel!.toLowerCase(),
          )
          .toList();
    }

    return items;
  }

  List<String> _getUniqueCategories() {
    return _categoryOptions.map((cat) => cat['label']!).toList();
  }

  List<String> _getUniqueSubcategories() {
    if (_selectedCategory == null || _categoriesData.isEmpty) {
      return [];
    }

    final categoryId = _categoryOptions.firstWhere(
      (cat) => cat['label'] == _selectedCategory,
      orElse: () => {'id': '', 'label': ''},
    )['id'];

    if (categoryId == null || categoryId.isEmpty) return [];

    final category = (_categoriesData['categories'] as List).firstWhere(
      (cat) => cat['id'] == categoryId,
      orElse: () => {'groups': []},
    );

    if (category['groups'] == null) return [];

    final subcategories = <String>[];
    for (var group in category['groups'] as List) {
      final groupId = group['id'] as String;
      if (_subcategoriesData['subtypes'] != null &&
          _subcategoriesData['subtypes'][groupId] != null) {
        for (var subtype in _subcategoriesData['subtypes'][groupId] as List) {
          subcategories.add(subtype['label'] as String);
        }
      }
    }

    return subcategories;
  }

  List<String> _getUniqueFormalityLevels() {
    return ['Casual', 'Smart Casual', 'Business', 'Formal'];
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedSubcategory = null;
      _selectedFormalityLevel = null;
      _subcategoryOptions = [];
    });
  }

  bool get _hasActiveFilters {
    return _selectedCategory != null ||
        _selectedSubcategory != null ||
        _selectedFormalityLevel != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final GlobalKey<NavigatorState> wardrobeNavigatorKey =
        GlobalKey<NavigatorState>();

    /*if (_showAddItemScreen) {
      return AddItemScreen(onBack: _navigateBackToList);
    }*/

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (route, result) {
        if (wardrobeNavigatorKey.currentState != null &&
            wardrobeNavigatorKey.currentState!.canPop()) {
          wardrobeNavigatorKey.currentState!.pop(result);
        }
      },
      child: Navigator(
        key: wardrobeNavigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              centerTitle: false,
              title: Padding(
                padding: const EdgeInsets.only(
                  top: 24.0,
                  left: 10.0,
                  bottom: 8,
                ),
                child: Text(
                  'My Wardrobe',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.onSurface,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  tabs: [
                    Tab(
                      icon: _wardrobeItems.isNotEmpty
                          ? Badge(
                              label: Text('${_wardrobeItems.length}'),
                              child: const Icon(Icons.checkroom_outlined),
                              backgroundColor: theme.colorScheme.primary,
                              textColor: theme.colorScheme.onInverseSurface,
                            )
                          : const Icon(Icons.checkroom_outlined),
                      text: 'Clothes',
                    ),
                    Tab(
                      icon: _savedOutfits.isNotEmpty
                          ? Badge(
                              label: Text('${_savedOutfits.length}'),
                              child: const Icon(Icons.watch_later_outlined),
                              backgroundColor: theme.colorScheme.primary,
                              textColor: theme.colorScheme.onInverseSurface,
                            )
                          : const Icon(Icons.watch_later_outlined),
                      text: 'Saved outfits',
                    ),
                    Tab(
                      icon: () {
                        final favCount =
                            _wardrobeItems
                                .where((item) => item.isFavorite)
                                .length +
                            _savedOutfits
                                .where((outfit) => outfit.isFavorite)
                                .length;
                        return favCount > 0
                            ? Badge(
                                label: Text('$favCount'),
                                child: const Icon(Icons.favorite_outline),
                                backgroundColor: theme.colorScheme.primary,
                                textColor: theme.colorScheme.onInverseSurface,
                              )
                            : const Icon(Icons.favorite_outline);
                      }(),
                      text: 'Favorites',
                    ),
                  ],
                ),
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: _hasActiveFilters
                              ? theme.colorScheme.primaryContainer
                              : null,
                          border: Border.all(
                            color: _hasActiveFilters
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.tune_rounded,
                            color: _hasActiveFilters
                                ? theme.colorScheme.onPrimaryContainer
                                : null,
                          ),
                          onPressed: () => _showFilterBottomSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: _searchNotifier,
                    builder: (context, searchValue, child) {
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildClothesTab(theme),
                          _buildPastOutfitsTab(theme),
                          _buildFavoriteOutfitsTab(theme),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => {
                wardrobeNavigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) =>
                        AddItemScreen(onBack: _navigateBackToList),
                  ),
                ),
              },
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.add_rounded,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClothesTab(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredItems = _getFilteredItems();

    if (_wardrobeItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checkroom_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No items in wardrobe yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first item',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No items found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with a different name',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WardrobeItemDetailScreen(
                    item: item,
                    onUpdate: _loadWardrobeItems,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: item.color != ''
                              ? Color(
                                  int.parse('0xFF${item.color.substring(1)}'),
                                )
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: item.imagePath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(item.imagePath!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.checkroom_rounded,
                                color: theme.colorScheme.onPrimaryContainer
                                    .withOpacity(0.5),
                                size: 32,
                              ),
                      ),
                      if (item.isInWash)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.local_laundry_service,
                              color: theme.colorScheme.onPrimary,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description.isEmpty
                              ? '${item.category}'
                              : item.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: item.tags.take(3).map((tag) {
                              return Chip(
                                label: Text(tag),
                                padding: EdgeInsets.zero,
                                labelStyle: theme.textTheme.labelSmall,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          item.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_outline,
                        ),
                        color: item.isFavorite ? theme.colorScheme.error : null,
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _toggleFavorite(item),
                      ),
                      IconButton(
                        icon: Icon(
                          item.isInWash
                              ? Icons.local_laundry_service
                              : Icons.local_laundry_service_outlined,
                        ),
                        color: item.isInWash ? theme.colorScheme.primary : null,
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _toggleInWash(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _deleteItem(item.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteItem(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _wardrobeService.deleteWardrobeItem(id);
      _loadWardrobeItems();
    }
  }

  Future<void> _toggleFavorite(WardrobeItem item) async {
    final updatedItem = WardrobeItem(
      id: item.id,
      name: item.name,
      description: item.description,
      category: item.category,
      subcategory: item.subcategory,
      color: item.color,
      formalityLevel: item.formalityLevel,
      tags: item.tags,
      imagePath: item.imagePath,
      attributes: item.attributes,
      usageConstraints: item.usageConstraints,
      createdAt: item.createdAt,
      isFavorite: !item.isFavorite,
      isInWash: item.isInWash,
    );

    await _wardrobeService.updateWardrobeItem(updatedItem);
    _loadWardrobeItems();
  }

  Future<void> _toggleInWash(WardrobeItem item) async {
    final updatedItem = WardrobeItem(
      id: item.id,
      name: item.name,
      description: item.description,
      category: item.category,
      subcategory: item.subcategory,
      color: item.color,
      formalityLevel: item.formalityLevel,
      tags: item.tags,
      imagePath: item.imagePath,
      attributes: item.attributes,
      usageConstraints: item.usageConstraints,
      createdAt: item.createdAt,
      isFavorite: item.isFavorite,
      isInWash: !item.isInWash,
    );

    await _wardrobeService.updateWardrobeItem(updatedItem);
    _loadWardrobeItems();
  }

  Widget _buildPastOutfitsTab(ThemeData theme) {
    if (_isLoadingOutfits) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savedOutfits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.watch_later_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No past outfits yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final filteredOutfits = _getFilteredOutfits();

    if (filteredOutfits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No outfits found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredOutfits.length,
      itemBuilder: (context, index) {
        final outfit = filteredOutfits[index];
        return _buildOutfitCard(outfit, theme);
      },
    );
  }

  List<SavedOutfit> _getFilteredOutfits() {
    var outfits = _savedOutfits;

    //final query = _searchController.text.toLowerCase().trim();
    final query = _searchNotifier.value.toLowerCase().trim();
    if (query.isNotEmpty) {
      outfits = outfits.where((outfit) {
        // Search by outfit name
        if (outfit.name.toLowerCase().contains(query)) {
          return true;
        }

        // Search by items in outfit
        final outfitItems = _wardrobeItems.where((item) {
          return item.id == outfit.shirtId ||
              item.id == outfit.pulloverId ||
              item.id == outfit.bottomId ||
              item.id == outfit.outerwearId ||
              item.id == outfit.shoesId ||
              outfit.accessoryIds.contains(item.id);
        });

        return outfitItems.any(
          (item) =>
              item.name.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query) ||
              item.subcategory.toLowerCase().contains(query),
        );
      }).toList();
    }

    return outfits;
  }

  Widget _buildOutfitCard(SavedOutfit outfit, ThemeData theme) {
    // Get the wardrobe items that make up this outfit
    final outfitItems = _wardrobeItems.where((item) {
      return item.id == outfit.shirtId ||
          item.id == outfit.pulloverId ||
          item.id == outfit.bottomId ||
          item.id == outfit.outerwearId ||
          item.id == outfit.shoesId ||
          outfit.accessoryIds.contains(item.id);
    }).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showOutfitDetails(outfit, outfitItems),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              // Outfit preview with stacked images
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  children: [
                    if (outfitItems.isEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.checkroom_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 32,
                          ),
                        ),
                      )
                    else if (outfitItems.length == 1)
                      Container(
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(
                              '0xFF${outfitItems[0].color!.substring(1)}',
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: outfitItems[0].imagePath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(outfitItems[0].imagePath!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.checkroom_rounded,
                                  color: theme.colorScheme.onPrimaryContainer
                                      .withOpacity(0.5),
                                  size: 32,
                                ),
                              ),
                      )
                    else
                      // Show up to 4 items in a grid
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2,
                            ),
                        itemCount: outfitItems.length > 4
                            ? 4
                            : outfitItems.length,
                        itemBuilder: (context, i) {
                          final item = outfitItems[i];
                          return Container(
                            decoration: BoxDecoration(
                              color: item.color != ""
                                  ? Color(
                                      int.parse(
                                        '0xFF${item.color.substring(1)}',
                                      ),
                                    )
                                  : theme.colorScheme.primaryContainer,
                              borderRadius: i == 0
                                  ? const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                    )
                                  : i == 1
                                  ? const BorderRadius.only(
                                      topRight: Radius.circular(12),
                                    )
                                  : i == 2
                                  ? const BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                    )
                                  : const BorderRadius.only(
                                      bottomRight: Radius.circular(12),
                                    ),
                            ),
                            child: item.imagePath != null
                                ? ClipRRect(
                                    borderRadius: i == 0
                                        ? const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                          )
                                        : i == 1
                                        ? const BorderRadius.only(
                                            topRight: Radius.circular(12),
                                          )
                                        : i == 2
                                        ? const BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                          )
                                        : const BorderRadius.only(
                                            bottomRight: Radius.circular(12),
                                          ),
                                    child: Image.file(
                                      File(item.imagePath!),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    Icons.checkroom_rounded,
                                    color: theme.colorScheme.onPrimaryContainer
                                        .withOpacity(0.5),
                                    size: 16,
                                  ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outfit.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(outfit.savedAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${outfitItems.length} items',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      outfit.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_outline,
                    ),
                    color: outfit.isFavorite ? theme.colorScheme.error : null,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _toggleOutfitFavorite(outfit),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _deleteOutfit(outfit.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _toggleOutfitFavorite(SavedOutfit outfit) async {
    final updatedOutfit = SavedOutfit(
      id: outfit.id,
      name: outfit.name,
      savedAt: outfit.savedAt,
      shirtId: outfit.shirtId,
      pulloverId: outfit.pulloverId,
      bottomId: outfit.bottomId,
      outerwearId: outfit.outerwearId,
      shoesId: outfit.shoesId,
      accessoryIds: outfit.accessoryIds,
      isFavorite: !outfit.isFavorite,
    );

    await _wardrobeService.updateSavedOutfit(updatedOutfit);
    _loadSavedOutfits();
  }

  Future<void> _deleteOutfit(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Outfit'),
        content: const Text('Are you sure you want to delete this outfit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _wardrobeService.deleteSavedOutfit(id);
      _loadSavedOutfits();
    }
  }

  void _showOutfitDetails(SavedOutfit outfit, List<WardrobeItem> items) {
    // Delegate to the reusable sheet so planner and wardrobe reuse the same UI
    showOutfitDetailsSheet(
      context,
      title: outfit.name,
      date: outfit.savedAt,
      items: items,
      score: null,
    );
  }

  Widget _buildFavoriteOutfitsTab(ThemeData theme) {
    if (_isLoadingOutfits || _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredItems = _getFilteredItems();
    final favoriteItems = filteredItems
        .where((item) => item.isFavorite)
        .toList();
    final filteredOutfits = _getFilteredOutfits();
    final favoriteOutfits = filteredOutfits
        .where((outfit) => outfit.isFavorite)
        .toList();

    if (favoriteItems.isEmpty && favoriteOutfits.isEmpty) {
      final hasAnyFavorites =
          _wardrobeItems.any((item) => item.isFavorite) ||
          _savedOutfits.any((outfit) => outfit.isFavorite);

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              hasAnyFavorites
                  ? 'No favorites match your search'
                  : 'No favorites yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasAnyFavorites
                  ? 'Try adjusting your search'
                  : 'Tap the heart icon on items or outfits to add them here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Favorite Clothes Section
        if (favoriteItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Favorite Clothes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...favoriteItems.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WardrobeItemDetailScreen(
                        item: item,
                        onUpdate: _loadWardrobeItems,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: item.color != ""
                                  ? Color(
                                      int.parse(
                                        '0xFF${item.color!.substring(1)}',
                                      ),
                                    )
                                  : theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: item.imagePath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(item.imagePath!),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    Icons.checkroom_rounded,
                                    color: theme.colorScheme.onPrimaryContainer
                                        .withOpacity(0.5),
                                    size: 32,
                                  ),
                          ),
                          if (item.isInWash)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.local_laundry_service,
                                  color: theme.colorScheme.onPrimary,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description.isEmpty
                                  ? '${item.category}'
                                  : item.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.tags.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: item.tags.take(3).map((tag) {
                                  return Chip(
                                    label: Text(tag),
                                    padding: EdgeInsets.zero,
                                    labelStyle: theme.textTheme.labelSmall,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.favorite),
                            color: theme.colorScheme.error,
                            iconSize: 20,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _toggleFavorite(item),
                          ),
                          IconButton(
                            icon: Icon(
                              item.isInWash
                                  ? Icons.local_laundry_service
                                  : Icons.local_laundry_service_outlined,
                            ),
                            color: item.isInWash
                                ? theme.colorScheme.primary
                                : null,
                            iconSize: 20,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _toggleInWash(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            iconSize: 20,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _deleteItem(item.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        // Favorite Outfits Section
        if (favoriteOutfits.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Favorite Outfits',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...favoriteOutfits.map((outfit) => _buildOutfitCard(outfit, theme)),
        ],
      ],
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Options',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _clearFilters();
                          });
                          setState(() {});
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterSection(
                          theme: theme,
                          title: 'Category',
                          icon: Icons.category_outlined,
                          options: _getUniqueCategories(),
                          selectedValue: _selectedCategory,
                          onSelected: (value) {
                            setModalState(() {
                              _selectedCategory = value;
                              if (value == null) {
                                _selectedSubcategory = null;
                              } else if (_selectedSubcategory != null) {
                                final availableSubcats =
                                    _getUniqueSubcategories();
                                if (!availableSubcats.contains(
                                  _selectedSubcategory,
                                )) {
                                  _selectedSubcategory = null;
                                }
                              }
                            });
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildFilterSection(
                          theme: theme,
                          title: 'Subcategory',
                          icon: Icons.label_outline,
                          options: _getUniqueSubcategories(),
                          selectedValue: _selectedSubcategory,
                          onSelected: (value) {
                            setModalState(() {
                              _selectedSubcategory = value;
                            });
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildFilterSection(
                          theme: theme,
                          title: 'Formality Level',
                          icon: Icons.star_outline_rounded,
                          options: _getUniqueFormalityLevels(),
                          selectedValue: _selectedFormalityLevel,
                          onSelected: (value) {
                            setModalState(() {
                              _selectedFormalityLevel = value;
                            });
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterSection({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<String> options,
    required String? selectedValue,
    required Function(String?) onSelected,
  }) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                onSelected(selected ? option : null);
              },
              showCheckmark: true,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
