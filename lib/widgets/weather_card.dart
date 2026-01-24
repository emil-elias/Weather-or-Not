import 'package:flutter/material.dart';
import 'package:weatherornot/constants/app_constants.dart';
import 'package:weatherornot/models/forecast.dart';
import 'package:weatherornot/models/weather.dart';
import 'package:weatherornot/services/weather_service.dart';

class WeatherCard extends StatelessWidget {
  final bool isLoading;
  final bool? flatBottomCorners;
  final String? errorMessage;
  final Weather? currentWeather;
  final Forecast? forecast;
  final int? forecastIndex;
  final VoidCallback? onTap;
  final WeatherService weatherService = WeatherService();

  WeatherCard({
    super.key,
    required this.isLoading,
    this.flatBottomCorners,
    this.errorMessage,
    this.currentWeather,
    this.forecast,
    this.forecastIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Text(
          errorMessage!,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: weatherService.getGradientColors(
              currentWeather,
              forecast,
              forecastIndex,
            ),
          ),
          borderRadius: flatBottomCorners == null || flatBottomCorners != true
              ? BorderRadius.circular(24)
              : const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
          boxShadow: [
            BoxShadow(
              color: weatherService.getGradientColors(
                currentWeather,
                forecast,
                forecastIndex,
              ).last.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 0),
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
                _getIcon(),

                // Temperature
                _getTemperature(),

                if (currentWeather != null && currentWeather!.icon != 32)
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
                            ' ${_getMaxTemperature().toStringAsFixed(0)}°',
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
                            ' ${_getMinTemperature().toStringAsFixed(0)}°',
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

                // Arrow
                if (onTap != null)
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white70,
                    size: 28,
                  )
                else
                  const SizedBox(width: 28),
              ],
            ),
            const SizedBox(height: 24),

            // Weather description
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getWeatherDescription(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(),
                ],
              ),
            ),

            const SizedBox(height: 16),
            // Source
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'Source: ${currentWeather?.source ?? forecast?.source ?? "not found"}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
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

  double _getMaxTemperature() {
    if (forecast?.days?.isNotEmpty == true) {
      return forecast!.days![0].maxTemperature ??
          currentWeather!.temperature ??
          0;
    }
    return currentWeather!.temperature ?? 0;
  }

  double _getMinTemperature() {
    if (forecast?.days?.isNotEmpty == true) {
      return forecast!.days![0].minTemperature ??
          currentWeather!.temperature ??
          0;
    }
    return currentWeather!.temperature ?? 0;
  }

  String _getWeatherDescription() {
    if (currentWeather == null &&
        forecastIndex != null &&
        forecast?.days != null &&
        forecast!.days!.isNotEmpty) {
      if (forecast!.days!.length > forecastIndex!) {
        return weatherService.getWeatherDescriptionById(
          forecast!.days![forecastIndex!].icon,
        );
      } else {
        return "No forecast available for this date";
      }
    } else if (currentWeather != null && currentWeather!.condition != null) {
      return WeatherConditions.getGermanDescription(
        currentWeather!.condition,
        temperature: currentWeather?.temperature,
        windSpeed: currentWeather?.windSpeed,
        cloudCover: currentWeather?.cloudCover,
      );
    } else if (currentWeather != null &&
        currentWeather!.icon != null &&
        currentWeather!.icon! <= 32) {
      return weatherService.getWeatherDescriptionById(currentWeather!.icon);
    } else if (forecast != null &&
        forecast!.icon != null &&
        forecast!.icon!.isNotEmpty) {
      final now = DateTime.now();
      final hourIndex = forecast?.start != null
          ? now.difference(forecast!.start!).inHours
          : 0;
      if (forecast!.icon!.length > hourIndex) {
        return weatherService.getWeatherDescriptionById(
          forecast!.icon![hourIndex],
        );
      }
    }

    return "";
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

  Widget _buildDetailRow() {
    if (currentWeather != null) {
      if (currentWeather!.icon == 32) {
        return SizedBox.shrink();
      }

      final now = DateTime.now();
      final hourIndex = forecast?.start != null
          ? now.difference(forecast!.start!).inHours
          : 0;

      String humidity = "--%";
      if (currentWeather!.humidity != null &&
          currentWeather!.humidity! < 3000) {
        humidity =
            '${currentWeather!.humidity!.clamp(0, 100).toStringAsFixed(0)}%';
      } else if (forecast != null &&
          forecast!.humidity != null &&
          forecast!.humidity!.isNotEmpty &&
          forecast!.humidity!.length > hourIndex) {
        humidity =
            '${forecast!.humidity![hourIndex].clamp(0, 100).toStringAsFixed(0)}%';
      }

      String wind = "-- km/h";
      if (currentWeather!.windSpeed != null &&
          currentWeather!.windSpeed! < 3000) {
        wind = '${currentWeather!.windSpeed!.toStringAsFixed(1)} km/h';
      } else if (forecast != null &&
          forecast!.windSpeed != null &&
          forecast!.windSpeed!.isNotEmpty &&
          forecast!.windSpeed!.length > hourIndex &&
          forecast!.windSpeed![hourIndex] < 3000) {
        wind = '${forecast!.windSpeed![hourIndex].toStringAsFixed(1)} km/h';
      } else if (forecast != null &&
          forecast!.days != null &&
          forecast!.days!.isNotEmpty) {
        wind =
            '${forecast!.days!.first.windSpeed?.toStringAsFixed(1) ?? '--'} km/h';
      }

      String cloudCover = "--%";
      if (currentWeather!.cloudCover != null &&
          currentWeather!.cloudCover! < 3000) {
        cloudCover =
            '${currentWeather!.cloudCover!.clamp(0, 100).toStringAsFixed(0)}%';
      } else if (forecast != null &&
          forecast!.cloudCover != null &&
          forecast!.cloudCover!.isNotEmpty &&
          forecast!.cloudCover!.length > hourIndex &&
          forecast!.cloudCover![hourIndex] < 3000) {
        cloudCover =
            '${forecast!.cloudCover![hourIndex].clamp(0, 100).toStringAsFixed(0)}%';
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildWeatherDetail(Icons.water_drop_outlined, humidity, 'Humidity'),
          _buildWeatherDetail(Icons.air_outlined, wind, 'Wind'),
          _buildWeatherDetail(Icons.cloud_outlined, cloudCover, 'Cloud Cover'),
        ],
      );
    } else if (forecast?.days != null && forecast!.days!.isNotEmpty) {
      int index = 0;

      if (forecastIndex != null) {
        if (forecast!.days!.length > forecastIndex!) {
          index = forecastIndex!;
        } else {
          return SizedBox.shrink();
        }
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildWeatherDetail(
            Icons.water_drop_outlined,
            '${forecast!.days![index].precipitation?.toStringAsFixed(0) ?? '--'} mm',
            'Precipitation',
          ),
          _buildWeatherDetail(
            Icons.air_outlined,
            '${forecast!.days![index].windSpeed?.toStringAsFixed(1) ?? '--'} km/h',
            'Wind',
          ),
          _buildWeatherDetail(
            Icons.wb_sunny_outlined,
            '${(forecast!.days![index].sunshine != null ? forecast!.days![index].sunshine! / 60 : 0).clamp(0, 24).toStringAsFixed(0)} h',
            'Sunshine',
          ),
        ],
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Icon _getIcon() {
    if (currentWeather == null &&
        forecastIndex != null &&
        forecast?.days != null &&
        forecast!.days!.isNotEmpty) {
      if (forecast!.days!.length > forecastIndex!) {
        return Icon(
          weatherService.getWeatherIconById(
            forecast!.days![forecastIndex!].icon,
          ),
          size: 80,
          color: Colors.white,
        );
      } else {
        return Icon(Icons.block, size: 80, color: Colors.white);
      }
    } else if (currentWeather != null && currentWeather!.condition != null) {
      return Icon(
        weatherService.getWeatherIcon(currentWeather!.condition),
        size: 80,
        color: Colors.white,
      );
    } else if (currentWeather != null &&
        currentWeather!.icon != null &&
        currentWeather!.icon! <= 32) {
      return Icon(
        weatherService.getWeatherIconById(currentWeather!.icon),
        size: 80,
        color: Colors.white,
      );
    } else if (forecast != null &&
        forecast!.icon != null &&
        forecast!.icon!.isNotEmpty) {
      final now = DateTime.now();
      final hourIndex = forecast?.start != null
          ? now.difference(forecast!.start!).inHours
          : 0;

      if (forecast!.icon!.length > hourIndex) {
        return Icon(
          weatherService.getWeatherIconById(forecast!.icon![hourIndex]),
          size: 80,
          color: Colors.white,
        );
      }
    }

    return Icon(Icons.question_mark, size: 80, color: Colors.white);
  }

  Widget _getTemperature() {
    const TextStyle style1 = TextStyle(
      fontSize: 72,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      height: 1,
    );

    const TextStyle style2 = TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      height: 1,
    );

    if (currentWeather == null &&
        forecastIndex != null &&
        forecast?.days != null &&
        forecast!.days!.isNotEmpty) {
      if (forecast!.days!.length > forecastIndex!) {
        return Text(
          '${forecast!.days![forecastIndex!].maxTemperature?.toStringAsFixed(0)}°/${forecast!.days![forecastIndex!].minTemperature?.toStringAsFixed(0)}°',
          style: style2,
        );
      } else {
        return Text("", style: style1);
      }
    } else if (currentWeather != null &&
        currentWeather!.temperature != null &&
        currentWeather!.temperature! < 3000) {
      return Text(
        '${currentWeather!.temperature?.toStringAsFixed(0) ?? '--'}°',
        style: style1,
      );
    } else if (forecast != null &&
        forecast!.temperature != null &&
        forecast!.temperature!.isNotEmpty) {
      final now = DateTime.now();
      final hourIndex = forecast?.start != null
          ? now.difference(forecast!.start!).inHours
          : 0;

      if (forecast!.temperature!.length > hourIndex) {
        return Text(
          '${forecast!.temperature?[hourIndex].toStringAsFixed(0) ?? '--'}°',
          style: style1,
        );
      }
    }

    return Text("", style: style1);
  }
}
