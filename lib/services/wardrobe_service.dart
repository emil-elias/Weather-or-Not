import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wardrobe_item.dart';
import '../models/saved_outfit.dart';

class WardrobeService {
  static const String _wardrobeKey = 'wardrobe_items';
  static const String _savedOutfitsKey = 'saved_outfits';

  Future<List<WardrobeItem>> getWardrobeItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString(_wardrobeKey);

    if (itemsJson == null) {
      return [];
    }

    final List<dynamic> itemsList = jsonDecode(itemsJson);
    return itemsList
        .map((json) => WardrobeItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<bool> addWardrobeItem(WardrobeItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getWardrobeItems();
      items.add(item);

      final itemsJson = jsonEncode(items.map((e) => e.toJson()).toList());
      return await prefs.setString(_wardrobeKey, itemsJson);
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateWardrobeItem(WardrobeItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getWardrobeItems();
      final index = items.indexWhere((i) => i.id == item.id);

      if (index != -1) {
        items[index] = item;
        final itemsJson = jsonEncode(items.map((e) => e.toJson()).toList());
        return await prefs.setString(_wardrobeKey, itemsJson);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteWardrobeItem(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getWardrobeItems();
      items.removeWhere((item) => item.id == id);

      final itemsJson = jsonEncode(items.map((e) => e.toJson()).toList());
      return await prefs.setString(_wardrobeKey, itemsJson);
    } catch (e) {
      return false;
    }
  }

  Future<void> clearAllItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wardrobeKey);
  }

  // Saved Outfits methods
  Future<List<SavedOutfit>> getSavedOutfits() async {
    final prefs = await SharedPreferences.getInstance();
    final String? outfitsJson = prefs.getString(_savedOutfitsKey);

    if (outfitsJson == null) {
      return [];
    }

    final List<dynamic> outfitsList = jsonDecode(outfitsJson);
    return outfitsList
        .map((json) => SavedOutfit.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<bool> saveOutfit(SavedOutfit outfit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final outfits = await getSavedOutfits();
      outfits.add(outfit);

      final outfitsJson = jsonEncode(outfits.map((e) => e.toJson()).toList());
      return await prefs.setString(_savedOutfitsKey, outfitsJson);
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateSavedOutfit(SavedOutfit outfit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final outfits = await getSavedOutfits();
      final index = outfits.indexWhere((o) => o.id == outfit.id);

      if (index != -1) {
        outfits[index] = outfit;
        final outfitsJson = jsonEncode(outfits.map((e) => e.toJson()).toList());
        return await prefs.setString(_savedOutfitsKey, outfitsJson);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSavedOutfit(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final outfits = await getSavedOutfits();
      outfits.removeWhere((outfit) => outfit.id == id);

      final outfitsJson = jsonEncode(outfits.map((e) => e.toJson()).toList());
      return await prefs.setString(_savedOutfitsKey, outfitsJson);
    } catch (e) {
      return false;
    }
  }
}
