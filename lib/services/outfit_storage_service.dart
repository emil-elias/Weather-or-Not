import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/outfit.dart';
import 'wardrobe_service.dart';
import '../models/wardrobe_item.dart';

class OutfitStorageService {
  static const String _outfitPrefix = 'outfit_';
  final WardrobeService _wardrobeService = WardrobeService();

  /// Generate a storage key from a date
  String _dateToKey(DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0]; // Format: YYYY-MM-DD
    return '$_outfitPrefix$dateStr';
  }

  /// Save an outfit for a specific date
  Future<bool> saveOutfitForDate(DateTime date, Outfit outfit, String? stationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _dateToKey(date);
      if (stationId != null) {
        outfit.stationID = stationId;
      }
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

      final wardrobeItems = await _wardrobeService.getWardrobeItems();

      Map<String, dynamic> _subtypesAttributesData = {};

      try {
        final String jsonString = await rootBundle.loadString(
          'assets/subtypes_attributes.json',
        );
        final jsonData = jsonDecode(jsonString);

        _subtypesAttributesData = jsonData;
      } catch (e) {
        print('Error loading subtypes attributes: $e');
      }

      if (outfitJson == null) {
        return null;
      }

      final Map<String, dynamic> json = jsonDecode(outfitJson);
      return _outfitFromJson(json, wardrobeItems, _subtypesAttributesData);
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
      final outfitKeys = keys
          .where((k) => k.startsWith(_outfitPrefix))
          .toList();

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
  Outfit _outfitFromJson(
    Map<String, dynamic> json,
    List<WardrobeItem> wardrobeItems,
    Map<String, dynamic> _subtypesAttributesData,
  ) {
    return Outfit(
      shirt: json['shirt'] != null
          ? _clothingItemFromJson(
              json['shirt'] as Map<String, dynamic>,
              wardrobeItems,
              _subtypesAttributesData,
            )
          : null,
      pullover: json['pullover'] != null
          ? _clothingItemFromJson(
              json['pullover'] as Map<String, dynamic>,
              wardrobeItems,
              _subtypesAttributesData,
            )
          : null,
      bottom: json['bottom'] != null
          ? _clothingItemFromJson(
              json['bottom'] as Map<String, dynamic>,
              wardrobeItems,
              _subtypesAttributesData,
            )
          : null,
      outerwear: json['outerwear'] != null
          ? _clothingItemFromJson(
              json['outerwear'] as Map<String, dynamic>,
              wardrobeItems,
              _subtypesAttributesData,
            )
          : null,
      shoes: json['shoes'] != null
          ? _clothingItemFromJson(
              json['shoes'] as Map<String, dynamic>,
              wardrobeItems,
              _subtypesAttributesData,
            )
          : null,
      accessories: json['accessories'] != null
          ? (json['accessories'] as List<dynamic>)
                .map(
                  (a) => _clothingItemFromJson(
                    a as Map<String, dynamic>,
                    wardrobeItems,
                    _subtypesAttributesData,
                  ),
                )
                .toList()
          : [],
      stationID: json["stationId"],
      score: (json['score'] as num).toDouble(),
      baseScore: (json['base_score'] as num).toDouble(),
      styleScore: (json['style_score'] as num).toDouble(),
      colorScore: (json['color_score'] as num).toDouble(),
      palette: _colorPaletteFromJson(json['palette'] as Map<String, dynamic>),
    );
  }

  ClothingItem _clothingItemFromJson(
    Map<String, dynamic> json,
    List<WardrobeItem>? wardrobeItems,
    Map<String, dynamic>? _subtypesAttributesData,
  ) {
    final correspondingWardrobeItem = wardrobeItems?.firstWhere(
      (item) => item.id == json['id'],
    );

    if (correspondingWardrobeItem != null && _subtypesAttributesData != null) {
      return correspondingWardrobeItem.toClothingItem(_subtypesAttributesData);
    }

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
