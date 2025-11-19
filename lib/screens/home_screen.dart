import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../models/weather.dart';
import '../models/activity.dart';
import '../constants/app_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  String _selectedLocation = 'Bremen, Germany';
  Weather? _currentWeather;
  bool _isLoading = false;
  String? _errorMessage;

  // Available locations
  final List<String> _locations = [
    'Bremen, Germany',
    'Hamburg, Germany',
    'Berlin, Germany',
    'München, Germany',
    'Köln, Germany',
  ];

  // Location coordinates
  final Map<String, Map<String, double>> _locationCoordinates = {
    'Bremen, Germany': {'lat': 53.0793, 'lon': 8.8017},
    'Hamburg, Germany': {'lat': 53.5511, 'lon': 9.9937},
    'Berlin, Germany': {'lat': 52.5200, 'lon': 13.4050},
    'München, Germany': {'lat': 48.1351, 'lon': 11.5820},
    'Köln, Germany': {'lat': 50.9375, 'lon': 6.9603},
  };

  List<Activity> _todayActivities = [];

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final coords = _locationCoordinates[_selectedLocation] ?? 
                     {'lat': AppConstants.bremenLatitude, 'lon': AppConstants.bremenLongitude};
      
      final weather = await _weatherService.getWeatherByCoordinates(
        coords['lat']!,
        coords['lon']!,
        locationName: _selectedLocation,
      );
      
      setState(() {
        _currentWeather = weather;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Wetter konnte nicht geladen werden';
        _isLoading = false;
      });
    }
  }

  void _onLocationChanged(String? newLocation) {
    if (newLocation != null && newLocation != _selectedLocation) {
      setState(() {
        _selectedLocation = newLocation;
      });
      _loadWeather();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Today',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Location Dropdown
              GestureDetector(
                onTap: () => _showLocationPicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedLocation,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Weather Card
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_errorMessage != null)
                Center(
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                )
              else if (_currentWeather != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF6B9FFF),
                        const Color(0xFF5855D6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5855D6).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Weather Icon and Temperature
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Weather Icon
                          Icon(
                            _getWeatherIcon(_currentWeather!.condition),
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 16),
                          // Temperature
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_currentWeather!.temperature?.toStringAsFixed(0) ?? '--'}°',
                                style: const TextStyle(
                                  fontSize: 72,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                              // High/Low
                              Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: Color(0xFF4AFF8C),
                                  ),
                                  Text(
                                    ' ${(_currentWeather!.temperature ?? 0 + 2).toStringAsFixed(0)}°',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF4AFF8C),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 16,
                                    color: Color(0xFFFF6B6B),
                                  ),
                                  Text(
                                    ' ${(_currentWeather!.temperature ?? 0 - 3).toStringAsFixed(0)}°',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFFFF6B6B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Arrow
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white70,
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Weather description
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getWeatherDescription(_currentWeather!.condition),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildWeatherDetail(
                                  Icons.water_drop_outlined,
                                  '${_currentWeather!.humidity ?? '--'}%',
                                  'Luftfeuchtigkeit',
                                ),
                                _buildWeatherDetail(
                                  Icons.air_outlined,
                                  '${_currentWeather!.windSpeed?.toStringAsFixed(1) ?? '--'} km/h',
                                  'Wind',
                                ),
                                _buildWeatherDetail(
                                  Icons.cloud_outlined,
                                  '${_currentWeather!.cloudCover ?? '--'}%',
                                  'Bewölkung',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Add activities button
              GestureDetector(
                onTap: () => _showAddActivityDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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

              // Outfit cards
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildOutfitCard(context, isLarge: true),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildOutfitCard(context),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildOutfitCard(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutfitCard(BuildContext context, {bool isLarge = false}) {
    final theme = Theme.of(context);
    return Container(
      height: isLarge ? 120 : 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checkroom_outlined,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }

  IconData _getWeatherIcon(String? condition) {
    if (condition == null) return Icons.wb_cloudy_outlined;
    
    final lowerCondition = condition.toLowerCase();
    if (lowerCondition.contains('sun') || lowerCondition.contains('clear')) {
      return Icons.wb_sunny_outlined;
    } else if (lowerCondition.contains('rain')) {
      return Icons.umbrella_outlined;
    } else if (lowerCondition.contains('cloud')) {
      return Icons.cloud_outlined;
    } else if (lowerCondition.contains('snow')) {
      return Icons.ac_unit_rounded;
    }
    return Icons.wb_cloudy_outlined;
  }

  String _getWeatherDescription(String? condition) {
    return WeatherConditions.getGermanDescription(
      condition,
      temperature: _currentWeather?.temperature,
      windSpeed: _currentWeather?.windSpeed,
      cloudCover: _currentWeather?.cloudCover,
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
                      'Location wählen',
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
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
    ActivityStyle? selectedStyle;
    ActivityType? selectedType;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Aktivität hinzufügen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stil',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ActivityStyle.values.map((style) {
                        final isSelected = selectedStyle == style;
                        return FilterChip(
                          label: Text(style.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              selectedStyle = selected ? style : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aktivität',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ActivityType.values.map((type) {
                        final isSelected = selectedType == type;
                        return FilterChip(
                          label: Text(type.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              selectedType = selected ? type : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: selectedStyle != null && selectedType != null
                      ? () {
                          setState(() {
                            _todayActivities.add(
                              Activity(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                name: '${selectedStyle!.displayName} - ${selectedType!.displayName}',
                                style: selectedStyle!,
                                type: selectedType!,
                              ),
                            );
                          });
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

  Widget _buildWeatherDetail(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 20,
        ),
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
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
