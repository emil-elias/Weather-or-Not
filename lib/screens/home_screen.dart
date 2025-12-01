import 'package:flutter/material.dart';
import 'package:weatherornot/models/forecast.dart';
import '../services/weather_service.dart';
import '../models/weather.dart';
import '../models/activity.dart';
import '../constants/app_constants.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();
  String _selectedLocation = 'Bremen, Germany';
  Weather? _currentWeather;
  Forecast? _forecast;
  bool _isLoading = false;
  String? _errorMessage;
  String closestLocation = 'Fetching...';
  List<Map<String, dynamic>>? _closestLocations;
  //String stationID = '';

  // Available locations
  final List<String> _locations = [
    'Bremen, Germany',
    'Hamburg, Germany',
    'Berlin, Germany',
    'München, Germany',
    /*'Köln, Germany',*/
    'Lisboa, Portugal',
  ];

  // Location coordinates
  final Map<String, Map<String, double>> _locationCoordinates = {
    'Bremen, Germany': {'lat': 53.0793, 'lon': 8.8017},
    'Hamburg, Germany': {'lat': 53.5511, 'lon': 9.9937},
    'Berlin, Germany': {'lat': 52.5200, 'lon': 13.4050},
    'München, Germany': {'lat': 48.1351, 'lon': 11.5820},
    'Köln, Germany': {'lat': 50.9375, 'lon': 6.9603},
    'Lisboa, Portugal': {'lat': 38.47, 'lon': -9.08},
  };

  final Map<String, String> stationIDs = Map<String, String>.from(AppConstants.stationIDs);

  List<Activity> _todayActivities = [];

  @override
  void initState() {
    super.initState();
    _getClosestLocation();
    //_loadWeather();
  }

  Future<void> _getClosestLocation() async {
    try {
      final geo.Position userPosition = await _locationService.getCurrentLocation();
      final List<Map<String, dynamic>> closestList = await _locationService.findClosestLocation(userPosition);
      //print(closestList);
      final closest = closestList.first;

      setState(() {
        closestLocation = 'Closest Location: ${closest['name']} with id ${closest['id']}';
        _selectedLocation = closest['name'];
        _locations.insert(0, closest['name']);
        //stationID = closest['id'];
        stationIDs[closest['name']] = closest['id'];
        _closestLocations = closestList;
        _loadWeather();
      });
    } catch (e) {
      setState(() {
        closestLocation = 'Error: $e';
        _loadWeather();
      });
    }

    print(closestLocation);
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

      /*if (stationID.isEmpty) {
        stationID = AppConstants.stationIDs[_selectedLocation] ?? '';
      }*/

      //final stationID = stationIDs[_selectedLocation];

      /*final weather = await _weatherService.getWeatherByCoordinates(
        coords['lat']!,
        coords['lon']!,
        locationName: _selectedLocation,
      );*/

      final weather = await _weatherService.getCurrentDWDWeatherByStationID(
        stationIDs[_selectedLocation]!,
        locationName: _selectedLocation,
        fallbackStations: _closestLocations != null
            ? _closestLocations!
                .where((loc) => loc['name'] != _selectedLocation)
                .toList()
            : null,
        fallbackLat: coords['lat'],
        fallbackLon: coords['lon'],
      );

      if (weather != null && weather.stationName != _selectedLocation) {
        setState(() {
          _locations.remove(_selectedLocation);
          _selectedLocation = weather.stationName;
          _locations.insert(0, weather.stationName);
          stationIDs[weather.stationName] = weather.stationId;
        });
      }

      final forecast = await _weatherService.getForecastDWDWeatherByStationID(
        stationIDs[_selectedLocation]!,
      );

      print(forecast.days);

      setState(() {
        _currentWeather = weather;
        _forecast = forecast;
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

                  // Location Dropdown
                  GestureDetector(
                    onTap: () => _showLocationPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.3),
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
                ],
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Weather Icon
                          Icon(
                            _currentWeather!.icon != null ? _getWeatherIconById(_currentWeather!.icon) : _getWeatherIcon(_currentWeather!.condition),
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 16),
                          // Temperature
                          Text(
                            '${_currentWeather!.temperature?.toStringAsFixed(0) ?? '--'}°',
                            style: const TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // High/Low
                          const Icon(
                            Icons.arrow_upward_rounded,
                            size: 16,
                            color: Color(0xFF4AFF8C),
                          ),
                          Text(
                            ' ${((_forecast?.days?.isNotEmpty == true ? (_forecast!.days![0].maxTemperature ?? _currentWeather!.temperature ?? 0) : (_currentWeather!.temperature ?? 0))).toStringAsFixed(0)}°',
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
                            ' ${((_forecast?.days?.isNotEmpty == true ? (_forecast!.days![0].minTemperature ?? _currentWeather!.temperature ?? 0) : (_currentWeather!.temperature ?? 0))).toStringAsFixed(0)}°',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w500,
                            ),
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
                              _currentWeather!.icon != null
                                  ? _getWeatherDescriptionById(_currentWeather!.icon)
                                  : _getWeatherDescription(_currentWeather!.condition),
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
                      const SizedBox(height: 16),
                      //Source
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Quelle: ${_currentWeather!.source}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
              _buildOutfitCard(context, isLarge: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildOutfitCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildOutfitCard(context)),
                ],
              ),
              const SizedBox(height: 24),
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

  IconData _getWeatherIconById(int? iconId) {
  if (iconId == null) return Icons.wb_cloudy_outlined;

  switch (iconId) {
    case 1: // sunny
      return Icons.wb_sunny_outlined;
    case 2: // sunny, partly/slightly cloudy, need to find a better icon
      return Icons.wb_sunny_outlined;
    case 3: // sunny, cloudy, need to find a better icon
      return Icons.cloud_outlined;
    case 4: // clouds
      return Icons.cloud_outlined;
    case 5: // fog
      return Icons.blur_on;
    case 6: // fog, slippery
      return Icons.blur_on;
    case 7: // light rain
      return Icons.water_drop_outlined;
    case 8: // rain
      return Icons.umbrella_outlined;
    case 9: // heavy rain
      return Icons.water_outlined;
    case 10: // slight rain, slippery
      return Icons.water_drop_outlined;
    case 11: // heavy rain, slippery
      return Icons.water_outlined;
    case 12: // rain, occasional snowfall
      return Icons.umbrella_outlined;
    case 13: // rain, increased snowfall
      return Icons.ac_unit_rounded;
    case 14: // light snowfall
      return Icons.ac_unit_rounded;
    case 15: // snowfall
      return Icons.snowing;
    case 16: // heavy snowfall
      return Icons.snowing;
    case 17: // clouds, (hail)
      return Icons.cloud;
    case 18: // sunny, light rain
      return Icons.wb_sunny_outlined;
    case 19: // sunny, heavy rain
      return Icons.wb_sunny_outlined;
    case 20: // sun, rain, occasional snowfall
      return Icons.wb_sunny_outlined;
    case 21: // sun, rain, increased snowfall
      return Icons.sunny_snowing;
    case 22: // sunny, occasional snowfall
      return Icons.wb_sunny_outlined;
    case 23: // sunny, increased snowfall
      return Icons.sunny_snowing;
    case 24: // sunny, (hail)
      return Icons.sunny_snowing;
    case 25: // sunny, (heavy hail)
      return Icons.sunny_snowing;
    case 26: // thunderstorm
      return Icons.flash_on;
    case 27: // thunderstorm, rain
      return Icons.thunderstorm_outlined;
    case 28: // thunderstorm, heavy rain
      return Icons.thunderstorm_outlined;
    case 29: // thunderstorm, (hail)
      return Icons.thunderstorm_outlined;
    case 30: // thunderstorm, (heavy hail)
      return Icons.thunderstorm_outlined;
    case 31: // (wind)
      return Icons.air;
    default:
      return Icons.wb_cloudy_outlined;
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

  String _getWeatherDescriptionById(int? iconId) {
    String condition;
    switch (iconId) {
      case 1:
        condition = 'sunny';
        break;
      case 2:
        condition = 'partly cloudy';
        break;
      case 3:
        condition = 'cloudy';
        break;
      case 4:
        condition = 'overcast';
        break;
      case 5:
        condition = 'fog';
        break;
      case 6:
        condition = 'foggy';
        break;
      case 7:
        condition = 'light rain';
        break;
      case 8:
        condition = 'rain';
        break;
      case 9:
        condition = 'heavy rain';
        break;
      case 10:
        condition = 'light rain, slippery';
        break;
      case 11:
        condition = 'heavy rain, slippery';
        break;
      case 12:
        condition = 'rain, occasional snowfall';
        break;
      case 13:
        condition = 'rain, increased snowfall';
        break;
      case 14:
        condition = 'light snowfall';
        break;
      case 15:
        condition = 'snowfall';
        break;
      case 16:
        condition = 'heavy snowfall';
        break;
      case 17:
        condition = 'clouds, hail';
        break;
      case 18:
        condition = 'sunny, light rain';
        break;
      case 19:
        condition = 'sunny, heavy rain';
        break;
      case 20:
        condition = 'sun, rain, occasional snowfall';
        break;
      case 21:
        condition = 'sun, rain, increased snowfall';
        break;
      case 22:
        condition = 'sunny, occasional snowfall';
        break;
      case 23:
        condition = 'sunny, increased snowfall';
        break;
      case 24:
        condition = 'sunny, hail';
        break;
      case 25:
        condition = 'sunny, heavy hail';
        break;
      case 26:
        condition = 'thunderstorm';
        break;
      case 27:
        condition = 'thunderstorm, rain';
        break;
      case 28:
        condition = 'thunderstorm, heavy rain';
        break;
      case 29:
        condition = 'thunderstorm, hail';
        break;
      case 30:
        condition = 'thunderstorm, heavy hail';
        break;
      case 31:
        condition = 'windy';
        break;
      default:
        condition = 'unknown';
        break;
    }

    return condition;
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
                                id: DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                name:
                                    '${selectedStyle!.displayName} - ${selectedType!.displayName}',
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
