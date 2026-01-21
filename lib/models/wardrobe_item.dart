import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:weatherornot/models/outfit.dart';

class WardrobeItem {
  final String id;
  final String name;
  final String description;
  final String category;
  final String subcategory;
  final String color;
  final String formalityLevel;
  final List<String> tags;
  final String? imagePath;
  final Map<String, dynamic>? attributes; // custom attributes overrides
  final Map<String, dynamic>? usageConstraints; // custom usage constraints
  final DateTime createdAt;
  final bool isFavorite;
  final bool isInWash;

  WardrobeItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.subcategory,
    required this.color,
    required this.formalityLevel,
    required this.tags,
    this.imagePath,
    this.attributes,
    this.usageConstraints,
    required this.createdAt,
    this.isFavorite = false,
    this.isInWash = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'color': color,
      'formalityLevel': formalityLevel,
      'tags': tags,
      'imagePath': imagePath,
      'attributes': attributes,
      'usageConstraints': usageConstraints,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
      'isInWash': isInWash,
    };
  }

  int _getWarmthLevel(String formalityLevel) {
    switch (formalityLevel.toLowerCase()) {
      case 'casual':
        return 5;
      case 'business':
        return 6;
      case 'formal':
        return 7;
      default:
        return 5;
    }
  }

  ClothingItem toClothingItem(Map<String,dynamic> _subtypesAttributesData) {
    final item = this;
    final rawCategory = (item.category ?? '').toString().toLowerCase();
    final rawSubtype = (item.subcategory ?? '').toString().toLowerCase();
    final name = item.name ?? '';
    final imagePath = item.imagePath;

    // Try to look up attributes from JSON using the subcategory as key
    Map<String, dynamic>? foundSubtypeData =
        _subtypesAttributesData[rawSubtype];

    // If not found, try normalizing spaces/hyphens to underscores
    if (foundSubtypeData == null) {
      final normalizedSubtype = rawSubtype
          .replaceAll(' ', '_')
          .replaceAll('-', '_');
      foundSubtypeData = _subtypesAttributesData[normalizedSubtype];

      if (foundSubtypeData != null) {
        print(
          'Found subtype via normalization: "$rawSubtype" -> "$normalizedSubtype"',
        );
      }
    }

    // If still not found, log a warning
    if (foundSubtypeData == null) {
      print(
        'Warning: Subtype "$rawSubtype" not found in subtypes_attributes.json (tried normalized: ${rawSubtype.replaceAll(' ', '_').replaceAll('-', '_')}), using defaults',
      );
    } else {
      print('Loaded attributes for "$rawSubtype" from JSON');
    }

    // Prefer stored attributes/usage constraints from the WardrobeItem, but merge them over JSON defaults
    final Map<String, dynamic> storedAttributes =
        (item.attributes as Map<String, dynamic>?)?.cast<String, dynamic>() ??
        {};
    final Map<String, dynamic> storedUsage =
        (item.usageConstraints as Map<String, dynamic>?)
            ?.cast<String, dynamic>() ??
        {};

    final Map<String, dynamic> jsonAttributes =
        (foundSubtypeData != null && foundSubtypeData['attributes'] is Map)
        ? Map<String, dynamic>.from(foundSubtypeData['attributes'] as Map)
        : {};
    final Map<String, dynamic> jsonUsage =
        (foundSubtypeData != null &&
            foundSubtypeData['usage_constraints'] is Map)
        ? Map<String, dynamic>.from(
            foundSubtypeData['usage_constraints'] as Map,
          )
        : {};

    // merge JSON defaults with stored overrides (stored wins)
    final attributesData = {...jsonAttributes, ...storedAttributes};
    final usageConstraintsData = {...jsonUsage, ...storedUsage};

    if (storedAttributes.isNotEmpty) {
      final overridden = storedAttributes.keys.join(', ');
      print(
        'Converting item ${item.id}: merging stored attributes over JSON defaults (overrides: $overridden)',
      );
    } else if (jsonAttributes.isNotEmpty) {
      print('Converting item ${item.id}: using JSON attributes for subtype');
    }

    if (storedUsage.isNotEmpty) {
      final overridden = storedUsage.keys.join(', ');
      print(
        'Converting item ${item.id}: merging stored usage constraints over JSON defaults (overrides: $overridden)',
      );
    } else if (jsonUsage.isNotEmpty) {
      print(
        'Converting item ${item.id}: using JSON usage constraints for subtype',
      );
    }

    // Parse attributes with fallback defaults
    final materials = List<String>.from(attributesData['materials'] ?? []);
    final warmthLevel =
        attributesData['warmth_level'] ??
        _getWarmthLevel(item.formalityLevel ?? 'casual');
    final waterResistance = attributesData['water_resistance'] ?? 5;
    final windResistance = attributesData['wind_resistance'] ?? 5;
    final breathability = attributesData['breathability'] ?? 5;
    final stretch = attributesData['stretch'] ?? 5;
    final formality =
        attributesData['formality'] ?? (item.formalityLevel ?? 'casual');
    final styleTags = List<String>.from(
      attributesData['style_tags'] ?? (item.tags ?? []),
    );
    final fit = attributesData['fit'] ?? 'regular';

    // Parse usage constraints with fallback defaults
    final weatherMinTemp = usageConstraintsData['weather_min_temp'] ?? -40;
    final weatherMaxTemp = usageConstraintsData['weather_max_temp'] ?? 45;
    final optimalActivities = List<String>.from(
      usageConstraintsData['optimal_activities'] ?? ['daily', 'casual'],
    );
    final unsuitableFor = List<String>.from(
      usageConstraintsData['unsuitable_for'] ?? [],
    );

    // Build ClothingItem using data from JSON
    return ClothingItem(
      id: item.id,
      category: rawCategory,
      subtype: rawSubtype,
      attributes: ClothingAttributes(
        materials: materials,
        warmthLevel: warmthLevel,
        waterResistance: waterResistance,
        windResistance: windResistance,
        breathability: breathability,
        stretch: stretch,
        formality: formality,
        styleTags: styleTags,
        fit: fit,
      ),
      usageConstraints: UsageConstraints(
        weatherMinTemp: weatherMinTemp,
        weatherMaxTemp: weatherMaxTemp,
        optimalActivities: optimalActivities,
        unsuitableFor: unsuitableFor,
      ),
      extractedColors: [],
      metadata: {'imagePath': imagePath, 'name': name},
    );
  }

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    return WardrobeItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      color: json['color'] as String,
      formalityLevel: json['formalityLevel'] as String,
      tags: List<String>.from(json['tags'] as List),
      imagePath: json['imagePath'] as String?,
      attributes: (json['attributes'] as Map<String, dynamic>?)
          ?.cast<String, dynamic>(),
      usageConstraints: (json['usageConstraints'] as Map<String, dynamic>?)
          ?.cast<String, dynamic>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
      isInWash: json['isInWash'] as bool? ?? false,
    );
  }
}
