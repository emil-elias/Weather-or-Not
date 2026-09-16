import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, return an error
      throw Exception('Location services are disabled.');
    }

    // Check for location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, return an error
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, return an error
      throw Exception(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    // When we reach here, permissions are granted and we can get the location
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Radius of the Earth in kilometers
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in kilometers
  }

  Future<List<Map<String, dynamic>>> findClosestLocation(
    double userLatitude,
    double userLongitude,
  ) async {
    // Load the JSON file
    final String response = await rootBundle.loadString('assets/stations.json');
    final List<dynamic> locations = json.decode(response);

    Map<String, dynamic>? closestLocation;
    double shortestDistance = double.infinity;
    List<Map<String, dynamic>> closestLocations = [];

    for (var location in locations) {
      final double distance = calculateDistance(
        userLatitude,
        userLongitude,
        location['lat'],
        location['lon'],
      );

      if (distance < 25) {
        closestLocations.add(location);
        closestLocations.last['distance'] = distance;
      }

      if (distance < shortestDistance) {
        shortestDistance = distance;
        closestLocation = location;
      }
    }

    if (closestLocations.isEmpty && closestLocation != null) {
      closestLocations.add(closestLocation);
      closestLocations.last['distance'] = shortestDistance;
    }

    closestLocations.sort((a, b) => a['distance'].compareTo(b['distance']));

    return closestLocations;
  }

  Future<List<Map<String, dynamic>>> searchLocationsByName(
    String query,
  ) async {
    // Load the JSON file
    final String response = await rootBundle.loadString('assets/stations.json');
    final List<dynamic> locations = json.decode(response);

    // normalize umlauts/ß for better matching (e.g. München <-> Muenchen)
    String normalize(String s) {
      final lower = s.toLowerCase();
      return lower
          .replaceAll('ä', 'ae')
          .replaceAll('ö', 'oe')
          .replaceAll('ü', 'ue')
          .replaceAll('Ä'.toLowerCase(), 'ae')
          .replaceAll('Ö'.toLowerCase(), 'oe')
          .replaceAll('Ü'.toLowerCase(), 'ue')
          .replaceAll('ß', 'ss')
          .replaceAll("-", " ");
    }

    final normQuery = normalize(query);
    List<Map<String, dynamic>> matchingLocations = [];

    for (var location in locations) {
      final name = (location['name'] ?? '').toString().replaceAll("-", " ");
      if (normalize(name).contains(normQuery)) {
        matchingLocations.add(location);
      }
    }

    return matchingLocations;
  }

  Future<List<Map<String, dynamic>>> getClosestAirqualityStations(double lat, double lon) async {
    final String response = await rootBundle.loadString('assets/airquality_stations.json');
    final List<dynamic> locations = json.decode(response);

    Map<String, dynamic>? closestLocation;
    double shortestDistance = double.infinity;
    List<Map<String, dynamic>> closestLocations = [];

    for (var location in locations) {
      final double distance = calculateDistance(
        lat,
        lon,
        location[8],
        location[7],
      );

      if (distance < 25) {
        closestLocations.add(location);
        closestLocations.last['distance'] = distance;
      }

      if (distance < shortestDistance) {
        shortestDistance = distance;
        closestLocation = location;
      }
    }

    if (closestLocations.isEmpty && closestLocation != null) {
      closestLocations.add(closestLocation);
      closestLocations.last['distance'] = shortestDistance;
    }

    closestLocations.sort((a, b) => a['distance'].compareTo(b['distance']));

    return closestLocations;
  }

  Future<bool> saveLocationToStorage(Map<String,dynamic> location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = "selected_location";
      
      final locationJson = jsonEncode(location);
      return await prefs.setString(key, locationJson);
    } catch (e) {
      print('Error saving selected location: $e');
      return false;
    }
  }

  Future<Map<String,dynamic>?> getLocationFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = "selected_location";
      
      final locationJson = prefs.getString(key);
      if (locationJson != null) {
        final location = jsonDecode(locationJson);
        return location;
      } else {
        return null;
      }
        
    } catch (e) {
      print('Error getting selected location: $e');
      return null;
    }
  }
}
