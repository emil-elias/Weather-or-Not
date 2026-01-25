import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:weatherornot/models/weather.dart';
import 'package:weatherornot/providers/main_provider.dart';
import 'package:weatherornot/screens/home_screen.dart';
import 'package:weatherornot/services/planner_service.dart';
import 'package:weatherornot/services/wardrobe_service.dart';
import 'package:weatherornot/services/preferences_service.dart';
import 'package:weatherornot/services/outfit_generator.dart';
import 'package:weatherornot/services/outfit_storage_service.dart';
import 'package:weatherornot/models/outfit.dart';
import 'package:weatherornot/widgets/weather_card.dart';
import 'package:weatherornot/widgets/outfit_details_sheet.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PlannerService _plannerService = PlannerService();
  final WardrobeService _wardrobeService = WardrobeService();
  final PreferencesService _preferencesService = PreferencesService();
  final OutfitStorageService _outfitStorageService = OutfitStorageService();
  final Map<String, Outfit> _plannedOutfits = {}; // dateKey -> Outfit
  final Map<String, Set<String>> _inWashItemIdsByDate =
      {}; // dateKey -> ids of items in wash

  // Activities data
  Map<String, dynamic> _activitiesData = {};

  // Calendar
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  // Day activities mapping
  Map<String, List<String>> _dayActivitiesMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadActivitiesFromAssets();
    _loadAllDayActivities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    } catch (e) {
      print('Error loading activities: $e');
    }
  }

  /// Get all activity subcategories
  List<String> _getAllActivitySubcategories() {
    //final List<String> allSubcategories = [];
    final Map<String, List<String>> groupedActivities = {};

    if (_activitiesData.containsKey('activities')) {
      final activities = _activitiesData['activities'];
      if (activities is Map<String, dynamic>) {
        activities.forEach((category, subcategoriesMap) {
          if (subcategoriesMap is Map<String, dynamic>) {
            subcategoriesMap.forEach((groupKey, subList) {
              if (subList is List) {
                //allSubcategories.addAll(List<String>.from(subList));
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

    //return allSubcategories.toSet().toList();
    return sortedGroupKeys.expand((key) => groupedActivities[key]!).toList();
  }

  /// Load all day activities from storage
  Future<void> _loadAllDayActivities() async {
    final data = await _plannerService.getAllDayActivities();
    print('📅 Loaded day activities: $data'); // Debug
    setState(() {
      _dayActivitiesMap = data;
    });

    // After we loaded planned activities, generate outfits for the upcoming forecast days
    await _generateOutfitsForWeek();
  }

  /// Get activities for selected day
  List<String> _getActivitiesForDay(DateTime day) {
    final dateKey = _dateToString(day);
    return _dayActivitiesMap[dateKey]?.where((activity) => !activity.startsWith('!R:')).toList() ?? [];
  }

  /// Collect IDs of outfit items that are currently in wash
  Future<Set<String>> _collectInWashItemIds(Outfit? outfit) async {
    if (outfit == null) return <String>{};

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

    return inWashIds;
  }

  /// Generate outfits for the next 6 forecast days (indexes 1..6)
  Future<void> _generateOutfitsForWeek() async {
    final now = DateTime.now();
    for (int idx = 1; idx <= 6; idx++) {
      final day = now.add(Duration(days: idx));
      await _generateOutfitForIndex(idx, day);
    }
  }

  Future<void> _generateOutfitForIndex(int forecastIndex, DateTime day) async {
    if (!mounted) return;

    final provider = context.read<MainProvider>();

    final key = _dateToString(day);

    // Check if outfit is already stored for this date
    final storedOutfit = await _outfitStorageService.getOutfitForDate(day);
    if (storedOutfit != null && storedOutfit.stationID != null && storedOutfit.stationID == provider.selectedLocation["id"]) {
      final inWashIds = await _collectInWashItemIds(storedOutfit);
      if (mounted) {
        setState(() {
          _plannedOutfits[key] = storedOutfit;
          _inWashItemIdsByDate[key] = inWashIds;
        });
      }
      print('Planner: Using stored outfit for $key');
      return;
    }

    if (!mounted) return;

    

    final forecast = provider.forecast;

    if (forecast == null ||
        forecast.days == null ||
        forecast.days!.length <= forecastIndex) {
      return;
    }

    final dayForecast = forecast.days![forecastIndex];

    // Temperature: use average of min and max when available
    final double temp =
        ((dayForecast.maxTemperature ??
                (provider.currentWeather?.temperature ?? 15.0)) +
            (dayForecast.minTemperature ??
                (provider.currentWeather?.temperature ?? 15.0))) /
        2.0;

    double rainProbability = 0.0;
    if (dayForecast.precipitation != null) {
      rainProbability = (dayForecast.precipitation! / 5.0).clamp(0.0, 1.0);
    } else if (dayForecast.icon != null &&
        dayForecast.icon! >= 200 &&
        dayForecast.icon! < 800) {
      // crude heuristic: meteorological icons <800 are weather events - assume some rain if not clear
      rainProbability = 0.6;
    }

    final double windSpeed =
        dayForecast.windSpeed ?? provider.currentWeather?.windSpeed ?? 0.0;

    final activities = List<String>.from(await _plannerService.getMergedDayActivities(day));

    // Add transportation as an activity so the engine can prefer appropriate items
    final transport = await _preferencesService.getTransportation();
    if (transport.trim().isNotEmpty) activities.add(transport.toLowerCase());

    final coldThreshold = await _preferencesService.getColdThreshold();
    final warmThreshold = await _preferencesService.getWarmThreshold();

    // Get wardrobe and convert to ClothingItem
    final allWardrobeItems = await _wardrobeService.getWardrobeItems();

    final wardrobeItems = allWardrobeItems
          .where((item) => !item.isInWash)
          .toList();

    final clothingItems = _convertToClothingItemsPlanner(wardrobeItems);

    // Debug: list potential outer candidates from wardrobe
    final outerCandidates = clothingItems
        .where(
          (c) =>
              c.category.toLowerCase().contains('outer') ||
              c.subtype.toLowerCase().contains('jacket') ||
              c.subtype.toLowerCase().contains('coat') ||
              c.category.toLowerCase().contains('jacket') ||
              c.category.toLowerCase().contains('coat'),
        )
        .toList();
    print(
      'Planner: found ${clothingItems.length} clothing items; outer candidates (${outerCandidates.length}): ${outerCandidates.map((c) => '${c.subtype}(${c.category}) warmth=${c.attributes.warmthLevel} water=${c.attributes.waterResistance}').join(', ')}',
    );

    final engine = OutfitEngine(clothingItems);

    // Generate multiple outfits and randomly select from top 5
    final outfits = engine.generateOutfits(
      temperature: temp,
      activities: activities,
      rainProbability: rainProbability,
      windSpeed: windSpeed,
      weatherCondition: null,
      coldThreshold: coldThreshold,
      warmThreshold: warmThreshold,
      topNPerCategory: 3,
      maxOutfits: 5,
    );

    if (outfits.isNotEmpty) {
      // Randomly select from top 5 outfits
      final random = Random();
      final outfit = outfits[random.nextInt(outfits.length)];

      // Save the outfit to storage
      await _outfitStorageService.saveOutfitForDate(day, outfit, forecast.stationId);

      // Collect any outfit pieces currently in wash
      final inWashIds = await _collectInWashItemIds(outfit);

      if (mounted) {
        setState(() {
          _plannedOutfits[key] = outfit;
          _inWashItemIdsByDate[key] = inWashIds;
        });
      }
      print('Planner: Generated and stored outfit for $key');
    }
  }

  List<ClothingItem> _convertToClothingItemsPlanner(
    List<dynamic> wardrobeItems,
  ) {
    return wardrobeItems.map((item) {
      final rawCategory = (item.category ?? '').toString().toLowerCase();
      final rawSubtype = (item.subcategory ?? '').toString().toLowerCase();
      final name = item.name ?? '';
      final imagePath = item.imagePath;

      final Map<String, dynamic> storedAttributes =
          (item.attributes as Map<String, dynamic>?)?.cast<String, dynamic>() ??
          {};
      final Map<String, dynamic> storedUsage =
          (item.usageConstraints as Map<String, dynamic>?)
              ?.cast<String, dynamic>() ??
          {};

      // Planner doesn't load the subtypes JSON; prefer stored WardrobeItem attributes
      // Default to no JSON attributes (use stored attributes only)
      Map<String, dynamic>? foundSubtypeData = null;

      final Map<String, dynamic> jsonAttributes =
          (foundSubtypeData != null && foundSubtypeData['attributes'] is Map)
          ? Map<String, dynamic>.from(foundSubtypeData['attributes'] as Map)
          : {};
      final Map<String, dynamic> jsonUsage =
          (foundSubtypeData != null &&
              foundSubtypeData['usage_constraints'] is Map)
          ? Map<String, dynamic>.from(
              foundSubtypeData['usage_constraints'] as Map,
            )
          : {};

      final attributesData = {...jsonAttributes, ...storedAttributes};
      final usageConstraintsData = {...jsonUsage, ...storedUsage};

      if (storedAttributes.isNotEmpty) {
        final overridden = storedAttributes.keys.join(', ');
        print(
          'Converting item ${item.id}: merging stored attributes over JSON defaults (overrides: $overridden)',
        );
      }
      if (storedUsage.isNotEmpty) {
        final overridden = storedUsage.keys.join(', ');
        print(
          'Converting item ${item.id}: merging stored usage constraints over JSON defaults (overrides: $overridden)',
        );
      }

      final materials = List<String>.from(attributesData['materials'] ?? []);
      final warmthLevel = attributesData['warmth_level'] ?? 5;
      final waterResistance = attributesData['water_resistance'] ?? 5;
      final windResistance = attributesData['wind_resistance'] ?? 5;
      final breathability = attributesData['breathability'] ?? 5;
      final stretch = attributesData['stretch'] ?? 5;
      final formality =
          attributesData['formality'] ?? (item.formalityLevel ?? 'casual');
      final styleTags = List<String>.from(
        attributesData['style_tags'] ?? (item.tags ?? []),
      );
      final fit = attributesData['fit'] ?? 'regular';

      final weatherMinTemp = usageConstraintsData['weather_min_temp'] ?? -40;
      final weatherMaxTemp = usageConstraintsData['weather_max_temp'] ?? 45;
      final optimalActivities = List<String>.from(
        usageConstraintsData['optimal_activities'] ?? ['daily', 'casual'],
      );
      final unsuitableFor = List<String>.from(
        usageConstraintsData['unsuitable_for'] ?? [],
      );
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

  Widget _buildPlannedOutfitPreview(
    DateTime day,
    ThemeData theme,
    VoidCallback? onTap,
  ) {
    final key = _dateToString(day);
    final outfit = _plannedOutfits[key];
    if (outfit == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Text(
          'No outfit generated for this day',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    bool _isItemInWashForDay(String dateKey, ClothingItem item) {
      return _inWashItemIdsByDate[dateKey]?.contains(item.id) ?? false;
    }

    Widget buildItemPreview(ClothingItem? item, IconData fallbackIcon) {
      if (item == null)
        return Column(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.surface,
              child: Icon(fallbackIcon),
            ),
            const SizedBox(height: 4),
            Text('-', style: theme.textTheme.bodySmall),
          ],
        );
      final imagePath = item.metadata?['imagePath'] as String?;
      final label = (item.metadata?['name'] as String?) ?? item.subtype;
      final inWash = _isItemInWashForDay(key, item);
      return Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: outfit.palette.dominant.withOpacity(0.15),
                child: imagePath != null
                    ? ClipOval(
                        child: Image.file(
                          File(imagePath),
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.checkroom,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
              ),
              if (inWash)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
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
                      size: 14,
                      color: theme.colorScheme.onError,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 80,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 0, bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        //onTap: () => _showOutfitDetails(outfit),
        onTap: onTap ?? () => _showOutfitDetails(outfit),

        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: buildItemPreview(outfit.outerwear, Icons.shield),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: buildItemPreview(outfit.pullover, Icons.layers),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: buildItemPreview(outfit.shirt, Icons.checkroom),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: buildItemPreview(outfit.bottom, Icons.checkroom),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: buildItemPreview(
                      outfit.shoes,
                      Icons.directions_walk,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOutfitDetails(Outfit outfit) {
    final items = [
      if (outfit.outerwear != null) outfit.outerwear!,
      if (outfit.pullover != null) outfit.pullover!,
      if (outfit.shirt != null) outfit.shirt!,
      if (outfit.bottom != null) outfit.bottom!,
      if (outfit.shoes != null) outfit.shoes!,
      ...(outfit.accessories ?? []),
    ];

    // Reuse the wardrobe details sheet UI for planner outfits
    showOutfitDetailsSheet(
      context,
      title: 'Planned Outfit',
      date: null,
      items: items,
      score: outfit.score,
    );
  }

  /// Format activity key to readable string
  String _formatActivityKey(String key) {
    return key
        .replaceFirst("R:","")
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Convert DateTime to string key (YYYY-MM-DD)
  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final GlobalKey<NavigatorState> plannerNavigatorKey =
        GlobalKey<NavigatorState>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (route, result) {
        if (plannerNavigatorKey.currentState != null &&
            plannerNavigatorKey.currentState!.canPop()) {
          plannerNavigatorKey.currentState!.pop(result);
        }
      },
      child: Navigator(
        key: plannerNavigatorKey,
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
                  'Planner',
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
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.wb_sunny_outlined),
                      text: 'Week forecast',
                    ),
                    Tab(
                      icon: Icon(Icons.show_chart_rounded),
                      text: 'Activities',
                    ),
                  ],
                ),
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildForecastTab(theme, context, plannerNavigatorKey),
                _buildActivitiesTab(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForecastTab(
    ThemeData theme,
    BuildContext context,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    DateTime now = DateTime.now();

    MainProvider provider = context.watch<MainProvider>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,

          children: List.generate(6, (i) {
            final idx = i + 1; // Skip today (index 0)
            DateTime day = now.add(Duration(days: idx));
            String dayName = DateFormat('EEEE').format(day);
            String date = DateFormat('MMM d').format(day);

            void onTap() async {
              await navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    live: false,
                    title: dayName,
                    forecastIndex: idx,
                  ),
                ),
              );
              // Reload outfit after returning from HomeScreen
              await _generateOutfitForIndex(idx, day);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$dayName, $date',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16),

                WeatherCard(
                  isLoading: false,
                  forecast: provider.forecast,
                  flatBottomCorners:
                      _plannedOutfits.containsKey(_dateToString(day))
                      ? true
                      : false,
                  forecastIndex: idx,
                  onTap: onTap,
                ),
                //const SizedBox(height: 12),
                _buildPlannedOutfitPreview(day, theme, onTap),
                const SizedBox(height: 16),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildActivitiesTab(ThemeData theme) {
    final activitiesForSelectedDay = _getActivitiesForDay(_selectedDay);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                  formatButtonDecoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  formatButtonTextStyle: TextStyle(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                eventLoader: (day) {
                  return _getActivitiesForDay(day);
                  //return [];
                },
              ),
            ),
            const SizedBox(height: 24),

            // Selected date info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMM d, y').format(_selectedDay),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
                FilledButton.icon(
                  onPressed: () => _showAddActivityDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            FutureBuilder<List<String>>(
              future: _plannerService.getMergedDayActivities(_selectedDay),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading activities: ${snapshot.error}'),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No activities planned for this day',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Add" to plan an activity',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  final activitiesForSelectedDay = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activitiesForSelectedDay.length,
                    itemBuilder: (context, index) {
                      String activity = activitiesForSelectedDay[index];
                      final isWeekly = activity.startsWith('R:');
                      if (isWeekly) {
                        activity = activity.substring(2); // Remove 'R:' prefix
                      }
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              isWeekly
                                  ? Icons.replay_outlined
                                  : Icons.show_chart_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(_formatActivityKey(activity)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                _deleteActivity(activity, isWeekly),
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteActivity(String activity, bool isWeekly) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${activity.replaceAll("_", " ")}?'),
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
                _removeActivityFromDay('R:$activity', false)
              },
              child: const Text('Remove from all days'),
            ),
          FilledButton(
            onPressed: () => {
              Navigator.pop(context, true),
              _removeActivityFromDay(
                isWeekly ? 'R:$activity' : activity,
                true,
              )
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
  }

  void _showAddActivityDialog(BuildContext context) {
    String? selectedActivityCategory;
    String? selectedActivitySubcategory;
    List<String> selectedActivities = [];
    String searchQuery = '';
    String recurrenceOption = 'once'; // Default to "Only this day"

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
              title: Text(
                'Add Activity to ${DateFormat('MMM d').format(_selectedDay)}',
              ),
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
                                'every ${DateFormat('EEEE').format(_selectedDay)}',
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
                  onPressed: selectedActivities.isEmpty
                      ? null
                      : () async {
                          for (final activity in selectedActivities) {
                            await _plannerService.addActivityToDay(
                              _selectedDay,
                              activity,
                              recurrenceOption,
                            );
                          }
                          // Reload once after all are added
                          await _loadAllDayActivities();
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
                        },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Add activity to selected day
  /*Future<void> _addActivityToDay(String activity) async {
    print('💾 Saving activity: $activity for date: $_selectedDay'); // Debug
    final success = await _plannerService.addActivityToDay(
      _selectedDay,
      activity,
    );
    print('💾 Save success: $success'); // Debug
    if (success) {
      await _loadAllDayActivities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_formatActivityKey(activity)} added')),
        );
      }
    }
  }*/

  /// Remove activity from selected day
  Future<void> _removeActivityFromDay(String activity, bool once) async {
    final success = await _plannerService.removeActivityFromDay(
      _selectedDay,
      activity,
      once
    );
    if (success) {
      await _loadAllDayActivities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_formatActivityKey(activity)} removed')),
        );
      }
    }
  }
}
