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
  bool _isLoading = true;
  Map<String, dynamic> _selectedLocation = {
    "name": "...",
    "id": "10224",
    "lat": 53.0451,
    "lon": 8.7981,
  };
  List<Map<String, dynamic>> _closestLocations = [];
  bool _locationAccessDenied = false;

  final List<String> _locations = [
    'BREMEN',
    'HAMBURG',
    'BERLIN',
    'MÜNCHEN',
    /*'KÖLN',*/
    'LISBON',
  ];

  final Map<String, Map<String, double>> _locationCoordinates = {
    'BREMEN': {'lat': 53.0793, 'lon': 8.8017},
    'HAMBURG': {'lat': 53.5511, 'lon': 9.9937},
    'BERLIN': {'lat': 52.5200, 'lon': 13.4050},
    'MÜNCHEN': {'lat': 48.1351, 'lon': 11.5820},
    'KÖLN': {'lat': 50.9375, 'lon': 6.9603},
    'LISBON': {'lat': 38.47, 'lon': -9.08},
  };

  final Map<String, String> stationIDs = Map<String, String>.from(
    AppConstants.stationIDs,
  );

  Weather? get currentWeather => _currentWeather;
  Forecast? get forecast => _forecast;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  Map<String, dynamic> get selectedLocation => _selectedLocation;
  List<Map<String, dynamic>> get closestLocations => _closestLocations;
  bool get locationAccessDenied => _locationAccessDenied;
  List<String> get locations => _locations;
  Map<String, Map<String, double>> get locationCoordinates =>
      _locationCoordinates;

  void setSelectedLocation(Map<String, dynamic> location) {
    _selectedLocation = location;
    _locationService.saveLocationToStorage(location);
    notifyListeners();
  }

  Future<void> getClosestLocation() async {
    final savedLocation = await _locationService.getLocationFromStorage();

    Map<String, dynamic> closest;
    double fallbackLat;
    double fallbackLon;

    try {
      final geo.Position userPosition = await _locationService
          .getCurrentLocation();

      final List<Map<String, dynamic>> closestList = await _locationService
          .findClosestLocation(userPosition.latitude, userPosition.longitude);
      //print(closestList);

      if (savedLocation != null) {
        closest = savedLocation;
        fallbackLat = savedLocation["lat"];
        fallbackLon = savedLocation["lon"];
      } else {
        closest = closestList.first;
        fallbackLat = userPosition.latitude;
        fallbackLon = userPosition.longitude;
      }

      print(
        'User position: ${userPosition.latitude}, ${userPosition.longitude}',
      );

      _locations.insert(0, closest['name']);
      stationIDs[closest['name']] = closest['id'];
      _closestLocations = closestList;
      _locationAccessDenied = false;
      setSelectedLocation(closest);

      loadWeather(
        closest['id'],
        closest['name'],
        fallbackStations: closestList.sublist(1),
        fallbackLat: fallbackLat,
        fallbackLon: fallbackLon,
      );
    } catch (e) {
      print('Error getting location: $e');
      // mark that location access was denied / failed so UI can prompt
      _locationAccessDenied = true;
      if (savedLocation != null) {
        setSelectedLocation(savedLocation);
        loadWeather(
          savedLocation["id"],
          savedLocation["name"],
          fallbackLat: savedLocation["lat"],
          fallbackLon: savedLocation["lon"],
        );
      } else {
        setSelectedLocation({"name": "BREMEN", "id": "10224"});
        loadWeather(
          stationIDs['BREMEN']!,
          'BREMEN',
          fallbackLat: _locationCoordinates['BREMEN']!['lat'],
          fallbackLon: _locationCoordinates['BREMEN']!['lon'],
        );
      }
    } finally {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> loadWeather(
    String stationId,
    String locationName, {
    List<Map<String, dynamic>>? fallbackStations,
    double? fallbackLat,
    double? fallbackLon,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedLocation = {
      "name": locationName,
      "id": stationId,
      "lat": fallbackLat,
      "lon": fallbackLon,
    };
    notifyListeners();

    Weather? weather;
    Forecast? forecast;

    try {
      weather = await _weatherService.getCurrentDWDWeatherByStationID(
        stationId,
        locationName: locationName,
        fallbackStations: fallbackStations,
        fallbackLat: fallbackLat,
        fallbackLon: fallbackLon,
      );

      if (weather.stationName != _selectedLocation["name"]) {
        final oldLocation = _selectedLocation["name"];
        _locations.remove(oldLocation);
        if (!_locations.contains(weather.stationName)) {
          _locations.insert(0, weather.stationName);
        }
        _selectedLocation = {
          "name": weather.stationName,
          "id": weather.stationId,
        };
        stationIDs[weather.stationName] = weather.stationId;
        stationId = weather.stationId;
      }

      forecast = await _weatherService.getForecastDWDWeatherByStationID(
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

    return {'weather': weather, 'forecast': forecast};
  }
}
