import 'dart:ui';

/// Represents a clothing item (e.g. tshirt, jeans, hoodie)
class ClothingItem {
  final String id;
  final String category;      // e.g. "top"
  final String subtype;       // e.g. "tshirt"
  final ClothingAttributes attributes;
  final UsageConstraints usageConstraints;
  final List<Color> extractedColors; // From color picker (dominant, accents)
  final Map<String, dynamic>? metadata;

  ClothingItem({
    required this.id,
    required this.category,
    required this.subtype,
    required this.attributes,
    required this.usageConstraints,
    required this.extractedColors,
    this.metadata,
  });

  factory ClothingItem.fromJson(Map<String, dynamic> json) {
    return ClothingItem(
      id: json['id'],
      category: json['category'],
      subtype: json['subtype'],
      attributes: ClothingAttributes.fromJson(json['attributes']),
      usageConstraints: UsageConstraints.fromJson(json['usage_constraints']),
      extractedColors: (json['extracted_colors'] as List<dynamic>)
          .map((c) => Color(c))
          .toList(),
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "category": category,
        "subtype": subtype,
        "attributes": attributes.toJson(),
        "usage_constraints": usageConstraints.toJson(),
        "extracted_colors": extractedColors.map((c) => c.value).toList(),
        "metadata": metadata,
      };
}

/// Attributes describing the physical & stylistic properties of a clothing item
class ClothingAttributes {
  final List<String> materials;
  final int warmthLevel;
  final int waterResistance;
  final int windResistance;
  final int breathability;
  final int stretch;
  final String formality;
  final List<String> styleTags;
  final String fit;

  ClothingAttributes({
    required this.materials,
    required this.warmthLevel,
    required this.waterResistance,
    required this.windResistance,
    required this.breathability,
    required this.stretch,
    required this.formality,
    required this.styleTags,
    required this.fit,
  });

  factory ClothingAttributes.fromJson(Map<String, dynamic> json) {
    return ClothingAttributes(
      materials: List<String>.from(json['materials']),
      warmthLevel: json['warmth_level'],
      waterResistance: json['water_resistance'],
      windResistance: json['wind_resistance'],
      breathability: json['breathability'],
      stretch: json['stretch'],
      formality: json['formality'],
      styleTags: List<String>.from(json['style_tags']),
      fit: json['fit'],
    );
  }

  Map<String, dynamic> toJson() => {
        "materials": materials,
        "warmth_level": warmthLevel,
        "water_resistance": waterResistance,
        "wind_resistance": windResistance,
        "breathability": breathability,
        "stretch": stretch,
        "formality": formality,
        "style_tags": styleTags,
        "fit": fit,
      };
}

/// Constraints for weather, activities, and suitability
class UsageConstraints {
  final int weatherMinTemp;
  final int weatherMaxTemp;
  final List<String> optimalActivities;
  final List<String> unsuitableFor;

  UsageConstraints({
    required this.weatherMinTemp,
    required this.weatherMaxTemp,
    required this.optimalActivities,
    required this.unsuitableFor,
  });

  factory UsageConstraints.fromJson(Map<String, dynamic> json) {
    return UsageConstraints(
      weatherMinTemp: json['weather_min_temp'],
      weatherMaxTemp: json['weather_max_temp'],
      optimalActivities: List<String>.from(json['optimal_activities']),
      unsuitableFor: List<String>.from(json['unsuitable_for']),
    );
  }

  Map<String, dynamic> toJson() => {
        "weather_min_temp": weatherMinTemp,
        "weather_max_temp": weatherMaxTemp,
        "optimal_activities": optimalActivities,
        "unsuitable_for": unsuitableFor,
      };
}

/// Represents a full outfit (shirt, pullover, bottom, shoes, outerwear, accessories…)
class Outfit {
  final ClothingItem? shirt;
  final ClothingItem? pullover;
  final ClothingItem? bottom;
  final ClothingItem? outerwear;
  final ClothingItem? shoes;
  final List<ClothingItem> accessories;
  String? stationID;

  final double score; // final composite score used for ranking
  final double baseScore; // average of item scores (pre style/color adjustment)
  final double styleScore; // 0..100 style consistency
  final double colorScore; // 0..100 color harmony
  final ColorPalette palette;

  Outfit({
    this.shirt,
    this.pullover,
    this.bottom,
    this.outerwear,
    this.shoes,
    this.accessories = const [],
    this.stationID,
    required this.score,
    required this.baseScore,
    required this.styleScore,
    required this.colorScore,
    required this.palette,
  });

  Map<String, dynamic> toJson() => {
        "shirt": shirt?.toJson(),
        "pullover": pullover?.toJson(),
        "bottom": bottom?.toJson(),
        "outerwear": outerwear?.toJson(),
        "shoes": shoes?.toJson(),
        "accessories": accessories.map((i) => i.toJson()).toList(),
        "score": score,
        "base_score": baseScore,
        "style_score": styleScore,
        "color_score": colorScore,
        "palette": palette.toJson(),
        "stationId": stationID
      };
}

/// Represents the color theme generated by the outfit
class ColorPalette {
  final Color dominant;
  final List<Color> accents;
  final List<Color> neutrals;

  ColorPalette({
    required this.dominant,
    required this.accents,
    required this.neutrals,
  });

  Map<String, dynamic> toJson() => {
        "dominant": dominant.value,
        "accents": accents.map((c) => c.value).toList(),
        "neutrals": neutrals.map((c) => c.value).toList(),
      };
}
