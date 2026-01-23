import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:weatherornot/models/day_forecast.dart';
import 'package:weatherornot/models/weather_warning.dart';
import 'package:weatherornot/providers/main_provider.dart';
import 'package:weatherornot/services/weather_service.dart';
import 'package:intl/intl.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  MainProvider _provider = MainProvider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    _provider = context.watch<MainProvider>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Weather'),
            /*LocationDropdown(selectedLocation: _provider.selectedLocation, locations: _provider.locations, onLocationChanged: _onLocationChanged)*/
          ],
        ),
        centerTitle: false,
        titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _weatherService.getGradientColors(
              _provider.currentWeather,
              _provider.forecast,
              null,
            ),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildCurrentWeather(),
                const SizedBox(height: 24),
                if (_provider.forecast?.warnings != null &&
                    _provider.forecast!.warnings!.isNotEmpty)
                  _buildWarnings(),
                if (_provider.forecast?.warnings != null &&
                    _provider.forecast!.warnings!.isNotEmpty)
                  const SizedBox(height: 24),
                _buildHourlyForecast(),
                const SizedBox(height: 24),
                _buildDailyForecast(),
                const SizedBox(height: 24),
                _buildWeatherDetails(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _provider.selectedLocation["name"],
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_provider.forecast?.source != null)
            Text(
              'Source: ${_provider.forecast?.source}',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeather() {
    String currentTemp = "--°";
    int currentIcon = 0;
    String maxTemp = "--°";
    String minTemp = "--°";

    final now = DateTime.now();
    final hourIndex = _provider.forecast?.start != null
        ? now.difference(_provider.forecast!.start!).inHours
        : 0;

    if (_provider.currentWeather != null &&
        _provider.currentWeather!.temperature != null &&
        _provider.currentWeather!.temperature! <= 100) {
      currentTemp =
          '${_provider.currentWeather!.temperature!.toStringAsFixed(0)}°';
    } else if (_provider.forecast != null) {
      if (_provider.forecast?.temperature != null &&
          hourIndex >= 0 &&
          hourIndex < _provider.forecast!.temperature!.length) {
        currentTemp = '${_provider.forecast!.temperature![hourIndex]}°';
      }
    }

    if (_provider.currentWeather != null &&
        _provider.currentWeather!.icon != null &&
        _provider.currentWeather!.icon! <= 32) {
      currentIcon = _provider.currentWeather!.icon!;
    } else if (_provider.forecast != null) {
      if (_provider.forecast?.icon != null &&
          hourIndex >= 0 &&
          hourIndex < _provider.forecast!.icon!.length) {
        currentIcon = _provider.forecast!.icon![hourIndex];
      }
    }

    if (_provider.forecast?.days != null &&
        _provider.forecast!.days!.isNotEmpty) {
      final todayForecast = _provider.forecast!.days!.first;
      if (todayForecast.maxTemperature != null) {
        maxTemp = '${todayForecast.maxTemperature!.toStringAsFixed(0)}°';
      }
      if (todayForecast.minTemperature != null) {
        minTemp = '${todayForecast.minTemperature!.toStringAsFixed(0)}°';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),

      child: Card(
        color: Colors.white.withOpacity(0.2),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        currentTemp,
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                //color: Color(0xFF4AFF8C),
                                color: Colors.white,
                              ),
                              Text(
                                ' ${maxTemp}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  //color: Color(0xFF4AFF8C),
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                                //color: Color(0xFFFF6B6B),
                                color: Colors.white,
                              ),
                              Text(
                                ' ${minTemp}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  //color: Color(0xFFFF6B6B),
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    _weatherService.getWeatherDescriptionById(currentIcon),
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),

              Icon(
                _weatherService.getWeatherIconById(currentIcon),
                size: 80,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyForecast() {
    if (_provider.forecast?.temperature == null ||
        _provider.forecast!.temperature!.isEmpty) {
      return SizedBox.shrink();
    }

    final now = DateTime.now();
    final hourIndex = _provider.forecast?.start != null
        ? now.difference(_provider.forecast!.start!).inHours
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Hourly Forecast',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: (_provider.forecast?.temperature?.length ?? 0).clamp(
              0,
              hourIndex + 24,
            ),
            itemBuilder: (context, index) {
              final actualIndex = index + hourIndex;
              final temp = _provider.forecast?.temperature![actualIndex] ?? 0;
              final icon = _provider.forecast?.icon?[actualIndex] ?? 0;
              final time = _provider.forecast?.start?.add(
                Duration(minutes: 60 * actualIndex),
              );

              return _buildHourlyItem(time, temp, icon);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyItem(DateTime? time, double temp, int icon) {
    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        color: Colors.white.withOpacity(0.2),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                time != null ? DateFormat('HH:mm').format(time) : '--',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(
                _weatherService.getWeatherIconById(icon),
                size: 28,
                color: Colors.white,
              ),
              Text(
                '${temp.toStringAsFixed(0)}°',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyForecast() {
    if (_provider.forecast?.days == null || _provider.forecast!.days!.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Daily Forecast',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: _provider.forecast!.days!.take(7).map((day) {
              return _buildDailyItem(day);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyItem(DayForecast day) {
    return Card(
      color: Colors.white.withOpacity(0.2),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('EEE, MMM d').format(day.date),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              _weatherService.getWeatherIconById(day.icon ?? 0),
              size: 28,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${day.maxTemperature?.toStringAsFixed(0) ?? '--'}°',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(' / ', style: TextStyle(color: Colors.white70)),
                  Text(
                    '${day.minTemperature?.toStringAsFixed(0) ?? '--'}°',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetails() {
    final now = DateTime.now();
    final hourIndex = _provider.forecast?.start != null
        ? now.difference(_provider.forecast!.start!).inHours
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weather Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                [
                  if (_provider.currentWeather?.windSpeed != null &&
                      _provider.currentWeather!.windSpeed! < 1000)
                    _buildDetailCard(
                      'Wind Speed',
                      '${_provider.currentWeather!.windSpeed!.toStringAsFixed(1)} km/h',
                      Icons.air,
                    )
                  else if (_provider.forecast?.windSpeed != null &&
                      _provider.forecast!.windSpeed!.isNotEmpty &&
                      _provider.forecast!.windSpeed![hourIndex] < 1000)
                    _buildDetailCard(
                      'Wind Speed',
                      '${_provider.forecast!.windSpeed![hourIndex].toStringAsFixed(1)} km/h',
                      Icons.air,
                    ),
                  if (_provider.forecast?.days != null && _provider.forecast!.days!.isNotEmpty && _provider.forecast!.days!.first.windSpeed != null)
                    _buildDetailCard(
                      'max. Wind Speed',
                      '${_provider.forecast!.days!.first.windSpeed!.toStringAsFixed(1)} km/h',
                      Icons.air,
                    ),
                  if (_provider.currentWeather?.humidity != null &&
                      _provider.currentWeather!.humidity! < 3000)
                    _buildDetailCard(
                      'Humidity',
                      '${_provider.currentWeather!.humidity!.toStringAsFixed(0)}%',
                      Icons.water_drop,
                    )
                  else if (_provider.forecast?.humidity != null &&
                      _provider.forecast!.humidity!.isNotEmpty &&
                      _provider.forecast!.humidity![hourIndex] < 3000)
                    _buildDetailCard(
                      'Humidity',
                      '${_provider.forecast!.humidity![hourIndex].toStringAsFixed(0)}%',
                      Icons.water_drop,
                    ),
                  if (_provider.currentWeather?.pressure != null &&
                      _provider.currentWeather!.pressure! < 3000)
                    _buildDetailCard(
                      'Pressure',
                      '${_provider.currentWeather!.pressure!.toStringAsFixed(0)} mbar',
                      Icons.compress,
                    )
                  else if (_provider.forecast?.pressure != null &&
                      _provider.forecast!.pressure!.isNotEmpty &&
                      _provider.forecast!.pressure![hourIndex] < 3000)
                    _buildDetailCard(
                      'Pressure',
                      '${_provider.forecast!.pressure![hourIndex].toStringAsFixed(0)} mbar',
                      Icons.compress,
                    ),
                  if (_provider.forecast?.days != null && _provider.forecast!.days!.isNotEmpty && _provider.forecast!.days!.first.precipitation != null &&
                      _provider.forecast!.days!.first.precipitation! < 3000)
                    _buildDetailCard(
                      'Precipitation',
                      '${_provider.forecast!.days!.first.precipitation!.toStringAsFixed(1)} mm',
                      Icons.opacity,
                    )
                  else if (_provider.currentWeather?.precipitation != null &&
                      _provider.currentWeather!.precipitation! < 3000)
                    _buildDetailCard(
                      'Precipitation',
                      '${_provider.currentWeather!.precipitation!.toStringAsFixed(1)} mm',
                      Icons.opacity,
                    ),
                  if (_provider.currentWeather?.cloudCover != null &&
                      _provider.currentWeather!.cloudCover! < 3000)
                    _buildDetailCard(
                      'Cloud Cover',
                      '${_provider.currentWeather!.cloudCover!.clamp(0, 100).toStringAsFixed(0)}%',
                      Icons.cloud,
                    )
                  else if (_provider.forecast?.cloudCover != null &&
                      _provider.forecast!.cloudCover!.isNotEmpty &&
                      _provider.forecast!.cloudCover![hourIndex] < 3000)
                    _buildDetailCard(
                      'Cloud Cover',
                      '${_provider.forecast!.cloudCover![hourIndex].clamp(0, 100).toStringAsFixed(0)}%',
                      Icons.cloud,
                    ),
                  if (_provider.forecast?.days != null && _provider.forecast!.days!.isNotEmpty && _provider.forecast!.days!.first.sunshine != null &&
                      _provider.forecast!.days!.first.sunshine! < 3000)
                    _buildDetailCard(
                      'Sunshine',
                      '${(_provider.forecast!.days!.first.sunshine! / 60).clamp(0, 24).toStringAsFixed(0)} h',
                      Icons.wb_sunny_outlined,
                    ),
                  if (_provider.currentWeather?.dewpoint != null &&
                      _provider.currentWeather!.dewpoint! < 3000)
                    _buildDetailCard(
                      'Dew Point',
                      '${_provider.currentWeather!.dewpoint!.toStringAsFixed(1)}°',
                      Icons.thermostat,
                    )
                  else if (_provider.forecast?.dewPoint != null &&
                      _provider.forecast!.dewPoint!.isNotEmpty &&
                      _provider.forecast!.dewPoint![hourIndex] < 3000)
                    _buildDetailCard(
                      'Dew Point',
                      '${_provider.forecast!.dewPoint![hourIndex].toStringAsFixed(1)}°',
                      Icons.thermostat,
                    ),
                  if (_provider.currentWeather?.snow != null &&
                      _provider.currentWeather!.snow! > 0 &&
                      _provider.currentWeather!.snow! < 3000)
                    _buildDetailCard(
                      'Snow',
                      '${(_provider.currentWeather!.snow!).toStringAsFixed(1)} cm',
                      Icons.ac_unit,
                    ),
                ].map((card) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  const horizontalPadding =
                      40.0; // Adjust this to match your screen's horizontal padding
                  const spacing = 12.0; // Horizontal spacing between cards
                  final cardWidth =
                      (screenWidth - horizontalPadding - spacing) / 2;

                  return SizedBox(
                    width:
                        cardWidth, // Adjusted width to account for padding and spacing
                    child: card,
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String label, String value, IconData icon) {
    return Card(
      color: Colors.white.withOpacity(0.2),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.white70),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarnings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Text(
                'Weather Warnings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: _provider.forecast!.warnings!.map((warning) {
              return _buildWarningCard(warning);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningCard(WeatherWarning warning) {
    final levelColor = _getWarningColor(warning.level);
    //final levelText = _getWarningLevelText(warning.level);
    final levelText = "!";

    return Card(
      color: levelColor.withOpacity(0.3),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: levelColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning.event ?? warning.title ?? 'Weather Warning',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (warning.start != null || warning.end != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      _formatWarningTime(warning.start, warning.end),
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            if (warning.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  warning.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
            if (warning.instruction != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warning.instruction!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getWarningColor(int? level) {
    switch (level) {
      case 1:
        return Colors.yellow.shade700;
      case 2:
        return Colors.orange.shade700;
      case 3:
        return Colors.red.shade700;
      case 4:
        return Colors.red.shade900;
      default:
        return Colors.amber.shade700;
    }
  }

  String _getWarningLevelText(int? level) {
    switch (level) {
      case 1:
        return 'Minor';
      case 2:
        return 'Moderate';
      case 3:
        return 'Severe';
      case 4:
        return 'Extreme';
      default:
        return 'Advisory';
    }
  }

  String _formatWarningTime(DateTime? start, DateTime? end) {
    final now = DateTime.now();
    final dateFormat = DateFormat('MMM d, HH:mm');

    if (start != null && end != null) {
      if (start.day == end.day) {
        return '${DateFormat('MMM d, HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
      } else {
        return '${dateFormat.format(start)} - ${dateFormat.format(end)}';
      }
    } else if (start != null) {
      return 'From ${dateFormat.format(start)}';
    } else if (end != null) {
      return 'Until ${dateFormat.format(end)}';
    }
    return '';
  }
}
