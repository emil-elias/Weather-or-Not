import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PlannerService {
  static const String _keyDayActivities = 'day_activities';

  /// Save activities for a specific day
  Future<bool> saveDayActivities(DateTime date, List<String> activities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allData = await getAllDayActivities();

      // Use date string as key (YYYY-MM-DD format)
      final dateKey = _dateToString(date);
      allData[dateKey] = activities;

      final jsonString = jsonEncode(allData);
      print('💾 Saving to SharedPreferences: $jsonString'); // Debug
      final result = await prefs.setString(_keyDayActivities, jsonString);
      print('💾 SharedPreferences save result: $result'); // Debug
      return result;
    } catch (e) {
      print('Error saving day activities: $e');
      return false;
    }
  }

  /// Get activities for a specific day
  Future<List<String>> getDayActivities(DateTime date) async {
    try {
      final allData = await getAllDayActivities();
      final dateKey = _dateToString(date);
      return allData[dateKey] ?? [];
    } catch (e) {
      print('Error getting day activities: $e');
      return [];
    }
  }

  /// Get all day activities as a map
  Future<Map<String, List<String>>> getAllDayActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyDayActivities);
      print('📖 Reading from SharedPreferences: $jsonString'); // Debug

      if (jsonString == null || jsonString.isEmpty) {
        print('📖 No data found in SharedPreferences'); // Debug
        return {};
      }

      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      final Map<String, List<String>> result = {};

      decoded.forEach((key, value) {
        if (value is List) {
          result[key] = List<String>.from(value);
        }
      });

      print('📖 Decoded activities: $result'); // Debug
      return result;
    } catch (e) {
      print('Error getting all day activities: $e');
      return {};
    }
  }

  /// Delete activities for a specific day
  Future<bool> deleteDayActivities(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allData = await getAllDayActivities();

      final dateKey = _dateToString(date);
      allData.remove(dateKey);

      final jsonString = jsonEncode(allData);
      return await prefs.setString(_keyDayActivities, jsonString);
    } catch (e) {
      print('Error deleting day activities: $e');
      return false;
    }
  }

  /// Add a single activity to a day
  Future<bool> addActivityToDay(DateTime date, String activity) async {
    try {
      final activities = await getDayActivities(date);
      if (!activities.contains(activity)) {
        activities.add(activity);
        return await saveDayActivities(date, activities);
      }
      return true;
    } catch (e) {
      print('Error adding activity to day: $e');
      return false;
    }
  }

  /// Remove a single activity from a day
  Future<bool> removeActivityFromDay(DateTime date, String activity) async {
    try {
      final activities = await getDayActivities(date);
      activities.remove(activity);
      return await saveDayActivities(date, activities);
    } catch (e) {
      print('Error removing activity from day: $e');
      return false;
    }
  }

  /// Convert DateTime to string key (YYYY-MM-DD)
  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Convert string key to DateTime
  DateTime _stringToDate(String dateString) {
    final parts = dateString.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Clear all saved day activities
  Future<bool> clearAllDayActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_keyDayActivities);
    } catch (e) {
      print('Error clearing all day activities: $e');
      return false;
    }
  }
}
