import 'package:flutter/material.dart';
import '../models/weather.dart';
import '../models/forecast.dart';
import '../services/weather_service.dart';
import '../constants/app_constants.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../services/location_service.dart';

class MainProvider extends ChangeNotifier {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();

  Weather? _currentWeather;
  Forecast? _forecast;
  String? _errorMessage;
  bool _isLoading = false;
  String _selectedLocation = 'Bremen, Germany';
  List<Map<String, dynamic>> _closestLocations = [];

  final List<String> _locations = [
    'Bremen, Germany',
    'Hamburg, Germany',
    'Berlin, Germany',
    'München, Germany',
    /*'Köln, Germany',*/
    'Lisboa, Portugal',
  ];

  final Map<String, Map<String, double>> _locationCoordinates = {
    'Bremen, Germany': {'lat': 53.0793, 'lon': 8.8017},
    'Hamburg, Germany': {'lat': 53.5511, 'lon': 9.9937},
    'Berlin, Germany': {'lat': 52.5200, 'lon': 13.4050},
    'München, Germany': {'lat': 48.1351, 'lon': 11.5820},
    'Köln, Germany': {'lat': 50.9375, 'lon': 6.9603},
    'Lisboa, Portugal': {'lat': 38.47, 'lon': -9.08},
  };

  final Map<String, String> stationIDs = Map<String, String>.from(AppConstants.stationIDs);

  Weather? get currentWeather => _currentWeather;
  Forecast? get forecast => _forecast;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  String get selectedLocation => _selectedLocation;
  List<Map<String, dynamic>> get closestLocations => _closestLocations;
  List<String> get locations => _locations;
  Map<String, Map<String, double>> get locationCoordinates => _locationCoordinates;


  void setSelectedLocation(String location) {
    _selectedLocation = location;
    notifyListeners();
  }

  Future<void> getClosestLocation() async {
    try {
      final geo.Position userPosition = await _locationService.getCurrentLocation();
      final List<Map<String, dynamic>> closestList = await _locationService.findClosestLocation(userPosition);
      //print(closestList);
      final closest = closestList.first;

      print('User position: ${userPosition.latitude}, ${userPosition.longitude}');

      _locations.insert(0, closest['name']);
      stationIDs[closest['name']] = closest['id'];
      _closestLocations = closestList;
      setSelectedLocation(closest['name']);
      
      loadWeather(
          closest['id'],
          closest['name'],
          fallbackStations: closestList.sublist(1),
          fallbackLat: userPosition.latitude,
          fallbackLon: userPosition.longitude
        );

    } catch (e) {
      print('Error getting location: $e');
      setSelectedLocation('Bremen, Germany');
      loadWeather(
        stationIDs['Bremen, Germany']!,
        'Bremen, Germany',
        fallbackLat: _locationCoordinates['Bremen, Germany']!['lat'],
        fallbackLon: _locationCoordinates['Bremen, Germany']!['lon'],
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadWeather(
    String stationId,
    String locationName, {
    List<Map<String, dynamic>>? fallbackStations,
    double? fallbackLat,
    double? fallbackLon,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedLocation = locationName;
    notifyListeners();

    try {
      final weather = await _weatherService.getCurrentDWDWeatherByStationID(
        stationId,
        locationName: locationName,
        fallbackStations: fallbackStations,
        fallbackLat: fallbackLat,
        fallbackLon: fallbackLon,
      );

      if (weather.stationName != _selectedLocation) {
          final oldLocation = _selectedLocation;
          _locations.remove(oldLocation);
          if (!_locations.contains(weather.stationName)) {
            _locations.insert(0, weather.stationName);
          }
          _selectedLocation = weather.stationName;
          stationIDs[weather.stationName] = weather.stationId;
          stationId = weather.stationId;
      }

      final forecast = await _weatherService.getForecastDWDWeatherByStationID(
        stationId,
      );

      _currentWeather = weather;
      _forecast = forecast;
      
    } catch (e) {
      _errorMessage = 'Wetter konnte nicht geladen werden';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
