import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:weatherornot/services/test_service.dart';
import '../models/weather.dart';
import '../models/forecast.dart';
import '../models/day_forecast.dart';
import '../models/weather_warning.dart';
import '../constants/app_constants.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WeatherService {
  static String get baseUrl => AppConstants.brightSkyApiBaseUrl;

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  List<double> _toDoubleList(dynamic v, {bool divideBy10 = false}) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) {
        final d = _toDouble(e);
        return divideBy10 ? d / 10 : d;
      }).toList();
    }
    return [];
  }

  List<int> _toIntList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) {
        if (e is int) return e;
        if (e is double) return e.toInt();
        return int.tryParse(e.toString()) ?? 0;
      }).toList();
    }
    return [];
  }

  List<bool> _toBoolList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) {
        if (e is bool) return e;
        if (e is num) return e != 0;
        final s = e?.toString().toLowerCase();
        return s == 'true' || s == '1';
      }).toList();
    }
    return [];
  }

  Future<Weather> getCurrentDWDWeatherByStationID(
    String stationID, {
    String? locationName,
    List<Map<String, dynamic>>? fallbackStations,
    double? fallbackLat,
    double? fallbackLon,
    String? message,
  }) async {
    if (stationID == 'TEST0') {
      return TestService.getTestWeather();
    }

    try {
      final currentWeatherUrl =
          '${AppConstants.DWDAWSApiBaseUrl}/current_measurement_$stationID.json';
      print('Fetching DWD weather from: $currentWeatherUrl'); // Debug

      final response = await http.get(Uri.parse(currentWeatherUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final weatherData = data;

        if (weatherData != null) {
          print('DWD Weather data received: $weatherData'); // Debug

          return Weather(
            stationName: locationName ?? 'DWD Station $stationID',
            stationId: stationID,
            source:
                'DWD (station $stationID - current measurement) ${message != null ? '\n$message' : ''}',
            temperature:
                weatherData['temperature'] != null &&
                    weatherData['temperature'] < 3000
                ? weatherData['temperature'].toDouble() / 10
                : null,
            precipitation:
                weatherData['precipitation'] != null &&
                    weatherData['precipitation'] < 3000
                ? weatherData['precipitation'].toDouble() / 10
                : null,
            precipitation_3h:
                weatherData['precipitation_3h'] != null &&
                    weatherData['precipitation_3h'] < 3000
                ? weatherData['precipitation_3h'].toDouble() / 10
                : null,
            snow:
                weatherData['totalsnow'] != null &&
                    weatherData['totalsnow'] < 3000
                ? weatherData['totalsnow'].toDouble() / 10
                : null,
            dewpoint:
                weatherData['dewpoint'] != null &&
                    weatherData['dewpoint'] < 3000
                ? weatherData['dewpoint'].toDouble() / 10
                : null,
            sunshine:
                weatherData['sunshine'] != null &&
                    weatherData['sunshine'] < 3000
                ? (weatherData['sunshine'].toDouble() / 10)
                : null,
            windSpeed:
                weatherData['meanwind'] != null &&
                    weatherData['meanwind'] < 3000
                ? weatherData['meanwind'].toDouble() / 10
                : null,
            windGust:
                weatherData['maxwind'] != null && weatherData['maxwind'] < 3000
                ? weatherData['maxwind'].toDouble() / 10
                : null,
            windDirection:
                weatherData['winddirection'] != null &&
                    weatherData['winddirection'] < 3000
                ? weatherData['winddirection'].toDouble() / 10
                : null,
            cloudCover:
                weatherData['cloud_cover_total'] != null &&
                    weatherData['cloud_cover_total'] < 3000
                ? weatherData['cloud_cover_total'].toDouble()
                : null,
            humidity:
                weatherData['humidity'] != null &&
                    weatherData['humidity'] < 3000
                ? weatherData['humidity'].toDouble() / 10
                : null,
            pressure:
                weatherData['pressure'] != null &&
                    weatherData['pressure'] < 3000
                ? weatherData['pressure'].toDouble() / 10
                : null,
            timestamp: DateTime.fromMillisecondsSinceEpoch(weatherData['time']),
            icon: weatherData['icon']?.toInt(),
          );
        }
      }

      // Fallback to mock data for now, if API fails
      // this endpoint denies access for some stations. if this happens, we need to either try the next nearest station or use another api service
      // we could also use the more reliable forecast endpoint and just use the forecast value for the current hour, but obviously, that would be less accurate

      print('DWD API failed, trying to get forecast'); // Debug

      final forecast = await getForecastDWDWeatherByStationID(stationID);

      if (forecast.temperature == null || forecast.temperature!.isEmpty) {
        print('DWD forecast data missing, using Bright Sky'); // Debug

        //recursive fallback to next closest station if available
        if (fallbackStations != null && fallbackStations.isNotEmpty) {
          return getCurrentDWDWeatherByStationID(
            fallbackStations.first["id"],
            locationName: fallbackStations.first["name"],
            fallbackStations: fallbackStations.length > 1
                ? fallbackStations.sublist(1)
                : null,
            fallbackLat: fallbackLat,
            fallbackLon: fallbackLon,
            message:
                'Note: using data from next nearest station - no data available for your selected location',
          );
        } else if (fallbackLat != null && fallbackLon != null) {
          //if nothing helps, just use BrightSky
          return getWeatherByCoordinates(
            fallbackLat,
            fallbackLon,
            locationName: 'DWD Station $stationID',
          );
        } else {
          print('DWD forecast data missing, using mock data'); // Debug
          return _getMockWeather(locationName ?? 'DWD Station $stationID');
        }
      }

      final now = DateTime.now();
      final hourIndex = forecast.start != null
          ? now.difference(forecast.start!).inHours
          : 0;

      print('Forecast start: ${forecast.start}'); // Debug
      print('Hour Index: $hourIndex'); // Debug

      return Weather(
        stationName: locationName ?? 'DWD Station $stationID',
        stationId: stationID,
        source:
            'DWD (station $stationID - based on forecast) ${message != null ? '\n$message' : ''}',
        temperature:
            (forecast.temperature != null &&
                hourIndex < forecast.temperature!.length)
            ? forecast.temperature![hourIndex]
            : null,
        precipitation:
            (forecast.precipitation != null &&
                hourIndex < forecast.precipitation!.length)
            ? forecast.precipitation![hourIndex]
            : null,
        windSpeed:
            (forecast.windSpeed != null &&
                hourIndex < forecast.windSpeed!.length)
            ? forecast.windSpeed![hourIndex]
            : null,
        windGust:
            (forecast.windGust != null && hourIndex < forecast.windGust!.length)
            ? forecast.windGust![hourIndex]
            : null,
        windDirection:
            (forecast.windDirection != null &&
                hourIndex < forecast.windDirection!.length)
            ? forecast.windDirection![hourIndex]
            : null,
        cloudCover:
            (forecast.cloudCover != null &&
                hourIndex < forecast.cloudCover!.length)
            ? forecast.cloudCover![hourIndex]
            : null,
        humidity:
            (forecast.humidity != null && hourIndex < forecast.humidity!.length)
            ? forecast.humidity![hourIndex]
            : null,
        pressure:
            (forecast.pressure != null && hourIndex < forecast.pressure!.length)
            ? forecast.pressure![hourIndex]
            : null,
        condition: null,
        timestamp: now,
        icon: (forecast.icon != null && hourIndex < forecast.icon!.length)
            ? forecast.icon![hourIndex]
            : null,
      );
    } catch (e) {
      print('Error fetching DWD weather: $e'); // Debug
      // Return mock data on error
      if (fallbackLat != null && fallbackLon != null) {
        return getWeatherByCoordinates(
          fallbackLat,
          fallbackLon,
          locationName: locationName ?? 'DWD Station $stationID',
        );
      } else {
        return _getMockWeather(locationName ?? 'DWD Station $stationID');
      }
    }
  }

  Future<Forecast> getForecastDWDWeatherByStationID(String stationID) async {
    if (stationID == 'TEST0') {
      return TestService.getTestForecast();
    }

    try {
      final rawUrl =
          '${AppConstants.DWDApiBaseUrl}/stationOverviewExtended?stationIds=$stationID';

      //cors issues when working on web, using corsproxy.io when testing on web (dev only)
      final forecastUrl = kIsWeb ? 'https://corsproxy.io/?$rawUrl' : rawUrl;

      print('Fetching DWD forecast from: $forecastUrl'); // Debug

      final uri = Uri.parse(forecastUrl);
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'WeatherOrNot/1.0',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body)[stationID];
        print('DWD Forecast data received: $data'); // Debug

        final forecast = data['forecast1'];
        final forecast2 = data['forecast2'];
        final warnings = data['warnings'];
        final days = data['days'];

        // Parse the forecast data here and return a Forecast object
        // the parsing of the days and warnings field does not work yet, still returns empty lists
        return Forecast(
          stationName: 'DWD Station $stationID',
          stationId: forecast["stationId"] ?? stationID,
          source: 'DWD (station $stationID)',
          start: forecast['start'] != null
              ? DateTime.fromMillisecondsSinceEpoch(forecast['start'])
              : DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                ),
          timestep: forecast['timestep']?.toInt(),
          temperature: _toDoubleList(forecast['temperature'], divideBy10: true),
          windSpeed: _toDoubleList(forecast['windSpeed'], divideBy10: true),
          windGust: _toDoubleList(forecast['windGust'], divideBy10: true),
          windDirection: _toDoubleList(
            forecast['windDirection'],
            divideBy10: true,
          ),
          precipitation: _toDoubleList(
            forecast['precipitationTotal'],
            divideBy10: true,
          ),
          sunshine: _toDoubleList(forecast['sunshine'], divideBy10: true),
          dewPoint: _toDoubleList(forecast['dewPoint2m'], divideBy10: true),
          cloudCover: _toDoubleList(forecast['cloudCoverTotal']),
          humidity: _toDoubleList(forecast['humidity'], divideBy10: true),
          pressure: _toDoubleList(
            forecast['surfacePressure'],
            divideBy10: true,
          ),
          isDaylight: _toBoolList(forecast['isDay']),
          precipitationProbability: _toDoubleList(
            forecast['precipitationProbability'],
          ),
          icon: _toIntList(forecast['icon']),
          days: days != null
              ? (days as List).map((dayData) {
                  return DayForecast(
                    date: dayData['dayDate'] != null
                        ? DateTime.parse(dayData['dayDate'])
                        : DateTime.now(),
                    minTemperature: dayData['temperatureMin'] != null
                        ? dayData['temperatureMin'].toDouble() / 10
                        : null,
                    maxTemperature: dayData['temperatureMax'] != null
                        ? dayData['temperatureMax'].toDouble() / 10
                        : null,
                    precipitation: dayData['precipitation'] != null
                        ? dayData['precipitation'].toDouble() / 10
                        : null,
                    windSpeed: dayData['windSpeed'] != null
                        ? dayData['windSpeed'].toDouble() / 10
                        : null,
                    windGust: dayData['windGust'] != null
                        ? dayData['windGust'].toDouble() / 10
                        : null,
                    windDirection: dayData['windDirection'] != null
                        ? dayData['windDirection'].toDouble() / 10
                        : null,
                    sunshine: dayData['sunshine'] != null
                        ? dayData['sunshine'].toDouble() / 10
                        : null,
                    sunrise: dayData['sunrise'] != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            dayData['sunrise'],
                          )
                        : null,
                    sunset: dayData['sunset'] != null
                        ? DateTime.fromMillisecondsSinceEpoch(dayData['sunset'])
                        : null,
                    moonrise: dayData['moonrise'] != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            dayData['moonrise'],
                          )
                        : null,
                    moonset: dayData['moonset'] != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            dayData['moonset'],
                          )
                        : null,
                    moonphase: dayData['moonphase']?.toInt(),
                    icon: dayData['icon']?.toInt(),
                  );
                }).toList()
              : [],
          warnings: warnings != null
              ? (warnings as List).map((warningData) {
                  return WeatherWarning(
                    warnId: warningData['warnId'] ?? '',
                    type: warningData['type']?.toInt(),
                    level: warningData['level']?.toInt(),
                    event: warningData['event'] ?? '',
                    title: warningData['headline'] ?? 'Warnung',
                    description: warningData['description'] ?? '',
                    start: warningData['start'] != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            warningData['start'],
                          )
                        : DateTime.now(),
                    end: warningData['end'] != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            warningData['end'],
                          )
                        : DateTime.now(),
                    instruction: warningData['instruction'] ?? '',
                  );
                }).toList()
              : [],
        );
      }
    } catch (e) {
      print('Error fetching DWD forecast: $e'); // Debug
      print('Returning empty forecast'); // Debug
    }

    return Forecast(
      stationName: 'DWD Station $stationID',
      stationId: stationID,
    );
  }

  /// Fetches weather data for specific coordinates
  Future<Weather> getWeatherByCoordinates(
    double lat,
    double lon, {
    String? locationName,
  }) async {
    try {
      final date = DateTime.now().toIso8601String().split('T')[0];

      final url = '$baseUrl/current_weather?lat=$lat&lon=$lon&date=$date';
      print('Fetching weather from: $url'); // Debug

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final weatherData = data['weather'];

        if (weatherData != null) {
          print('Weather data received: $weatherData'); // Debug

          // Bright Sky API provides wind_speed_10, wind_speed_30, wind_speed_60
          // Use the 60-minute average for most accurate current conditions
          final windSpeed =
              weatherData['wind_speed_60']?.toDouble() ??
              weatherData['wind_speed_30']?.toDouble() ??
              weatherData['wind_speed_10']?.toDouble();

          // Precipitation is also in different time intervals
          final precipitation =
              weatherData['precipitation_60']?.toDouble() ??
              weatherData['precipitation_30']?.toDouble() ??
              weatherData['precipitation_10']?.toDouble();

          return Weather(
            stationName: locationName ?? 'Unknown',
            stationId: locationName ?? 'unknown',
            source: 'Bright Sky',
            temperature: weatherData['temperature']?.toDouble(),
            precipitation: precipitation,
            windSpeed: windSpeed,
            cloudCover: weatherData['cloud_cover']?.toDouble(),
            humidity: weatherData['relative_humidity']?.toDouble(),
            pressure: weatherData['pressure_msl']?.toDouble(),
            condition: weatherData['condition'] ?? 'dry',
            timestamp: DateTime.parse(
              weatherData['timestamp'] ?? DateTime.now().toIso8601String(),
            ),
          );
        }
      }

      print('API failed, using mock data'); // Debug
      // Fallback to mock data if API fails
      return _getMockWeather(locationName ?? 'Unknown');
    } catch (e) {
      print('Error fetching weather: $e'); // Debug
      // Return mock data on error
      return _getMockWeather(locationName ?? 'Unknown');
    }
  }

  /// Returns mock weather data for testing
  Weather _getMockWeather(String locationName) {
    //final random = Random();
    return Weather(
      stationName: locationName,
      stationId: locationName.toLowerCase().replaceAll(' ', '_'),
      source: 'not found',
      temperature: null,
      precipitation: null,
      windSpeed: null,
      cloudCover: null,
      humidity: null,
      pressure: null,
      icon: 32,
      timestamp: DateTime.now(),
    );
  }

  IconData getWeatherIcon(String? condition) {
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

  IconData getWeatherIconById(int? iconId) {
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
      case 32: // unknown
        return Icons.block;
      default:
        return Icons.wb_cloudy_outlined;
    }
  }

  String getWeatherDescriptionById(int? iconId) {
    String condition;
    switch (iconId) {
      case 1:
        condition = 'Sunny';
        break;
      case 2:
        condition = 'Partly cloudy';
        break;
      case 3:
        condition = 'Cloudy';
        break;
      case 4:
        condition = 'Overcast';
        break;
      case 5:
        condition = 'Fog';
        break;
      case 6:
        condition = 'Foggy';
        break;
      case 7:
        condition = 'Light rain';
        break;
      case 8:
        condition = 'Rain';
        break;
      case 9:
        condition = 'Heavy rain';
        break;
      case 10:
        condition = 'Light rain, slippery';
        break;
      case 11:
        condition = 'Heavy rain, slippery';
        break;
      case 12:
        condition = 'Rain, occasional snowfall';
        break;
      case 13:
        condition = 'Rain, increased snowfall';
        break;
      case 14:
        condition = 'Light snowfall';
        break;
      case 15:
        condition = 'Snowfall';
        break;
      case 16:
        condition = 'Heavy snowfall';
        break;
      case 17:
        condition = 'Clouds, hail';
        break;
      case 18:
        condition = 'Sunny, light rain';
        break;
      case 19:
        condition = 'Sunny, heavy rain';
        break;
      case 20:
        condition = 'Sun, rain, occasional snowfall';
        break;
      case 21:
        condition = 'Sun, rain, increased snowfall';
        break;
      case 22:
        condition = 'Sunny, occasional snowfall';
        break;
      case 23:
        condition = 'Sunny, increased snowfall';
        break;
      case 24:
        condition = 'Sunny, hail';
        break;
      case 25:
        condition = 'Sunny, heavy hail';
        break;
      case 26:
        condition = 'Thunderstorm';
        break;
      case 27:
        condition = 'Thunderstorm, rain';
        break;
      case 28:
        condition = 'Thunderstorm, heavy rain';
        break;
      case 29:
        condition = 'Thunderstorm, hail';
        break;
      case 30:
        condition = 'Thunderstorm, heavy hail';
        break;
      case 31:
        condition = 'Windy';
        break;
      case 32:
        condition =
            'Unfortunately, we could not get weather data for your location';
        break;
      default:
        condition = '';
        break;
    }

    return condition;
  }

  List<Color> getGradientColors(
    Weather? weather,
    Forecast? forecast,
    int? forecastIndex,
  ) {
    final hour = DateTime.now().hour;
    final index = forecastIndex ?? 0;
    final sunrise =
        forecast != null && forecast.days != null && forecast.days!.isNotEmpty && index < forecast.days!.length
        ? forecast.days![index].sunrise?.hour ?? 6
        : 6;
    final sunset =
        forecast != null && forecast.days != null && forecast.days!.isNotEmpty && index < forecast.days!.length
        ? forecast.days![index].sunset?.hour ?? 18
        : 18;

    // choose base gradient by time of day
    List<Color> base;
    if (hour >= sunrise && hour < 12) {
      base = [Color(0xFF4A90E2), Color(0xFF50C9FF)]; // Morning
    } else if (hour >= 12 && hour < sunset - 1) {
      base = [Color(0xFF56CCF2), Color(0xFF2F80ED)]; // Afternoon
    } else if (hour >= sunset - 1 && hour < sunset + 1) {
      base = [Color(0xFFFF6B6B), Color(0xFFFFB347)]; // Evening
    } else {
      base = [Color(0xFF2C3E50), Color(0xFF3E5266)]; // Night
    }

    // Determine cloud cover percent (0..100). Prefer current weather, fall back to forecast values.
    double cloudCoverPercent = 0.0;

    if (forecastIndex != null &&
        forecast != null &&
        forecast.days != null &&
        index < forecast.days!.length) {
      final sunshine = forecast.days![index].sunshine ?? 0;
      final negativeSunshine =
          100 -
          sunshine / 60 * 10; // "convert" sunshine hours to cloud percentage
      cloudCoverPercent = negativeSunshine.clamp(0, 100).toDouble();
    }

    if (weather != null && weather.cloudCover != null) {
      cloudCoverPercent = weather.cloudCover!.clamp(0, 100).toDouble();
    } else if (forecast != null &&
        forecast.cloudCover != null &&
        forecast.cloudCover!.isNotEmpty) {
      final now = DateTime.now();

      final hourIndex = forecast.start != null
          ? now.difference(forecast.start!).inHours
          : 0;
      if (hourIndex >= 0 && hourIndex < forecast.cloudCover!.length) {
        cloudCoverPercent = forecast.cloudCover![hourIndex]
            .clamp(0, 100)
            .toDouble();
      }
    }

    // If no cloud data or zero cloud cover, return base gradient
    if (cloudCoverPercent <= 0) return base;

    // Desaturate each base color proportionally to cloud cover (100% => fully desaturated)
    return base.map((c) {
      final hsl = HSLColor.fromColor(c);
      final newSat = hsl.saturation * (1 - cloudCoverPercent / 100.0);
      return hsl.withSaturation(newSat).toColor();
    }).toList();
  }
}
