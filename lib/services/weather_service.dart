import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/weather.dart';
import '../constants/app_constants.dart';

class WeatherService {
  static String get baseUrl => AppConstants.brightSkyApiBaseUrl;

  /// Fetches weather data for specific coordinates
  Future<Weather> getWeatherByCoordinates(double lat, double lon, {String? locationName}) async {
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
          final windSpeed = weatherData['wind_speed_60']?.toDouble() ?? 
                           weatherData['wind_speed_30']?.toDouble() ?? 
                           weatherData['wind_speed_10']?.toDouble();
          
          // Precipitation is also in different time intervals
          final precipitation = weatherData['precipitation_60']?.toDouble() ?? 
                               weatherData['precipitation_30']?.toDouble() ?? 
                               weatherData['precipitation_10']?.toDouble();
          
          return Weather(
            stationName: locationName ?? 'Unknown',
            stationId: locationName ?? 'unknown',
            temperature: weatherData['temperature']?.toDouble(),
            precipitation: precipitation,
            windSpeed: windSpeed,
            cloudCover: weatherData['cloud_cover']?.toInt(),
            humidity: weatherData['relative_humidity']?.toInt(),
            pressure: weatherData['pressure_msl']?.toDouble(),
            condition: weatherData['condition'] ?? 'dry',
            timestamp: DateTime.parse(weatherData['timestamp'] ?? DateTime.now().toIso8601String()),
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
      temperature: 10 + random.nextDouble() * 5,
      precipitation: random.nextDouble() * 2,
      windSpeed: 10 + random.nextDouble() * 10,
      cloudCover: 50 + random.nextInt(30),
      humidity: 70 + random.nextInt(20),
      pressure: 1013.0 + (random.nextDouble() - 0.5) * 20,
      condition: ['dry', 'fog', 'rain', 'snow'][random.nextInt(4)],
      timestamp: DateTime.now(),
    );
  }

}
