import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _transportationKey = 'preferred_transportation';
  static const String _coldThresholdKey = 'cold_threshold';
  static const String _warmThresholdKey = 'warm_threshold';

  /// Save preferred transportation mode
  Future<void> saveTransportation(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_transportationKey, mode);
  }

  /// Get preferred transportation mode
  Future<String> getTransportation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_transportationKey) ?? 'Bike';
  }

  /// Save cold threshold
  Future<void> saveColdThreshold(double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_coldThresholdKey, threshold);
  }

  /// Get cold threshold
  Future<double> getColdThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_coldThresholdKey) ?? 5.0;
  }

  /// Save warm threshold
  Future<void> saveWarmThreshold(double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_warmThresholdKey, threshold);
  }

  /// Get warm threshold
  Future<double> getWarmThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_warmThresholdKey) ?? 20.0;
  }

  /// Save all preferences at once
  Future<void> saveAllPreferences({
    required String transportation,
    required double coldThreshold,
    required double warmThreshold,
  }) async {
    await Future.wait([
      saveTransportation(transportation),
      saveColdThreshold(coldThreshold),
      saveWarmThreshold(warmThreshold),
    ]);
  }
}
