import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:weatherornot/providers/main_provider.dart';
import 'package:weatherornot/widgets/weather_card.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                SizedBox(height: 16,),
                WeatherCard(
                  isLoading: false,
                  forecast: provider.forecast,
                  forecastIndex: i,
                ),
                SizedBox(height: 16,),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildActivitiesTab(ThemeData theme) {
    return Center(child: Text("Activities"));
  }
}
