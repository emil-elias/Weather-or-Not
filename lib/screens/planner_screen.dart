import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:weatherornot/providers/main_provider.dart';
import 'package:weatherornot/services/planner_service.dart';
import 'package:weatherornot/widgets/weather_card.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PlannerService _plannerService = PlannerService();

  // Activities data
  Map<String, dynamic> _activitiesData = {};

  // Calendar
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

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

    return allSubcategories.toSet().toList();
  }

  /// Load all day activities from storage
  Future<void> _loadAllDayActivities() async {
    final data = await _plannerService.getAllDayActivities();
    print('📅 Loaded day activities: $data'); // Debug
    setState(() {
      _dayActivitiesMap = data;
    });
  }

  /// Get activities for selected day
  List<String> _getActivitiesForDay(DateTime day) {
    final dateKey = _dateToString(day);
    return _dayActivitiesMap[dateKey] ?? [];
  }

  /// Format activity key to readable string
  String _formatActivityKey(String key) {
    return key
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Planner',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.onSurface,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(icon: Icon(Icons.wb_sunny_outlined), text: 'Week forecast'),
              Tab(
                icon: Icon(Icons.show_chart_rounded),
                text: 'Week activities',
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildForecastTab(theme, context),
          _buildActivitiesTab(theme),
        ],
      ),
    );
  }

  Widget _buildForecastTab(ThemeData theme, BuildContext context) {
    DateTime now = DateTime.now();

    MainProvider provider = context.watch<MainProvider>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,

          children: List.generate(7, (i) {
            DateTime day = now.add(Duration(days: i));
            String dayName = DateFormat('EEEE').format(day);
            String date = DateFormat('MMM d').format(day);

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
                  forecastIndex: i,
                ),
                SizedBox(height: 16),
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
                },
              ),
            ),
            const SizedBox(height: 24),

            // Selected date info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, y').format(_selectedDay),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showAddActivityDialog(context, theme),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Activities for selected day
            if (activitiesForSelectedDay.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.3,
                  ),
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
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activitiesForSelectedDay.length,
                itemBuilder: (context, index) {
                  final activity = activitiesForSelectedDay[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.show_chart_rounded,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(_formatActivityKey(activity)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeActivityFromDay(activity),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to add activity to selected day
  void _showAddActivityDialog(BuildContext context, ThemeData theme) {
    final allActivities = _getAllActivitySubcategories();
    final currentActivities = _getActivitiesForDay(_selectedDay);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Add Activity to ${DateFormat('MMM d').format(_selectedDay)}',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: allActivities.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: allActivities.length,
                    itemBuilder: (context, index) {
                      final activity = allActivities[index];
                      final isAlreadyAdded = currentActivities.contains(
                        activity,
                      );

                      return ListTile(
                        leading: Icon(
                          isAlreadyAdded
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isAlreadyAdded
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(_formatActivityKey(activity)),
                        enabled: !isAlreadyAdded,
                        onTap: isAlreadyAdded
                            ? null
                            : () {
                                _addActivityToDay(activity);
                                Navigator.pop(context);
                              },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Add activity to selected day
  Future<void> _addActivityToDay(String activity) async {
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
  }

  /// Remove activity from selected day
  Future<void> _removeActivityFromDay(String activity) async {
    final success = await _plannerService.removeActivityFromDay(
      _selectedDay,
      activity,
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
