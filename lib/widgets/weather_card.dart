import 'package:flutter/material.dart';
import 'package:weatherornot/constants/app_constants.dart';
import 'package:weatherornot/models/forecast.dart';
import 'package:weatherornot/models/weather.dart';
import 'package:weatherornot/services/weather_service.dart';

class WeatherCard extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final Weather? currentWeather;
  final Forecast? forecast;
  final int? forecastIndex;
  final VoidCallback? onTap;
  final WeatherService weatherService = WeatherService();

  WeatherCard({
    super.key,
    required this.isLoading,
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
            colors: weatherService.getGradientColors(currentWeather, forecast, forecastIndex),
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
                _getIcon(),

                // Temperature
                _getTemperature(),

                if (currentWeather != null)
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.arrow_upward_rounded,
                            size: 16,
                            //color: Color(0xFF4AFF8C),
                            color: Colors.white
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
                            color: Colors.white
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
                Text(
                  'Source: ${currentWeather?.source ?? forecast?.source ?? "trust me bro"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
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
    if (currentWeather != null) {
      if (currentWeather!.icon != null) {
        return weatherService.getWeatherDescriptionById(currentWeather!.icon);
      } else if (currentWeather!.condition != null) {
        return WeatherConditions.getGermanDescription(
          currentWeather!.condition,
          temperature: currentWeather?.temperature,
          windSpeed: currentWeather?.windSpeed,
          cloudCover: currentWeather?.cloudCover,
        );
      }
    } else if (forecast?.days != null && forecast!.days!.isNotEmpty) {
      if (forecastIndex != null) {
        return weatherService.getWeatherDescriptionById(
          forecast!.days![forecastIndex!].icon,
        );
      } else {
        return weatherService.getWeatherDescriptionById(
          forecast!.days!.first.icon,
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
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildWeatherDetail(
            Icons.water_drop_outlined,
            '${currentWeather!.humidity?.clamp(0,100).toStringAsFixed(0) ?? '--'}%',
            'Humidity',
          ),
          _buildWeatherDetail(
            Icons.air_outlined,
            '${currentWeather!.windSpeed?.toStringAsFixed(1) ?? forecast?.days?.first.windSpeed?.toStringAsFixed(1) ?? '--'} km/h',
            'Wind',
          ),
          _buildWeatherDetail(
            Icons.cloud_outlined,
            '${currentWeather!.cloudCover?.clamp(0,100).toStringAsFixed(0)  ?? '--'}%',
            'Cloud Cover',
          ),
        ],
      );
    } else if (forecast?.days != null && forecast!.days!.isNotEmpty) {
      int index = forecastIndex ?? 0;
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
            '${(forecast!.days![index].sunshine != null ? forecast!.days![index].sunshine! / 60 : 0).clamp(0,24).toStringAsFixed(0)} h',
            'Sunshine',
          )
        ],
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Icon _getIcon() {
    if (currentWeather != null) {
      return Icon(
        currentWeather!.icon != null
            ? weatherService.getWeatherIconById(currentWeather!.icon)
            : weatherService.getWeatherIcon(currentWeather!.condition),
        size: 80,
        color: Colors.white,
      );
    } else if (forecast?.days != null && forecast!.days!.isNotEmpty) {
      if (forecastIndex != null) {
        return Icon(
          weatherService.getWeatherIconById(
            forecast!.days![forecastIndex!].icon,
          ),
          size: 80,
          color: Colors.white,
        );
      } else {
        return Icon(
          weatherService.getWeatherIconById(forecast!.days!.first.icon),
          size: 80,
          color: Colors.white,
        );
      }
    } else {
      return Icon(Icons.question_mark, size: 80, color: Colors.white);
    }
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

    if (currentWeather != null) {
      return Text(
        '${currentWeather!.temperature?.toStringAsFixed(0) ?? '--'}°',
        style: style1,
      );
    } else if (forecast?.days != null && forecast!.days!.isNotEmpty) {
      if (forecastIndex != null) {
        return Text(
          '${forecast!.days![forecastIndex!].maxTemperature?.toStringAsFixed(0)}°/${forecast!.days![forecastIndex!].minTemperature?.toStringAsFixed(0)}°',
          style: style2,
        );
      } else {
        return Text(
          '${forecast!.days!.first.maxTemperature?.toStringAsFixed(0)}°/${forecast!.days!.first.minTemperature?.toStringAsFixed(0)}°',
          style: style2,
        );
      }
    } else {
      return Text("?°", style: style1);
    }
  }
}
