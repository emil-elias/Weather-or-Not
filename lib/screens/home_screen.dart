import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:weatherornot/models/forecast.dart';
import 'package:weatherornot/screens/weather_screen.dart';
import 'package:weatherornot/services/outfit_generator.dart';
import 'package:weatherornot/providers/main_provider.dart';
import 'package:weatherornot/widgets/location_dropdown.dart';
import 'package:weatherornot/widgets/weather_card.dart';
import '../services/weather_service.dart';
import '../services/wardrobe_service.dart';
import '../models/weather.dart';
import '../models/activity.dart';
import '../models/outfit.dart';
import '../models/saved_outfit.dart';
import '../constants/app_constants.dart';
import '../services/location_service.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  final WardrobeService _wardrobeService = WardrobeService();

  final LocationService _locationService = LocationService();

  MainProvider _provider = MainProvider();

  String _selectedLocation = 'Bremen, Germany';
  Weather? _currentWeather;
  Forecast? _forecast;
  Outfit? _generatedOutfit;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _subtypesAttributesData = {};
  // Activities loaded from JSON
  Map<String, dynamic> _activitiesData = {};
  List<String> _availableActivities = [];

  // Location coordinates
  final Map<String, Map<String, double>> _locationCoordinates = {
    'Bremen, Germany': {'lat': 53.0793, 'lon': 8.8017},
    'Hamburg, Germany': {'lat': 53.5511, 'lon': 9.9937},
    'Berlin, Germany': {'lat': 52.5200, 'lon': 13.4050},
    'München, Germany': {'lat': 48.1351, 'lon': 11.5820},
    'Köln, Germany': {'lat': 50.9375, 'lon': 6.9603},
    'Lisbon, Portugal': {'lat': 38.47, 'lon': -9.08},
  };
  List<String> _locations = [];

  final List<Activity> _todayActivities = [];

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _loadActivitiesFromAssets();
    _loadSubtypesAttributesFromAssets(); // Add this line
    _loadWeather();
  }

  /// Load activities from assets/activities.json
  Future<void> _loadActivitiesFromAssets() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/activities.json',
      );
      final jsonData = jsonDecode(jsonString);

      setState(() {
        _activitiesData = jsonData;
      });

      // Update available activities based on wardrobe
      await _updateAvailableActivities();
    } catch (e) {
      print('Error loading activities: $e');
    }
  }

  /// Update available activities based on wardrobe items
  Future<void> _updateAvailableActivities() async {
    try {
      final wardrobeItems = await _wardrobeService.getWardrobeItems();

      if (wardrobeItems.isEmpty) {
        setState(() {
          _availableActivities = [];
        });
        return;
      }

      // Extract categories from wardrobe
      final wardrobeCategories = wardrobeItems
          .map((item) => item.category.toLowerCase())
          .toSet()
          .toList();

      // Map wardrobe categories to activities
      final activities = _mapWardrobeToActivities(wardrobeCategories);

      setState(() {
        _availableActivities = activities;
      });
    } catch (e) {
      print('Error updating activities: $e');
    }
  }

  /// Map wardrobe categories to relevant activities
  List<String> _mapWardrobeToActivities(List<String> wardrobeCategories) {
    final List<String> relevantActivities = [];

    // Define mappings between wardrobe categories and activity keys
    const categoryActivityMap = {
      'tops': ['casual', 'work', 'events', 'outdoor'],
      'bottoms': ['casual', 'work', 'events', 'outdoor'],
      'outerwear': ['casual', 'outdoor', 'sports'],
      'shoes': ['casual', 'work', 'events', 'outdoor', 'sports'],
      'accessories': ['all'],
      'sportswear': ['sports'],
    };

    // Check for sport shoes or sportswear -> add sports activities
    final hasSportEquipment = wardrobeCategories.any(
      (cat) => cat.contains('sport') || cat.contains('gym'),
    );

    if (hasSportEquipment) {
      relevantActivities.add('sports');
    }

    // Check for formal/dress shoes -> add events
    final hasFormalShoes = wardrobeCategories.any(
      (cat) => cat.contains('dress') || cat.contains('formal'),
    );

    if (hasFormalShoes) {
      relevantActivities.add('events');
    }

    // Check for outdoor/technical gear -> add outdoor
    final hasOutdoorGear = wardrobeCategories.any(
      (cat) => cat.contains('technical') || cat.contains('hiking'),
    );

    if (hasOutdoorGear) {
      relevantActivities.add('outdoor');
    }

    // Always add casual and work
    relevantActivities.addAll(['casual', 'work', 'home']);

    return relevantActivities.toSet().toList();
  }

  /// Get subcategories for a given activity category
  List<String> _getSubcategoriesForActivity(String activityKey) {
    final List<String> subcategories = [];

    if (_activitiesData.containsKey('activities') &&
        _activitiesData['activities'].containsKey(activityKey)) {
      final Map<String, dynamic> activityGroups =
          _activitiesData['activities'][activityKey];
      activityGroups.forEach((group, subList) {
        if (subList is List) {
          subcategories.addAll(List<String>.from(subList));
        }
      });
    }

    return subcategories;
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final coords =
          _locationCoordinates[_selectedLocation] ??
          {
            'lat': AppConstants.bremenLatitude,
            'lon': AppConstants.bremenLongitude,
          };

      final stationID = AppConstants.stationIDs[_selectedLocation];

      final weather = await _weatherService.getCurrentDWDWeatherByStationID(
        stationID!,
        locationName: _selectedLocation,
        fallbackLat: coords['lat'],
        fallbackLon: coords['lon'],
      );

      final forecast = await _weatherService.getForecastDWDWeatherByStationID(
        stationID,
      );

      print(forecast.days);

      // Generate outfit with weather and activities


      setState(() {
        _currentWeather = weather;
        _forecast = forecast;
        _isLoading = false;
      });

      await _generateOutfit(weather);
    } catch (e) {
      setState(() {
        _errorMessage = 'Wetter konnte nicht geladen werden';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateOutfit(Weather weather) async {
    try {
      // Fetch wardrobe items from storage
      final wardrobeItems = await _wardrobeService.getWardrobeItems();

      if (wardrobeItems.isEmpty) {
        print('No wardrobe items available');
        return;
      }

      // Convert WardrobeItem to ClothingItem
      final clothingItems = _convertToClothingItems(wardrobeItems);

      // Create outfit engine
      final outfitEngine = OutfitEngine(clothingItems);

      // Get activity string (combine all activities or use first one)
      String activityString = 'daily';
      if (_todayActivities.isNotEmpty) {
        activityString = _todayActivities.first.type.displayName.toLowerCase();
      }

      // Generate outfit
      final outfit = outfitEngine.generate(
        temperature: weather.temperature ?? 20.0,
        activity: activityString,
      );

      setState(() {
        _generatedOutfit = outfit;
      });
    } catch (e) {
      print('Error generating outfit: $e');
    }
  }

  Future<void> _saveOutfit() async {
    if (_generatedOutfit == null) return;

    try {
      // Show dialog to name the outfit
      final TextEditingController nameController = TextEditingController();
      final outfitName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save Outfit'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Outfit Name',
              hintText: 'e.g., Casual Monday, Sport Day',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, nameController.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (outfitName == null || outfitName.trim().isEmpty) return;

      final savedOutfit = SavedOutfit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: outfitName.trim(),
        savedAt: DateTime.now(),
        shirtId: _generatedOutfit!.shirt?.id,
        pulloverId: _generatedOutfit!.pullover?.id,
        bottomId: _generatedOutfit!.bottom?.id,
        outerwearId: _generatedOutfit!.outerwear?.id,
        shoesId: _generatedOutfit!.shoes?.id,
        accessoryIds: _generatedOutfit!.accessories.map((a) => a.id).toList(),
      );

      final success = await _wardrobeService.saveOutfit(savedOutfit);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Outfit saved successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save outfit')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  /// Load subtypes attributes from assets/subtypes_attributes.json
  Future<void> _loadSubtypesAttributesFromAssets() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/subtypes_attributes.json',
      );
      final jsonData = jsonDecode(jsonString);

      setState(() {
        _subtypesAttributesData = jsonData;
      });
    } catch (e) {
      print('Error loading subtypes attributes: $e');
    }
  }

  /// Convert WardrobeItem to ClothingItem for the outfit engine
  /// Uses attributes from subtypes_attributes.json if available
  List<ClothingItem> _convertToClothingItems(List<dynamic> wardrobeItems) {
    return wardrobeItems.map((item) {
      // Raw values from stored WardrobeItem
      final rawCategory = (item.category ?? '').toString().toLowerCase();
      final rawSubtype = (item.subcategory ?? '').toString().toLowerCase();
      final name = item.name ?? '';
      final imagePath = item.imagePath;

      // Try to look up attributes from JSON using the subcategory as key
      Map<String, dynamic>? foundSubtypeData =
          _subtypesAttributesData[rawSubtype];

      // If not found, try normalizing spaces/hyphens to underscores
      if (foundSubtypeData == null) {
        final normalizedSubtype = rawSubtype
            .replaceAll(' ', '_')
            .replaceAll('-', '_');
        foundSubtypeData = _subtypesAttributesData[normalizedSubtype];

        if (foundSubtypeData != null) {
          print(
            'Found subtype via normalization: "$rawSubtype" -> "$normalizedSubtype"',
          );
        }
      }

      // If still not found, log a warning
      if (foundSubtypeData == null) {
        print(
          'Warning: Subtype "$rawSubtype" not found in subtypes_attributes.json (tried normalized: ${rawSubtype.replaceAll(' ', '_').replaceAll('-', '_')}), using defaults',
        );
      } else {
        print('Loaded attributes for "$rawSubtype" from JSON');
      }

      // Extract attributes from JSON or use defaults
      final attributesData = foundSubtypeData?['attributes'] ?? {};
      final usageConstraintsData = foundSubtypeData?['usage_constraints'] ?? {};

      // Parse attributes with fallback defaults
      final materials = List<String>.from(attributesData['materials'] ?? []);
      final warmthLevel = attributesData['warmth_level'] ?? 5;
      final waterResistance = attributesData['water_resistance'] ?? 5;
      final windResistance = attributesData['wind_resistance'] ?? 5;
      final breathability = attributesData['breathability'] ?? 5;
      final stretch = attributesData['stretch'] ?? 5;
      final formality =
          attributesData['formality'] ?? (item.formalityLevel ?? 'casual');
      final styleTags = List<String>.from(attributesData['style_tags'] ?? []);
      final fit = attributesData['fit'] ?? 'regular';

      // Parse usage constraints with fallback defaults
      final weatherMinTemp = usageConstraintsData['weather_min_temp'] ?? -40;
      final weatherMaxTemp = usageConstraintsData['weather_max_temp'] ?? 45;
      final optimalActivities = List<String>.from(
        usageConstraintsData['optimal_activities'] ?? ['daily', 'casual'],
      );
      final unsuitableFor = List<String>.from(
        usageConstraintsData['unsuitable_for'] ?? [],
      );

      // Build ClothingItem using data from JSON
      return ClothingItem(
        id: item.id,
        category: rawCategory,
        subtype: rawSubtype,
        attributes: ClothingAttributes(
          materials: materials,
          warmthLevel: warmthLevel,
          waterResistance: waterResistance,
          windResistance: windResistance,
          breathability: breathability,
          stretch: stretch,
          formality: formality,
          styleTags: styleTags,
          fit: fit,
        ),
        usageConstraints: UsageConstraints(
          weatherMinTemp: weatherMinTemp,
          weatherMaxTemp: weatherMaxTemp,
          optimalActivities: optimalActivities,
          unsuitableFor: unsuitableFor,
        ),
        extractedColors: [],
        metadata: {'imagePath': imagePath, 'name': name},
      );
    }).toList();
  }

  /// Estimate warmth level from formality level
  int _getWarmthLevel(String formalityLevel) {
    switch (formalityLevel.toLowerCase()) {
      case 'casual':
        return 5;
      case 'business':
        return 6;
      case 'formal':
        return 7;
      default:
        return 5;
    }
  }

  void _onLocationChanged(String? newLocation) {
    if (newLocation != null && newLocation != _provider.selectedLocation) {
      _provider.setSelectedLocation(newLocation);
      _provider.loadWeather(
        _provider.stationIDs[newLocation]!,
        newLocation,
        fallbackStations: _provider.closestLocations.where((loc) => loc['name'] != newLocation)
                  .toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final GlobalKey<NavigatorState> homeNavigatorKey =
        GlobalKey<NavigatorState>();

    _provider = context.watch<MainProvider>();

    _currentWeather = context.watch<MainProvider>().currentWeather;
    _forecast = context.watch<MainProvider>().forecast;
    _isLoading = context.watch<MainProvider>().isLoading;
    _errorMessage = context.watch<MainProvider>().errorMessage;
    _selectedLocation = context.watch<MainProvider>().selectedLocation;
    _locations = context.watch<MainProvider>().locations;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Navigator(
        key: homeNavigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        'Today',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      LocationDropdown(
                        selectedLocation: _selectedLocation,
                        locations: _locations,
                        onLocationChanged: _onLocationChanged,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  WeatherCard(
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                    currentWeather: _currentWeather,
                    forecast: _forecast,
                    onTap: () {
                      homeNavigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (_) => const WeatherScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Add activities button
                  GestureDetector(
                    onTap: () => _showAddActivityDialog(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.show_chart_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Add activities for today',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Activities list
                  // Activities list
                  if (_todayActivities.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _todayActivities.map((activity) {
                        return Chip(
                          label: Text(activity.name),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() {
                              _todayActivities.remove(activity);
                            });
                            // Regenerate outfit when activity is removed
                            if (_currentWeather != null) {
                              _generateOutfit(_currentWeather!);
                            }
                          },
                          backgroundColor: theme.colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Your outfit section
                  Text(
                    'Your outfit',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Generate Outfit Button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _currentWeather != null
                              ? () => _generateOutfit(_currentWeather!)
                              : null,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Generate New Outfit'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generatedOutfit != null
                              ? _saveOutfit
                              : null,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save Outfit'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Outfit cards — vertical ordered list (Outerwear → Pullover → Shirt → Bottom → Shoes)
                  if (_generatedOutfit != null)
                    Column(
                      children: [
                        _buildOutfitCard(
                          context,
                          _generatedOutfit!.outerwear,
                          label: 'Outerwear',
                          isLarge: true,
                        ),
                        const SizedBox(height: 16),
                        _buildOutfitCard(
                          context,
                          _generatedOutfit!.pullover,
                          label: 'Pullover',
                          isLarge: true,
                        ),
                        const SizedBox(height: 16),
                        _buildOutfitCard(
                          context,
                          _generatedOutfit!.shirt,
                          label: 'Shirt',
                          isLarge: true,
                        ),
                        const SizedBox(height: 16),
                        _buildOutfitCard(
                          context,
                          _generatedOutfit!.bottom,
                          label: 'Bottom',
                          isLarge: true,
                        ),
                        const SizedBox(height: 16),
                        _buildOutfitCard(
                          context,
                          _generatedOutfit!.shoes,
                          label: 'Shoes',
                          isLarge: true,
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildOutfitCard(
                          context,
                          null,
                          label: 'Outerwear',
                          isLarge: true,
                        ),
                        const SizedBox(height: 16),
                        _buildOutfitCard(
                          context,
                          null,
                          label: 'Pullover',
                          isLarge: true,
                        ),
                        const SizedBox(height: 16),
                        _buildOutfitCard(
                          context,
                          null,
                          label: 'Shirt',
                          isLarge: true,
                        ),
                        const SizedBox(height: 16),
                        _buildOutfitCard(
                          context,
                          null,
                          label: 'Bottom',
                          isLarge: true,
                        ),
                        const SizedBox(height: 16),
                        _buildOutfitCard(
                          context,
                          null,
                          label: 'Shoes',
                          isLarge: true,
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutfitCard(
    BuildContext context,
    ClothingItem? item, {
    bool isLarge = false,
    String label = '',
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: item != null ? () => _showItemDetails(context, item) : null,
      child: Container(
        height: isLarge ? 180 : 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.98),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: item != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Item Image
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child:
                          item.metadata != null &&
                              item.metadata!['imagePath'] != null
                          ? Image.file(
                              File(item.metadata!['imagePath'] as String),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderIcon(theme);
                              },
                            )
                          : _buildPlaceholderIcon(theme),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Item details: Name, Category, Subcategory
                  Column(
                    children: [
                      // Item Name
                      Text(
                        item.metadata?['name'] as String? ?? item.subtype,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Category & Subcategory
                      Text(
                        '${item.category} • ${item.subtype}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Label (e.g., "Shirt", "Outerwear")
                      if (label.isNotEmpty)
                        Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openCategoryChooser(context, label),
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Change'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor: theme.colorScheme.onPrimaryContainer,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.checkroom_outlined,
                    size: 32,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  if (label.isNotEmpty)
                    Column(
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openCategoryChooser(context, label),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Choose alternative'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: theme.colorScheme.outline, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Container(
                          height: 4,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 4,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openCategoryChooser(context, label),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Choose an item'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: theme.colorScheme.outline, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.checkroom_outlined,
        size: 40,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _showItemDetails(BuildContext context, ClothingItem item) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Image
                Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child:
                      item.metadata != null &&
                          item.metadata!['imagePath'] != null
                      ? Image.asset(
                          item.metadata!['imagePath'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderIcon(theme);
                          },
                        )
                      : _buildPlaceholderIcon(theme),
                ),
                const SizedBox(height: 20),
                // Item Name
                Text(
                  item.subtype,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Category
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.category,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Item Details
                Text(
                  'Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Formality', item.attributes.formality, theme),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Warmth Level',
                  item.attributes.warmthLevel.toString(),
                  theme,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Water Resistance',
                  item.attributes.waterResistance.toString(),
                  theme,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Wind Resistance',
                  item.attributes.windResistance.toString(),
                  theme,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Breathability',
                  item.attributes.breathability.toString(),
                  theme,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Stretch',
                  item.attributes.stretch.toString(),
                  theme,
                ),
                const SizedBox(height: 20),
                // Materials
                if (item.attributes.materials.isNotEmpty) ...[
                  Text(
                    'Materials',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.attributes.materials.map((material) {
                      return Chip(
                        label: Text(material),
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        labelStyle: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                // Style Tags
                if (item.attributes.styleTags.isNotEmpty) ...[
                  Text(
                    'Style Tags',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.attributes.styleTags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        labelStyle: TextStyle(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                // Usage Constraints
                Text(
                  'Weather Suitability',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Temperature Range',
                  '${item.usageConstraints.weatherMinTemp}°C - ${item.usageConstraints.weatherMaxTemp}°C',
                  theme,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // Open a chooser allowing the user to pick a different item for the given role label (e.g., "Shirt", "Outerwear")
  Future<void> _openCategoryChooser(BuildContext context, String label) async {
    final wardrobeItems = await _wardrobeService.getWardrobeItems();
    if (wardrobeItems.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No wardrobe items available')));
      return;
    }

    final clothingItems = _convertToClothingItems(wardrobeItems);
    // Filter candidates by best-effort matching rules
    final candidates = clothingItems.where((c) => _matchesRole(c, label)).toList();

    if (candidates.isEmpty) {
      // fallback: try basic category/subtype contains
      final lower = label.toLowerCase();
      candidates.addAll(clothingItems.where((c) => c.category.toLowerCase().contains(lower) || c.subtype.toLowerCase().contains(lower)).toList());
    }

    if (candidates.isEmpty) {
      // last resort: show items from the same broad category (e.g., "tops" for shirt/pullover)
      final map = {
        'shirt': 'top',
        'pullover': 'top',
        'outerwear': 'outer',
        'bottom': 'bottom',
        'shoes': 'shoe',
      };
      final broad = map[label.toLowerCase()] ?? label.toLowerCase();
      candidates.addAll(clothingItems.where((c) => c.category.toLowerCase().contains(broad) || c.subtype.toLowerCase().contains(broad)).toList());
    }

    // Show chooser
    final result = await showModalBottomSheet<ClothingItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Choose $label', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final c = candidates[idx];
                    return ListTile(
                      leading: c.metadata != null && c.metadata!['imagePath'] != null
                        ? Image.file(File(c.metadata!['imagePath'] as String), width: 48, height: 48, fit: BoxFit.cover)
                        : const Icon(Icons.checkroom_outlined, size: 36),
                      title: Text(c.metadata?['name'] as String? ?? c.subtype),
                      subtitle: Text('${c.category} • ${c.subtype}'),
                      onTap: () {
                        Navigator.pop(context, c);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      // Replace piece in generated outfit
      _replaceOutfitPiece(result, label);
    }
  }

  bool _matchesRole(ClothingItem c, String label) {
    final lc = label.toLowerCase();
    final cat = c.category.toLowerCase();
    final sub = c.subtype.toLowerCase();
    if (lc.contains('shirt')) return cat.contains('top') && (sub.contains('shirt') || sub.contains('tshirt') || sub.contains('t-shirt') || sub.contains('tee'));
    if (lc.contains('pullover') || lc.contains('sweater') || lc.contains('hoodie')) return cat.contains('top') && (sub.contains('pullover') || sub.contains('sweater') || sub.contains('hoodie') || sub.contains('jumper'));
    if (lc.contains('outer')) return cat.contains('outer') || sub.contains('jacket') || sub.contains('coat') || sub.contains('parka');
    if (lc.contains('bottom')) return cat.contains('bottom') || sub.contains('jeans') || sub.contains('pants') || sub.contains('trouser') || sub.contains('short');
    if (lc.contains('shoe')) return cat.contains('shoe') || cat.contains('shoe') || sub.contains('shoe') || cat.contains('shoes');
    // default: match by category contains label
    return cat.contains(lc) || sub.contains(lc);
  }

  void _replaceOutfitPiece(ClothingItem selected, String label) {
    if (!mounted) return;
    final old = _generatedOutfit;
    final palette = old?.palette ?? ColorPalette(dominant: const Color(0xFF9E9E9E), accents: const [], neutrals: const []);
    final score = old?.score ?? 0.0;

    Outfit newOutfit = Outfit(
      shirt: old?.shirt,
      pullover: old?.pullover,
      bottom: old?.bottom,
      outerwear: old?.outerwear,
      shoes: old?.shoes,
      accessories: old?.accessories ?? [],
      score: score,
      palette: palette,
    );

    final lc = label.toLowerCase();
    if (lc.contains('shirt')) {
      newOutfit = Outfit(shirt: selected, pullover: newOutfit.pullover, bottom: newOutfit.bottom, outerwear: newOutfit.outerwear, shoes: newOutfit.shoes, accessories: newOutfit.accessories, score: newOutfit.score, palette: newOutfit.palette);
    } else if (lc.contains('pullover')) newOutfit = Outfit(shirt: newOutfit.shirt, pullover: selected, bottom: newOutfit.bottom, outerwear: newOutfit.outerwear, shoes: newOutfit.shoes, accessories: newOutfit.accessories, score: newOutfit.score, palette: newOutfit.palette);
    else if (lc.contains('bottom')) newOutfit = Outfit(shirt: newOutfit.shirt, pullover: newOutfit.pullover, bottom: selected, outerwear: newOutfit.outerwear, shoes: newOutfit.shoes, accessories: newOutfit.accessories, score: newOutfit.score, palette: newOutfit.palette);
    else if (lc.contains('outer')) newOutfit = Outfit(shirt: newOutfit.shirt, pullover: newOutfit.pullover, bottom: newOutfit.bottom, outerwear: selected, shoes: newOutfit.shoes, accessories: newOutfit.accessories, score: newOutfit.score, palette: newOutfit.palette);
    else if (lc.contains('shoe')) newOutfit = Outfit(shirt: newOutfit.shirt, pullover: newOutfit.pullover, bottom: newOutfit.bottom, outerwear: newOutfit.outerwear, shoes: selected, accessories: newOutfit.accessories, score: newOutfit.score, palette: newOutfit.palette);
    else {
      // fallback: try to set based on category
      if (selected.category.toLowerCase().contains('top')) newOutfit = Outfit(shirt: selected, pullover: newOutfit.pullover, bottom: newOutfit.bottom, outerwear: newOutfit.outerwear, shoes: newOutfit.shoes, accessories: newOutfit.accessories, score: newOutfit.score, palette: newOutfit.palette);
    }

    setState(() {
      _generatedOutfit = newOutfit;
    });
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showLocationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ort wählen',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListView.builder(
                shrinkWrap: true,
                itemCount: _locations.length,
                itemBuilder: (context, index) {
                  final location = _locations[index];
                  final isSelected = location == _selectedLocation;
                  return ListTile(
                    leading: Icon(
                      Icons.location_on,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      location,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      _onLocationChanged(location);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddActivityDialog(BuildContext context) {
    String? selectedActivityCategory;
    String? selectedActivitySubcategory;
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Build grouped activities: Map<GroupLabel, List<activityKey>>
            final Map<String, List<String>> groupedActivities = {};

            if (_activitiesData.containsKey('activities')) {
              final activities = _activitiesData['activities'];
              if (activities is Map<String, dynamic>) {
                activities.forEach((category, subcategoriesMap) {
                  if (subcategoriesMap is Map<String, dynamic>) {
                    subcategoriesMap.forEach((groupKey, subList) {
                      if (subList is List) {
                        final groupLabel = _formatActivityKey(groupKey);
                        groupedActivities.putIfAbsent(groupLabel, () => []);
                        groupedActivities[groupLabel]!
                            .addAll(List<String>.from(subList));
                      }
                    });
                  }
                });
              }
            }

            // Deduplicate and sort activities within each group
            final sortedGroupKeys = groupedActivities.keys.toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            for (final key in sortedGroupKeys) {
              final unique = groupedActivities[key]!.toSet().toList();
              unique.sort((a, b) => _formatActivityKey(a)
                  .toLowerCase()
                  .compareTo(_formatActivityKey(b).toLowerCase()));
              groupedActivities[key] = unique;
            }

            return AlertDialog(
              title: const Text('Aktivität hinzufügen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search field
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Suchen',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setDialogState(() {
                                    searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value.trim().toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aktivitäten',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Groups as ExpansionTiles
                    ...sortedGroupKeys.map((groupLabel) {
                      // Filter activities by search query
                      final activities = groupedActivities[groupLabel]!
                          .where((act) {
                        final label = _formatActivityKey(act).toLowerCase();
                        return searchQuery.isEmpty ||
                            label.contains(searchQuery) ||
                            act.toLowerCase().contains(searchQuery);
                      }).toList();

                      if (activities.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ExpansionTile(
                          title: Text(
                            groupLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: activities.map((activity) {
                                  final isSelected =
                                      selectedActivitySubcategory == activity;
                                  return FilterChip(
                                    label: Text(_formatActivityKey(activity)),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setDialogState(() {
                                        selectedActivitySubcategory = selected
                                            ? activity
                                            : null;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: selectedActivitySubcategory != null
                      ? () {
                          setState(() {
                            _todayActivities.add(
                              Activity(
                                id: DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                name: _formatActivityKey(
                                  selectedActivitySubcategory!,
                                ),
                                style: ActivityStyle.casual,
                                type: _mapActivityToType(
                                    selectedActivitySubcategory!),
                              ),
                            );
                          });
                          if (_currentWeather != null) {
                            _generateOutfit(_currentWeather!);
                          }
                          Navigator.pop(context);
                        }
                      : null,
                  child: const Text('Hinzufügen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Get all subcategories from all activity categories
  List<String> _getAllActivitySubcategories() {
    final List<String> allSubcategories = [];

    if (_activitiesData.containsKey('activities')) {
      final activities = _activitiesData['activities'];
      if (activities is Map<String, dynamic>) {
        activities.forEach((category, subcategoriesMap) {
          if (subcategoriesMap is Map<String, dynamic>) {
            subcategoriesMap.forEach((group, subList) {
              if (subList is List) {
                allSubcategories.addAll(List<String>.from(subList));
              }
            });
          }
        });
      }
    }

    return allSubcategories.toSet().toList(); // Remove duplicates and return
  }

  /// Get all activity categories from JSON
  List<String> _getAllActivityCategories() {
    if (_activitiesData.containsKey('activities')) {
      final activities = _activitiesData['activities'];
      if (activities is Map<String, dynamic>) {
        return activities.keys.toList();
      }
    }
    return [];
  }

  /// Format activity key to readable string
  String _formatActivityKey(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Map activity category to ActivityType
  ActivityType _mapActivityToType(String activityKey) {
    switch (activityKey.toLowerCase()) {
      case 'sports':
        return ActivityType.sport;
      case 'events':
        return ActivityType.feiern;
      case 'outdoor':
        return ActivityType.spazierengehen;
      case 'work':
        return ActivityType.meetings;
      case 'casual':
        return ActivityType.other;
      default:
        return ActivityType.other;
    }
  }

  String _getWeatherDescription(String? condition) {
    return WeatherConditions.getGermanDescription(
      condition,
      temperature: _currentWeather?.temperature,
      windSpeed: _currentWeather?.windSpeed,
      cloudCover: _currentWeather?.cloudCover,
    );
  }

  Widget _buildWeatherDetail(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
