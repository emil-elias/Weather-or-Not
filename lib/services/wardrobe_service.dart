import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wardrobe_item.dart';

class WardrobeService {
  static const String _wardrobeKey = 'wardrobe_items';

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
}
