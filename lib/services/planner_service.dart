import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlannerService {
  static const String _keyDayActivities = 'day_activities';
  static const String _keyWeeklyActivities = 'weekly_activities';

  /// Save activities for a specific day
  Future<bool> saveDayActivities(DateTime date, List<String> activities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      //final allData = await getAllDayActivities();

      String? jsonString = prefs.getString(_keyDayActivities);
      print('📖 Reading from SharedPreferences: $jsonString'); // Debug

      if (jsonString == null || jsonString.isEmpty) {
        print('📖 No data found in SharedPreferences');
        jsonString = '{}'; // Debug
      }

      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      final Map<String, List<String>> allData = {};

      decoded.forEach((key, value) {
        if (value is List) {
          allData[key] = List<String>.from(value);
        }
      });

      // Use date string as key (YYYY-MM-DD format)
      final dateKey = _dateToString(date);
      allData[dateKey] = activities;

      jsonString = jsonEncode(allData);
      print('💾 Saving to SharedPreferences: $jsonString'); // Debug
      final result = await prefs.setString(_keyDayActivities, jsonString);
      print('💾 SharedPreferences save result: $result'); // Debug
      return result;
    } catch (e) {
      print('Error saving day activities: $e');
      return false;
    }
  }

  Future<bool> saveWeeklyDayActivities(
    DateTime date,
    List<String> activities,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allData = await getAllWeeklyDayActivities();

      // Use date string as key (YYYY-MM-DD format)
      final dateKey = DateFormat('EEEE').format(date);
      allData[dateKey] = activities;

      final jsonString = jsonEncode(allData);
      print('💾 Saving to SharedPreferences: $jsonString'); // Debug
      final result = await prefs.setString(_keyWeeklyActivities, jsonString);
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
      final allDayData = await getAllDayActivities();
      final dateKey = _dateToString(date);
      //final allWeekData = await getAllWeeklyDayActivities();
      //final dayName = DateFormat('EEEE').format(date);

      List<String> activities = [];
      for (var activity in allDayData[dateKey] ?? []) {
        activities.add(activity);
      }
      //activities.addAll(allDayData[dateKey] ?? []);
      //activities.addAll(allWeekData[dayName] ?? []);

      return activities;
    } catch (e) {
      print('Error getting day activities: $e');
      return [];
    }
  }

  /// Get activities for a specific day
  Future<List<String>> getMergedDayActivities(DateTime date) async {
    try {
      final allDayData = await getAllDayActivities();
      final dateKey = _dateToString(date);
      final allWeekData = await getAllWeeklyDayActivities();
      final dayName = DateFormat('EEEE').format(date);

      List<String> activities = [];
      List<String> excludedActivities = [];
      for (var activity in allDayData[dateKey] ?? []) {
        if (!activity.startsWith('!R:')) {
          activities.add(activity);
        } else {
          excludedActivities.add(activity.substring(1));
        }
      }
      for (var activity in allWeekData[dayName] ?? []) {
        if (!activities.contains(activity) &&
            !excludedActivities.contains(activity)) {
          activities.add(activity);
        }
      }

      return activities;
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

  Future<Map<String, List<String>>> getAllWeeklyDayActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyWeeklyActivities);
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
  Future<bool> addActivityToDay(
    DateTime date,
    String activity,
    String recurrence,
  ) async {
    try {
      final dayActivities = await getDayActivities(date);
      final allWeeklyActivities = await getAllWeeklyDayActivities();
      final dayName = DateFormat('EEEE').format(date);
      final weeklyActivities = allWeeklyActivities[dayName] ?? [];
      if (recurrence == 'once' &&
          !dayActivities.contains(activity) &&
          (!weeklyActivities.contains('R:$activity') ||
              dayActivities.contains('!R:$activity'))) {
        dayActivities.add(activity);
        return await saveDayActivities(date, dayActivities);
      } else if (recurrence == 'weekly') {
        if (!weeklyActivities.contains('R:$activity')) {
          weeklyActivities.add('R:${activity}');
          await saveWeeklyDayActivities(date, weeklyActivities);
        }
        await removeActivityFromDay(date, '!R:$activity', true);
      }
      return true;
    } catch (e) {
      print('Error adding activity to day: $e');
      return false;
    }
  }

  /// Remove a single activity from a day
  Future<bool> removeActivityFromDay(
    DateTime date,
    String activity,
    bool once,
  ) async {
    try {
      final dayActivities = await getDayActivities(date);

      if (activity.startsWith('R:')) {
        if (once) {
          addActivityToDay(date, '!$activity', 'once');
        } else {
          final allWeeklyActivities = await getAllWeeklyDayActivities();
          final dayName = DateFormat('EEEE').format(date);
          final weeklyActivities = allWeeklyActivities[dayName] ?? [];
          weeklyActivities.remove(activity);
          await saveWeeklyDayActivities(date, weeklyActivities);
        }
      } else {
        dayActivities.remove(activity);
        await saveDayActivities(date, dayActivities);
      }

      return true;
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
