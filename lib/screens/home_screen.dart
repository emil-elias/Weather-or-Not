import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:weatherornot/models/forecast.dart';
import 'package:weatherornot/models/wardrobe_item.dart';
import 'package:weatherornot/screens/weather_screen.dart';
import 'package:weatherornot/services/outfit_generator.dart';
import 'package:weatherornot/services/outfit_storage_service.dart';
import 'package:weatherornot/providers/main_provider.dart';
import 'package:weatherornot/widgets/location_dropdown.dart';
import 'package:weatherornot/widgets/weather_card.dart';
import '../services/weather_service.dart';
import '../services/wardrobe_service.dart';
import '../services/planner_service.dart';
import '../models/weather.dart';
import '../models/activity.dart';
import '../models/outfit.dart';
import '../models/saved_outfit.dart';
import '../constants/app_constants.dart';
import '../services/location_service.dart';
import '../services/preferences_service.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  final String? title;
  final int? forecastIndex;
  final bool live;
  const HomeScreen({
    super.key,
    required this.live,
    this.title,
    this.forecastIndex,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  final WardrobeService _wardrobeService = WardrobeService();
  final OutfitStorageService _outfitStorageService = OutfitStorageService();

  final LocationService _locationService = LocationService();

  MainProvider _provider = MainProvider();

  Map<String, dynamic> _selectedLocation = {
    "name": 'BREMEN',
    "id": "10224",
    "lat": 53.0451,
    "lon": 8.7981,
  };
  Weather? _currentWeather;
  Forecast? _forecast;
  Outfit? _generatedOutfit;
  Set<String> _washingItemIds = <String>{};
  bool? _isLoading;
  String? _errorMessage;
  Map<String, dynamic> _subtypesAttributesData = {};
  // Activities loaded from JSON
  Map<String, dynamic> _activitiesData = {};
  List<String> _availableActivities = [];

  // Location coordinates
  final Map<String, Map<String, double>> _locationCoordinates = {
    'BREMEN': {'lat': 53.0793, 'lon': 8.8017},
    'HAMBURG': {'lat': 53.5511, 'lon': 9.9937},
    'BERLIN': {'lat': 52.5200, 'lon': 13.4050},
    'MÜNCHEN': {'lat': 48.1351, 'lon': 11.5820},
    'KÖLN': {'lat': 50.9375, 'lon': 6.9603},
    'LISBON': {'lat': 38.47, 'lon': -9.08},
  };
  List<String> _locations = [];

  final List<Activity> _todayActivities = [];
  final PlannerService _plannerService = PlannerService();

  @override
  void initState() {
    //_isLoading = true;
    super.initState();
    //_provider.addListener(providerCallback);
    //_provider = context.watch<MainProvider>();
    _initAsync();
  }

  void providerCallback() {
    //_loadOrGenerateOutfit();
    if (_provider.currentWeather != null && !_provider.isLoading) {
      _loadOrGenerateOutfit();
    }
  }

  Future<void> _initAsync() async {
    await _loadActivitiesFromAssets();
    await _loadSubtypesAttributesFromAssets();
    //await _loadWeather();
    await _syncTodayActivitiesWithPlanner();
    while (_provider.currentWeather == null && _provider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await _loadOrGenerateOutfit();
  }

  @override
  /*void didChangeDependencies() {
    super.didChangeDependencies();

    //final provider = context.watch<MainProvider>();

    // Check if provider has loaded and we haven't initialized yet
    if (_provider.currentWeather != null && !_provider.isLoading) {
      if (mounted) {
        _loadOrGenerateOutfit();
      }
    }
  }*/
  /// Get the date for the outfit being displayed
  DateTime _getDisplayDate() {
    if (widget.forecastIndex == null || widget.forecastIndex == 0) {
      return DateTime.now();
    }
    return DateTime.now().add(Duration(days: widget.forecastIndex!));
  }

  Future<void> _syncTodayActivitiesWithPlanner() async {
    final displayDate = _getDisplayDate();
    final planned = await _plannerService.getMergedDayActivities(displayDate);
    setState(() {
      _todayActivities.clear();
      for (final activityName in planned) {
        final isWeekly = activityName.startsWith('R:');
        _todayActivities.add(
          Activity(
            id: activityName,
            name: _formatActivityKey(activityName),
            style: ActivityStyle.casual,
            isWeekly: isWeekly,
            type: _mapActivityToType(activityName),
          ),
        );
      }
    });
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
      //_isLoading = true;
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
        locationName: _selectedLocation["name"],
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
        //_isLoading = false;
      });

      //await _generateOutfit(weather, forecast);
      await _loadOrGenerateOutfit();
    } catch (e) {
      setState(() {
        _errorMessage = 'Wetter konnte nicht geladen werden';
        //_isLoading = false;
      });
    }
  }

  Future<void> _loadOrGenerateOutfit() async {
    try {
      final displayDate = _getDisplayDate();

      // Try to load stored outfit for the display date
      final storedOutfit = await _outfitStorageService.getOutfitForDate(
        displayDate,
      );

      if (storedOutfit != null &&
          storedOutfit.stationID != null &&
          storedOutfit.stationID == _selectedLocation["id"]) {
        // Use stored outfit
        await _hasOutfitItemsInWash(storedOutfit);
        setState(() {
          _generatedOutfit = storedOutfit;
        });
        print('HomeScreen: Loaded stored outfit for $displayDate');
        return;
      }

      // If no stored outfit, wait for weather to be loaded then generate one
      if (_currentWeather != null) {
        await _generateOutfit(_currentWeather!, _forecast);

        // Save the generated outfit for the display date
        if (_generatedOutfit != null) {
          await _outfitStorageService.saveOutfitForDate(
            displayDate,
            _generatedOutfit!,
            _selectedLocation["id"],
          );
          print('HomeScreen: Generated and stored outfit for $displayDate');
        }
      }
    } catch (e) {
      print('Error loading or generating outfit: $e');
    }
  }

  Future<void> _generateOutfit(Weather weather, Forecast? forecast) async {
    try {
      // Fetch wardrobe items from storage
      final wardrobeItems = await _wardrobeService.getWardrobeItems();

      if (wardrobeItems.isEmpty) {
        print('No wardrobe items available');
        return;
      }

      // Filter out items that are currently in wash
      final availableItems = wardrobeItems
          .where((item) => !item.isInWash)
          .toList();

      if (availableItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No clothes available. All items are in the wash!'),
          ),
        );
        return;
      }

      // Convert WardrobeItem to ClothingItem
      final clothingItems = _convertToClothingItems(availableItems);

      // Create outfit engine
      final outfitEngine = OutfitEngine(clothingItems);

      // Build activities list from planner (source of truth), default to 'daily'
      final displayDate = _getDisplayDate();
      final plannedActivities = await _plannerService.getMergedDayActivities(
        displayDate,
      );
      final activities = plannedActivities.isNotEmpty
          ? plannedActivities.map(_normalizeActivityKey).toList()
          : ['daily'];

      // Load user preferences (transportation method and warm/cold thresholds)
      final prefs = PreferencesService();
      final transportation = await prefs.getTransportation();
      final coldThreshold = await prefs.getColdThreshold();
      final warmThreshold = await prefs.getWarmThreshold();

      // Add transportation as an activity (lowercased) so engine can consider it in optimalActivities/unsuitableFor
      if (transportation.trim().isNotEmpty) {
        activities.add(transportation.toLowerCase());
      }

      // Compute rain probability from precipitation or condition
      double rainProbability = 0.0;
      if (weather.precipitation != null) {
        rainProbability = (weather.precipitation! / 5.0).clamp(0.0, 1.0);
      } else if (forecast != null) {
        final now = DateTime.now();
        final hourIndex = forecast.start != null
            ? now.difference(forecast.start!).inHours
            : 0;
        if (hourIndex >= 0 &&
            forecast.precipitation != null &&
            hourIndex < forecast.precipitation!.length) {
          rainProbability = (forecast.precipitation![hourIndex] / 5.0).clamp(
            0.0,
            1.0,
          );
        } else if (forecast.days != null && forecast.days!.isNotEmpty) {
          int index =
              widget.forecastIndex != null &&
                  widget.forecastIndex! < forecast.days!.length
              ? widget.forecastIndex!
              : 0;
          final dailyPrecipitation = forecast.days![index].precipitation ?? 0.0;
          rainProbability = (dailyPrecipitation / 5.0).clamp(0.0, 1.0);
        }
      } else if (weather.condition != null &&
          weather.condition!.toLowerCase().contains('rain')) {
        rainProbability = 0.8;
      }

      double windSpeed = 0.0;

      if (weather.windSpeed != null) {
        windSpeed = weather.windSpeed!;
      } else if (forecast != null) {
        final now = DateTime.now();
        final hourIndex = forecast.start != null
            ? now.difference(forecast.start!).inHours
            : 0;
        if (hourIndex >= 0 &&
            forecast.windSpeed != null &&
            hourIndex < forecast.windSpeed!.length) {
          windSpeed = forecast.windSpeed![hourIndex];
        } else if (forecast.days != null && forecast.days!.isNotEmpty) {
          if (widget.forecastIndex != null &&
              widget.forecastIndex! < forecast.days!.length) {
            windSpeed = forecast.days![widget.forecastIndex!].windSpeed ?? 0.0;
          } else {
            windSpeed = forecast.days!.first.windSpeed ?? 0.0;
          }
        }
      }

      double temp = 15.0;

      if (weather.temperature != null) {
        temp = weather.temperature!;
      } else if (forecast != null) {
        final now = DateTime.now();
        final hourIndex = forecast.start != null
            ? now.difference(forecast.start!).inHours
            : 0;
        if (hourIndex >= 0 &&
            forecast.temperature != null &&
            hourIndex < forecast.temperature!.length) {
          temp = forecast.temperature![hourIndex];
        } else if (forecast.days != null && forecast.days!.isNotEmpty) {
          int index =
              widget.forecastIndex != null &&
                  widget.forecastIndex! < forecast.days!.length
              ? widget.forecastIndex!
              : 0;
          final highTemp = forecast.days![index].maxTemperature ?? 15.0;
          final lowTemp = forecast.days![index].minTemperature ?? 15.0;
          temp = (highTemp + lowTemp) / 2.0;
        }
      }

      // Generate multiple outfits and randomly select from top 5
      final outfits = outfitEngine.generateOutfits(
        temperature: temp,
        activities: activities,
        rainProbability: rainProbability,
        windSpeed: windSpeed,
        weatherCondition: weather.condition,
        coldThreshold: coldThreshold,
        warmThreshold: warmThreshold,
        topNPerCategory: 3,
        maxOutfits: 5,
      );

      if (outfits.isNotEmpty) {
        // Randomly select from top 5 outfits
        final random = Random();
        final selectedOutfit = outfits[random.nextInt(outfits.length)];
        await _hasOutfitItemsInWash(selectedOutfit);

        setState(() {
          _generatedOutfit = selectedOutfit;
        });

        // Save the generated outfit for the display date
        final displayDate = _getDisplayDate();
        await _outfitStorageService.saveOutfitForDate(
          displayDate,
          selectedOutfit,
          _selectedLocation["id"],
        );
        print('HomeScreen: Generated and saved outfit for $displayDate');
      }
    } catch (e) {
      print('Error generating outfit: $e');
    }
  }

  Future<void> _saveOutfit() async {
    if (_generatedOutfit == null) return;

    try {
      // Show dialog to name the outfit
      final TextEditingController nameController = TextEditingController();
      final theme = Theme.of(context);
      final outfitName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save Outfit'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Outfit Name',
              hintText: 'e.g., Casual Monday, Sport Day',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save outfit')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
  List<ClothingItem> _convertToClothingItems(List<WardrobeItem> wardrobeItems) {
    return wardrobeItems.map((item) {
      return item.toClothingItem(_subtypesAttributesData);
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

  void _onLocationChanged(Map<String, dynamic>? newLocation) async {
    if (newLocation != null && newLocation != _provider.selectedLocation) {
      _provider.setSelectedLocation(newLocation);

      final List<Map<String, dynamic>> closestList = await _locationService
          .findClosestLocation(newLocation['lat'], newLocation['lon']);
      final newWeather = await _provider.loadWeather(
        newLocation["id"],
        newLocation["name"],
        fallbackStations: closestList
            .where((loc) => loc['name'] != newLocation["name"])
            .toList(),
      );

      await _generateOutfit(newWeather['weather'], newWeather['forecast']);
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
    //_isLoading = context.watch<MainProvider>().isLoading;
    _errorMessage = context.watch<MainProvider>().errorMessage;
    _selectedLocation = context.watch<MainProvider>().selectedLocation;
    _locations = context.watch<MainProvider>().locations;
    /*_currentWeather = _provider.currentWeather;
    _forecast = _provider.forecast;
    _isLoading = _provider.isLoading;
    _errorMessage = _provider.errorMessage;
    _selectedLocation = _provider.selectedLocation;
    _locations = _provider.locations;*/

    // Determine display title based on date
    final displayDate = _getDisplayDate();
    final isToday =
        displayDate.day == DateTime.now().day &&
        displayDate.month == DateTime.now().month &&
        displayDate.year == DateTime.now().year;
    final displayTitle = isToday
        ? 'Today'
        : (widget.title ?? _formatDate(displayDate));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (route, result) {
        if (homeNavigatorKey.currentState != null &&
            homeNavigatorKey.currentState!.canPop()) {
          homeNavigatorKey.currentState!.pop(result);
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Navigator(
          key: homeNavigatorKey,
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: 12,
                  left: 24,
                  right: 24,
                  bottom: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (Navigator.canPop(context))
                                Transform.translate(
                                  offset: const Offset(
                                    -12,
                                    0,
                                  ), // Shift the button 8 pixels to the left
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Back',
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ),
                              //const SizedBox(width: 0),
                              Flexible(
                                child: Text(
                                  displayTitle,
                                  style: displayTitle == "Today"
                                      ? theme.textTheme.headlineLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        )
                                      : theme.textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        LocationDropdown(
                          selectedLocation: _selectedLocation,
                          onLocationChanged: _onLocationChanged,
                          closestLocations: _provider.closestLocations,
                          locationAccessDenied: _provider.locationAccessDenied,
                          onRequestLocationPermission: () =>
                              _provider.getClosestLocation(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    /*if (_provider.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else*/
                    WeatherCard(
                      isLoading: _provider.isLoading,
                      errorMessage: _errorMessage,
                      currentWeather: widget.live == true
                          ? _currentWeather
                          : null,
                      forecast: _forecast,
                      forecastIndex: widget.forecastIndex,
                      onTap: widget.live == true && _currentWeather?.icon != 32
                          ? () {
                              homeNavigatorKey.currentState?.push(
                                MaterialPageRoute(
                                  builder: (context) => const WeatherScreen(),
                                ),
                              );
                            }
                          : null,
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
                              'Add activities for ${isToday ? 'today' : displayTitle.toLowerCase()}',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
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
                            onDeleted: () async {
                              final displayDate = _getDisplayDate();
                              await _deleteActivity(
                                displayDate,
                                activity,
                                activity.isWeekly,
                              );

                              /*setState(() {
                                _todayActivities.remove(activity);
                              });*/
                              // Remove from planner

                              /*await _plannerService.removeActivityFromDay(
                                displayDate,
                                activity.name.toLowerCase().replaceAll(
                                  ' ',
                                  '_',
                                ),
                                false,
                              );*/

                              // Regenerate outfit when activity is removed
                              /*if (_currentWeather != null) {
                                _generateOutfit(_currentWeather!);
                              }*/
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
                                ? () => _generateOutfit(
                                    _currentWeather!,
                                    _forecast,
                                  )
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
                    else if (!_provider.isLoading)
                      Center(
                        child: Text(
                          "Add Items to your wardrobe to get outfit suggestions",
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isItemInWash(ClothingItem item) {
    return _washingItemIds.contains(item.id);
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
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: fixed square image area with in-wash overlay
                  Stack(
                    children: [
                      Container(
                        width: isLarge ? 140 : 120,
                        height: isLarge ? 140 : 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              item.metadata != null &&
                                  item.metadata!['imagePath'] != null
                              ? Image.file(
                                  File(item.metadata!['imagePath'] as String),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: _buildPlaceholderIcon(theme),
                                    );
                                  },
                                )
                              : Center(child: _buildPlaceholderIcon(theme)),
                        ),
                      ),
                      if (_isItemInWash(item))
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
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
                              color: theme.colorScheme.onError,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Right: info and change button
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Item name
                        Text(
                          item.metadata?['name'] as String? ?? item.subtype,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Category & Subtype
                        Text(
                          '${item.category} • ${item.subtype}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (label.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () =>
                                _openCategoryChooser(context, label),
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: const Text('Change'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              foregroundColor:
                                  theme.colorScheme.onPrimaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: isLarge ? 140 : 120,
                    height: isLarge ? 140 : 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: Icon(
                          Icons.checkroom_outlined,
                          size: 32,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (label.isNotEmpty) ...[
                          Text(
                            label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _openCategoryChooser(context, label),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Choose alternative'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                side: BorderSide(
                                  color: theme.colorScheme.outline,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // empty placeholder layout to keep consistent sizing
                          const SizedBox(height: 4),
                        ],
                      ],
                    ),
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
    //print("item category ${item.category}");
    //print("item subtype ${item.subtype}");
    //print("item attributes ${item.attributes.formality}");
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
                      ? Image.file(
                          File(item.metadata!['imagePath'] as String),
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
    if (!mounted) return;

    final wardrobeItems = await _wardrobeService.getWardrobeItems();
    if (wardrobeItems.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No wardrobe items available')),
        );
      return;
    }

    final clothingItems = _convertToClothingItems(wardrobeItems);
    // Filter candidates by best-effort matching rules
    final candidates = clothingItems
        .where((c) => _matchesRole(c, label))
        .toList();

    if (candidates.isEmpty) {
      // fallback: try basic category/subtype contains
      final lower = label.toLowerCase();
      candidates.addAll(
        clothingItems
            .where(
              (c) =>
                  c.category.toLowerCase().contains(lower) ||
                  c.subtype.toLowerCase().contains(lower),
            )
            .toList(),
      );
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
      candidates.addAll(
        clothingItems
            .where(
              (c) =>
                  c.category.toLowerCase().contains(broad) ||
                  c.subtype.toLowerCase().contains(broad),
            )
            .toList(),
      );
    }

    if (!mounted) return;

    // Show chooser
    final result = await showModalBottomSheet<ClothingItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choose $label',
                      style: theme.textTheme.titleLarge?.copyWith(
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
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final c = candidates[idx];
                    return ListTile(
                      leading:
                          c.metadata != null && c.metadata!['imagePath'] != null
                          ? Image.file(
                              File(c.metadata!['imagePath'] as String),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            )
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

  /// Check if any items in the outfit are in wash
  Future<bool> _hasOutfitItemsInWash(Outfit? outfit) async {
    if (outfit == null) {
      if (mounted) {
        setState(() {
          _washingItemIds.clear();
        });
      }
      return false;
    }

    final wardrobeItems = await _wardrobeService.getWardrobeItems();
    final outfitItems = [
      outfit.shirt,
      outfit.pullover,
      outfit.bottom,
      outfit.outerwear,
      outfit.shoes,
      ...outfit.accessories,
    ].whereType<ClothingItem>().toList();

    final inWashIds = <String>{};

    for (final outfitItem in outfitItems) {
      for (final wardrobeItem in wardrobeItems) {
        if (wardrobeItem.id == outfitItem.id && wardrobeItem.isInWash) {
          inWashIds.add(outfitItem.id);
          break;
        }
      }
    }

    if (mounted) {
      setState(() {
        _washingItemIds = inWashIds;
      });
    }

    return inWashIds.isNotEmpty;
  }

  bool _matchesRole(ClothingItem c, String label) {
    final lc = label.toLowerCase();
    final cat = c.category.toLowerCase();
    final sub = c.subtype.toLowerCase();
    if (lc.contains('shirt'))
      return cat.contains('top') &&
          (sub.contains('shirt') ||
              sub.contains('tshirt') ||
              sub.contains('t-shirt') ||
              sub.contains('tee'));
    if (lc.contains('pullover') ||
        lc.contains('sweat') ||
        lc.contains('hoodie'))
      return cat.contains("sweat") ||
          cat.contains("knitwear") ||
          (sub.contains('pullover') ||
              sub.contains('sweat') ||
              sub.contains('hoodie') ||
              sub.contains('jumper'));
    if (lc.contains('outer'))
      return cat.contains('outer') ||
          sub.contains('jacket') ||
          sub.contains('coat') ||
          sub.contains('parka');
    if (lc.contains('bottom'))
      return cat.contains('bottom') ||
          sub.contains('jeans') ||
          sub.contains('pants') ||
          sub.contains('trouser') ||
          sub.contains('short');
    if (lc.contains('shoe'))
      return cat.contains('shoe') ||
          cat.contains('shoe') ||
          sub.contains('shoe') ||
          cat.contains('shoes');
    // default: match by category contains label
    return cat.contains(lc) || sub.contains(lc);
  }

  void _replaceOutfitPiece(ClothingItem selected, String label) {
    if (!mounted) return;
    final old = _generatedOutfit;
    final palette =
        old?.palette ??
        ColorPalette(
          dominant: const Color(0xFF9E9E9E),
          accents: const [],
          neutrals: const [],
        );
    final score = old?.score ?? 0.0;

    Outfit newOutfit = Outfit(
      shirt: old?.shirt,
      pullover: old?.pullover,
      bottom: old?.bottom,
      outerwear: old?.outerwear,
      shoes: old?.shoes,
      accessories: old?.accessories ?? [],
      score: score,
      baseScore: old?.baseScore ?? score,
      styleScore: old?.styleScore ?? 0.0,
      colorScore: old?.colorScore ?? 0.0,
      palette: palette,
    );

    final lc = label.toLowerCase();
    if (lc.contains('shirt')) {
      newOutfit = Outfit(
        shirt: selected,
        pullover: newOutfit.pullover,
        bottom: newOutfit.bottom,
        outerwear: newOutfit.outerwear,
        shoes: newOutfit.shoes,
        accessories: newOutfit.accessories,
        score: newOutfit.score,
        baseScore: newOutfit.baseScore,
        styleScore: newOutfit.styleScore,
        colorScore: newOutfit.colorScore,
        palette: newOutfit.palette,
      );
    } else if (lc.contains('pullover'))
      newOutfit = Outfit(
        shirt: newOutfit.shirt,
        pullover: selected,
        bottom: newOutfit.bottom,
        outerwear: newOutfit.outerwear,
        shoes: newOutfit.shoes,
        accessories: newOutfit.accessories,
        score: newOutfit.score,
        baseScore: newOutfit.baseScore,
        styleScore: newOutfit.styleScore,
        colorScore: newOutfit.colorScore,
        palette: newOutfit.palette,
      );
    else if (lc.contains('bottom'))
      newOutfit = Outfit(
        shirt: newOutfit.shirt,
        pullover: newOutfit.pullover,
        bottom: selected,
        outerwear: newOutfit.outerwear,
        shoes: newOutfit.shoes,
        accessories: newOutfit.accessories,
        score: newOutfit.score,
        baseScore: newOutfit.baseScore,
        styleScore: newOutfit.styleScore,
        colorScore: newOutfit.colorScore,
        palette: newOutfit.palette,
      );
    else if (lc.contains('outer'))
      newOutfit = Outfit(
        shirt: newOutfit.shirt,
        pullover: newOutfit.pullover,
        bottom: newOutfit.bottom,
        outerwear: selected,
        shoes: newOutfit.shoes,
        accessories: newOutfit.accessories,
        score: newOutfit.score,
        baseScore: newOutfit.baseScore,
        styleScore: newOutfit.styleScore,
        colorScore: newOutfit.colorScore,
        palette: newOutfit.palette,
      );
    else if (lc.contains('shoe'))
      newOutfit = Outfit(
        shirt: newOutfit.shirt,
        pullover: newOutfit.pullover,
        bottom: newOutfit.bottom,
        outerwear: newOutfit.outerwear,
        shoes: selected,
        accessories: newOutfit.accessories,
        score: newOutfit.score,
        baseScore: newOutfit.baseScore,
        styleScore: newOutfit.styleScore,
        colorScore: newOutfit.colorScore,
        palette: newOutfit.palette,
      );
    else {
      // fallback: try to set based on category
      if (selected.category.toLowerCase().contains('top'))
        newOutfit = Outfit(
          shirt: selected,
          pullover: newOutfit.pullover,
          bottom: newOutfit.bottom,
          outerwear: newOutfit.outerwear,
          shoes: newOutfit.shoes,
          accessories: newOutfit.accessories,
          score: newOutfit.score,
          baseScore: newOutfit.baseScore,
          styleScore: newOutfit.styleScore,
          colorScore: newOutfit.colorScore,
          palette: newOutfit.palette,
        );
    }

    setState(() {
      _generatedOutfit = newOutfit;
    });

    // Save the modified outfit to storage for today
    _saveModifiedOutfit(newOutfit);
  }

  Future<void> _saveModifiedOutfit(Outfit outfit) async {
    try {
      final displayDate = _getDisplayDate();
      await _outfitStorageService.saveOutfitForDate(
        displayDate,
        outfit,
        _selectedLocation["id"],
      );
      await _hasOutfitItemsInWash(outfit);

      print('HomeScreen: Saved modified outfit for $displayDate');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Outfit saved'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error saving modified outfit: $e');
    }
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

  Future<bool> _deleteActivity(
    DateTime displayDate,
    Activity activity,
    bool isWeekly,
  ) async {
    final activityName = activity.name.toLowerCase().replaceAll(' ', '_');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${activity.name}?'),
        content: isWeekly
            ? Text(
                'This is a recurring activity. Choose whether to remove it only from this day or from all future occurrences.',
              )
            : Text('This activity will be removed from this day.'),
        actions: [
          if (!isWeekly)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          if (isWeekly)
            FilledButton(
              onPressed: () => {
                Navigator.pop(context, null),
                _plannerService.removeActivityFromDay(
                  displayDate,
                  'R:$activityName',
                  false,
                ),
                setState(() {
                  _todayActivities.remove(activity);
                }),
                if (_currentWeather != null)
                  {_generateOutfit(_currentWeather!, _forecast)},
              },
              child: const Text('Remove from all days'),
            ),
          FilledButton(
            onPressed: () => {
              Navigator.pop(context, true),
              _plannerService.removeActivityFromDay(
                displayDate,
                isWeekly ? 'R:$activityName' : activityName,
                true,
              ),
              setState(() {
                _todayActivities.remove(activity);
              }),
              if (_currentWeather != null)
                {_generateOutfit(_currentWeather!, _forecast)},
            },
            child: const Text('Remove from this day'),
          ),
          if (isWeekly)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
        ],
      ),
    );

    return confirmed == true;
  }

  void _showAddActivityDialog(BuildContext context) {
    String? selectedActivityCategory;
    String? selectedActivitySubcategory;
    List<String> selectedActivities = [];
    String searchQuery = '';
    String recurrenceOption = 'once';

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
                        groupedActivities[groupLabel]!.addAll(
                          List<String>.from(subList),
                        );
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
              unique.sort(
                (a, b) => _formatActivityKey(
                  a,
                ).toLowerCase().compareTo(_formatActivityKey(b).toLowerCase()),
              );
              groupedActivities[key] = unique;
            }

            return AlertDialog(
              title: const Text('Add activity'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Search field
                            TextField(
                              decoration: InputDecoration(
                                filled: false,
                                hintText: 'Search',
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
                              'Activities',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),

                            // Groups as ExpansionTiles
                            ...sortedGroupKeys.map((groupLabel) {
                              // Filter activities by search query
                              final activities = groupedActivities[groupLabel]!
                                  .where((act) {
                                    final label = _formatActivityKey(
                                      act,
                                    ).toLowerCase();
                                    return searchQuery.isEmpty ||
                                        label.contains(searchQuery) ||
                                        act.toLowerCase().contains(searchQuery);
                                  })
                                  .toList();

                              if (activities.isEmpty)
                                return const SizedBox.shrink();

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
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: activities.map((activity) {
                                          final isSelected = selectedActivities
                                              .contains(activity);
                                          return FilterChip(
                                            label: Text(
                                              _formatActivityKey(activity),
                                            ),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              setDialogState(() {
                                                if (selected) {
                                                  selectedActivities.add(
                                                    activity,
                                                  );
                                                } else {
                                                  selectedActivities.remove(
                                                    activity,
                                                  );
                                                }
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
                    ),
                    const SizedBox(height: 16),
                    // Dropdown for activity recurrence
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Do this... ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        DropdownButton<String>(
                          value: recurrenceOption,
                          items: [
                            DropdownMenuItem(
                              value: 'once',
                              child: Text('only this day'),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text(
                                'every ${DateFormat('EEEE').format(_getDisplayDate())}',
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              recurrenceOption = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedActivities.isNotEmpty
                      ? () async {
                          setState(() {
                            for (final activity in selectedActivities) {
                              final isWeekly = recurrenceOption == 'weekly';
                              _todayActivities.add(
                                Activity(
                                  id: isWeekly ? 'R:$activity' : activity,
                                  name: _formatActivityKey(activity),
                                  style: ActivityStyle.casual,
                                  type: _mapActivityToType(activity),
                                  isWeekly: isWeekly,
                                ),
                              );
                            }
                          });
                          final displayDate = _getDisplayDate();
                          for (final activity in selectedActivities) {
                            await _plannerService.addActivityToDay(
                              displayDate,
                              activity,
                              recurrenceOption,
                            );
                          }

                          if (_currentWeather != null) {
                            _generateOutfit(_currentWeather!, _forecast);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${selectedActivities.length} activities added',
                                ),
                              ),
                            );
                            Navigator.pop(context);
                          }
                        }
                      : null,
                  child: const Text('Add'),
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
        .replaceFirst('R:', '')
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _normalizeActivityKey(String key) {
    return key.replaceFirst('R:', '').trim().toLowerCase().replaceAll(' ', '_');
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

  String _formatDate(DateTime date) {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
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
