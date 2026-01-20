import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/outfit.dart';

class OutfitStorageService {
  static const String _outfitPrefix = 'outfit_';

  /// Generate a storage key from a date
  String _dateToKey(DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0]; // Format: YYYY-MM-DD
    return '$_outfitPrefix$dateStr';
  }

  /// Save an outfit for a specific date
  Future<bool> saveOutfitForDate(DateTime date, Outfit outfit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _dateToKey(date);
      final outfitJson = jsonEncode(outfit.toJson());
      return await prefs.setString(key, outfitJson);
    } catch (e) {
      print('Error saving outfit for date: $e');
      return false;
    }
  }

  /// Get a saved outfit for a specific date
  Future<Outfit?> getOutfitForDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _dateToKey(date);
      final outfitJson = prefs.getString(key);

      if (outfitJson == null) {
        return null;
      }

      final Map<String, dynamic> json = jsonDecode(outfitJson);
      return _outfitFromJson(json);
    } catch (e) {
      print('Error loading outfit for date: $e');
      return null;
    }
  }

  /// Delete a saved outfit for a specific date
  Future<bool> deleteOutfitForDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _dateToKey(date);
      return await prefs.remove(key);
    } catch (e) {
      print('Error deleting outfit for date: $e');
      return false;
    }
  }

  /// Clear all saved outfits
  Future<bool> clearAllOutfits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final outfitKeys = keys.where((k) => k.startsWith(_outfitPrefix)).toList();

      for (final key in outfitKeys) {
        await prefs.remove(key);
      }
      return true;
    } catch (e) {
      print('Error clearing all outfits: $e');
      return false;
    }
  }

  /// Parse outfit from JSON
  Outfit _outfitFromJson(Map<String, dynamic> json) {
    return Outfit(
      shirt: json['shirt'] != null
          ? _clothingItemFromJson(json['shirt'] as Map<String, dynamic>)
          : null,
      pullover: json['pullover'] != null
          ? _clothingItemFromJson(json['pullover'] as Map<String, dynamic>)
          : null,
      bottom: json['bottom'] != null
          ? _clothingItemFromJson(json['bottom'] as Map<String, dynamic>)
          : null,
      outerwear: json['outerwear'] != null
          ? _clothingItemFromJson(json['outerwear'] as Map<String, dynamic>)
          : null,
      shoes: json['shoes'] != null
          ? _clothingItemFromJson(json['shoes'] as Map<String, dynamic>)
          : null,
      accessories: json['accessories'] != null
          ? (json['accessories'] as List<dynamic>)
              .map((a) => _clothingItemFromJson(a as Map<String, dynamic>))
              .toList()
          : [],
      score: (json['score'] as num).toDouble(),
      baseScore: (json['base_score'] as num).toDouble(),
      styleScore: (json['style_score'] as num).toDouble(),
      colorScore: (json['color_score'] as num).toDouble(),
      palette: _colorPaletteFromJson(json['palette'] as Map<String, dynamic>),
    );
  }

  ClothingItem _clothingItemFromJson(Map<String, dynamic> json) {
    return ClothingItem.fromJson(json);
  }

  ColorPalette _colorPaletteFromJson(Map<String, dynamic> json) {
    return ColorPalette(
      dominant: Color(json['dominant'] as int),
      accents: (json['accents'] as List<dynamic>)
          .map((c) => Color(c as int))
          .toList(),
      neutrals: (json['neutrals'] as List<dynamic>)
          .map((c) => Color(c as int))
          .toList(),
    );
  }
}
