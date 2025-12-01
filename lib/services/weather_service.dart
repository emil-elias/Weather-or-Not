import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
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
            source: 'DWD (Station $stationID - aktuelle Messung) ${message != null ? '\n$message' : ''}',
            temperature: weatherData['temperature'] != null
                ? weatherData['temperature'].toDouble() / 10
                : null,
            precipitation: weatherData['precipitation'] != null
                ? weatherData['precipitation'].toDouble() / 10
                : null,
            precipitation_3h: weatherData['precipitation_3h'] != null
                ? weatherData['precipitation_3h'].toDouble() / 10
                : null,
            snow: weatherData['totalsnow'] != null
                ? weatherData['totalsnow'].toDouble() / 10
                : null,
            dewpoint: weatherData['dewpoint'] != null
                ? weatherData['dewpoint'].toDouble() / 10
                : null,
            sunshine: weatherData['sunshine'] != null
                ? weatherData['sunshine'].toDouble() / 10
                : null,
            windSpeed: weatherData['meanwind'] != null
                ? weatherData['meanwind'].toDouble() / 10
                : null,
            windGust: weatherData['maxwind'] != null
                ? weatherData['maxwind'].toDouble() / 10
                : null,
            windDirection: weatherData['winddirection'] != null
                ? weatherData['winddirection'].toDouble() / 10
                : null,
            cloudCover: weatherData['cloud_cover_total']?.toDouble(),
            humidity: weatherData['humidity'] != null
                ? weatherData['humidity'].toDouble() / 10
                : null,
            pressure: weatherData['pressure'] != null
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
            message: 'Hinweis: Daten der nächsten verfügbaren Station \n- keine verfügbaren Daten an Ihrem aktuellen Standort'
          );
        } else if (fallbackLat != null && fallbackLon != null) { //if nothing helps, just use BrightSky
          return getWeatherByCoordinates(
            fallbackLat,
            fallbackLon,
            locationName: 'DWD Station $stationID',
          );
        } else {
          print('DWD forecast data missing, using mock data'); // Debug
          return _getMockWeather('DWD Station $stationID');
        }
      }

      final now = DateTime.now();
      final hourIndex = forecast.start != null ? now.difference(forecast.start!).inHours : 0;

      print('Forecast start: ${forecast.start}'); // Debug
      print('Hour Index: $hourIndex'); // Debug

      return Weather(
        stationName: locationName ?? 'DWD Station $stationID',
        stationId: stationID,
        source: 'DWD (Station $stationID - basierend auf Vorhersage) ${message != null ? '\n$message' : ''}',
        temperature: (forecast.temperature != null &&
                hourIndex < forecast.temperature!.length)
            ? forecast.temperature![hourIndex]
            : null,
        precipitation: (forecast.precipitation != null &&
                hourIndex < forecast.precipitation!.length)
            ? forecast.precipitation![hourIndex]
            : null,
        windSpeed: (forecast.windSpeed != null &&
                hourIndex < forecast.windSpeed!.length)
            ? forecast.windSpeed![hourIndex]
            : null,
        windGust: (forecast.windGust != null &&
                hourIndex < forecast.windGust!.length)
            ? forecast.windGust![hourIndex]
            : null,
        windDirection: (forecast.windDirection != null &&
                hourIndex < forecast.windDirection!.length)
            ? forecast.windDirection![hourIndex]
            : null,
        cloudCover: (forecast.cloudCover != null &&
                hourIndex < forecast.cloudCover!.length)
            ? forecast.cloudCover![hourIndex]
            : null,
        humidity: (forecast.humidity != null &&
                hourIndex < forecast.humidity!.length)
            ? forecast.humidity![hourIndex]
            : null,
        pressure: (forecast.pressure != null &&
                hourIndex < forecast.pressure!.length)
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
          locationName: 'DWD Station $stationID',
        );
      } else {
        return _getMockWeather('DWD Station $stationID');
      }
    }
  }

  Future<Forecast> getForecastDWDWeatherByStationID(String stationID) async {
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
        final days = data['days'];

        // Parse the forecast data here and return a Forecast object
        // the parsing of the days and warnings field does not work yet, still returns empty lists
        return Forecast(
          stationName: 'DWD Station $stationID',
          stationId: forecast["stationId"] ?? stationID,
          source:
              'DWD (station $stationID - overview extended forecast)',
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
          pressure: _toDoubleList(forecast['surfacePressure'], divideBy10: true),
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
          warnings: forecast2['warnings'] != null
              ? (forecast2['warnings'] as List).map((warningData) {
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
    final random = Random();
    return Weather(
      stationName: locationName,
      stationId: locationName.toLowerCase().replaceAll(' ', '_'),
      source: 'Mock Data',
      temperature: 10 + random.nextDouble() * 5,
      precipitation: random.nextDouble() * 2,
      windSpeed: 10 + random.nextDouble() * 10,
      cloudCover: 50 + random.nextInt(30).toDouble(),
      humidity: 70 + random.nextInt(20).toDouble(),
      pressure: 1013.0 + (random.nextDouble() - 0.5) * 20,
      condition: ['dry', 'fog', 'rain', 'snow'][random.nextInt(4)],
      timestamp: DateTime.now(),
    );
  }
}
