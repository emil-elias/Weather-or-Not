// outfit_engine.dart
// High-level outfit recommendation engine

import 'dart:math';
import 'dart:ui';
import 'package:weatherornot/models/outfit.dart';


class OutfitEngine {
  final List<ClothingItem> wardrobe;

  OutfitEngine(this.wardrobe);

  /// Generate an outfit based on weather, activity and optional constraints.
  Outfit generate({
    required double temperature,
    required String activity,
  }) {
    print('OutfitEngine: Starting generation with temp=$temperature, activity=$activity');
    print('OutfitEngine: Total wardrobe items: ${wardrobe.length}');

    // We now score all wardrobe items (no strict pre-filtering) so the engine can
    // always provide the best possible full outfit from what's available.
    final scored = _scoreCandidates(wardrobe, temperature, activity);
    print('OutfitEngine: Scored items: ${scored.length}');

    final outfit = _buildOutfit(scored, temperature, activity);
    print('OutfitEngine: Generated outfit - shirt: ${outfit.shirt?.subtype}, pullover: ${outfit.pullover?.subtype}, bottom: ${outfit.bottom?.subtype}, shoes: ${outfit.shoes?.subtype}, outerwear: ${outfit.outerwear?.subtype}');

    return outfit;
  }

  // Kept for reference / future use, currently not used in the strict sense.
  List<ClothingItem> _filterByBasicConstraints(double temp, String activity) {
    print('Filter: (unused) Checking ${wardrobe.length} items for temp=$temp, activity=$activity');

    return wardrobe.where((item) {
      final c = item.usageConstraints;

      // Report but do not strictly exclude here (we score instead)
      final withinTemp = temp >= c.weatherMinTemp && temp <= c.weatherMaxTemp;
      final unsuitable = c.unsuitableFor.isNotEmpty && c.unsuitableFor.contains(activity);
      final notOptimal = c.optimalActivities.isNotEmpty && !c.optimalActivities.contains(activity);

      print('FilterCheck: ${item.subtype} (cat: ${item.category}) - withinTemp=$withinTemp, unsuitable=$unsuitable, notOptimal=$notOptimal');

      return withinTemp && !unsuitable && !notOptimal;
    }).toList();
  }

  /// Score all provided items. Values are heuristics: higher = better.
  Map<ClothingItem, double> _scoreCandidates(List<ClothingItem> items, double temp, String activity) {
    final scores = <ClothingItem, double>{};

    for (final item in items) {
      double score = 0;
      final c = item.usageConstraints;

      // 1) Temperature match: measure distance to the allowed [min,max] range.
      //    If inside range -> large bonus. If outside -> deduct relative to distance.
      double tempDiff;
      if (temp < c.weatherMinTemp) tempDiff = c.weatherMinTemp - temp;
      else if (temp > c.weatherMaxTemp) tempDiff = temp - c.weatherMaxTemp;
      else tempDiff = 0;

      if (tempDiff == 0) {
        score += 30; // inside preferred range
      } else {
        score += max(0, 30 - tempDiff * 2); // closer outside items still get some points
      }

      // 2) Activity match: strong bonus if item lists the activity in optimalActivities.
      if (c.optimalActivities.contains(activity)) {
        score += 30;
      } else if (c.unsuitableFor.contains(activity)) {
        score -= 35; // strong penalty if explicitly unsuitable
      } else if (c.optimalActivities.isEmpty) {
        score += 5; // small default boost when no optimalActivities defined
      }

      // 3) Warmth suitability: prefer items whose warmthLevel matches the ideal for temp.
      final double idealWarmth = ((20.0 - temp) / 3.0).clamp(1.0, 10.0);
      final double warmthDiff = (item.attributes.warmthLevel - idealWarmth).abs();
      score += max(0, 10 - warmthDiff * 2.0);

      // 4) Sports-specific properties
      if (activity == "sports") {
        score += item.attributes.breathability * 2;
        score += item.attributes.stretch * 2;
      }

      // 5) Small tie-breakers (optional): use formality or metadata if available (not implemented here)
      // Logging to help tuning
      print('ScoreCalc: ${item.subtype} (${item.category}) => score=${score.toStringAsFixed(2)} (tempDiff=${tempDiff.toStringAsFixed(1)}, idealWarmth=${idealWarmth.toStringAsFixed(2)}, warmth=${item.attributes.warmthLevel})');
      scores[item] = score;
    }

    return scores;
  }

  Outfit _buildOutfit(Map<ClothingItem, double> scores, double temp, String activity) {
    ClothingItem? shirt;
    ClothingItem? pullover;
    ClothingItem? bottom;
    ClothingItem? shoes;
    ClothingItem? outer;
    List<ClothingItem> accessories = [];

    double _computeFallbackScoreForItem(ClothingItem item) {
      // Keep a fallback heuristic similar to _scoreCandidates (for consistency)
      final c = item.usageConstraints;
      double tempDiff;
      if (temp < c.weatherMinTemp) tempDiff = c.weatherMinTemp - temp;
      else if (temp > c.weatherMaxTemp) tempDiff = temp - c.weatherMaxTemp;
      else tempDiff = 0;

      double s = (tempDiff == 0) ? 30 : max(0, 30 - tempDiff * 2);
      final double idealWarmth = ((20.0 - temp) / 3.0).clamp(1.0, 10.0);
      final double warmthDiff = (item.attributes.warmthLevel - idealWarmth).abs();
      s += max(0, 10 - warmthDiff * 2.0);

      if (c.optimalActivities.contains(activity)) s += 30;
      if (c.unsuitableFor.contains(activity)) s -= 35;

      if (activity == "sports") {
        s += item.attributes.breathability * 2;
        s += item.attributes.stretch * 2;
      }

      return s;
    }

    ClothingItem? _pickByCategory(List<String> categoryVariations) {
      // First, prefer items that match the requested category among the scored items
      final filtered = scores.entries
          .where((e) {
            final catLower = e.key.category.toLowerCase();
            return categoryVariations.any((cat) => catLower.contains(cat.toLowerCase()));
          })
          .toList();

      if (filtered.isNotEmpty) {
        filtered.sort((a, b) => b.value.compareTo(a.value));
        print("Pick: Selected from scored candidates $categoryVariations: ${filtered.first.key.subtype} (${filtered.first.key.category}) with score ${filtered.first.value.toStringAsFixed(2)}");
        return filtered.first.key;
      }

      // If no scored candidate exists for that category (edge case), fallback to scoring wardrobe items manually
      final fallbackCandidates = wardrobe.where((item) {
        final catLower = item.category.toLowerCase();
        return categoryVariations.any((cat) => catLower.contains(cat.toLowerCase()));
      }).toList();

      if (fallbackCandidates.isEmpty) {
        print('Pick: No items found at all for categories=$categoryVariations');
        return null;
      }

      final scoredFallback = fallbackCandidates
          .map((item) => MapEntry(item, _computeFallbackScoreForItem(item)))
          .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      print("Pick: Fallback selected ${scoredFallback.first.key.subtype} (${scoredFallback.first.key.category}) with fallback score ${scoredFallback.first.value.toStringAsFixed(2)}");
      return scoredFallback.first.key;
    }

    // Pick items based on actual category names
    shirt = _pickByCategory(['t-shirts', 'shirts & blouses', 'knitwear', 'sportswear', 'tops']);
    pullover = _pickByCategory(['sweat', 'hoodie', 'sweater', 'pullover']);
    bottom = _pickByCategory(['bottom', 'trousers', 'pant', 'shorts', 'skirts', 'jean', 'sports_bottoms']);
    shoes = _pickByCategory(['casual_shoes', 'boots', 'dress_shoes', 'sport_shoes']);
    outer = _pickByCategory(['outerwear', 'jacket', 'coat', 'technical_outerwear']);

    // Accessories: pick up to 2 highest-score from scores first, then fallback to wardrobe
    final accessoryEntries = scores.entries
        .where((e) => e.key.category.toLowerCase().contains("access"))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    accessories = accessoryEntries.take(2).map((e) => e.key).toList();

    if (accessories.length < 2) {
      final fallbackAccessories = wardrobe.where((item) => item.category.toLowerCase().contains("access")).toList()
        ..sort((a, b) => _computeFallbackScoreForItem(b).compareTo(_computeFallbackScoreForItem(a)));
      for (final a in fallbackAccessories) {
        if (!accessories.contains(a)) accessories.add(a);
        if (accessories.length >= 2) break;
      }
    }

    // Compute average score from the chosen items (use scored values when available, else fallback heuristic)
    final chosenItems = [if (shirt != null) shirt!, if (pullover != null) pullover!, if (bottom != null) bottom!, if (shoes != null) shoes!, if (outer != null) outer!, ...accessories];
    double total = 0;
    for (final item in chosenItems) {
      if (scores.containsKey(item)) total += scores[item]!;
      else total += _computeFallbackScoreForItem(item);
    }
    final scoreSum = chosenItems.isNotEmpty ? total / chosenItems.length : 0;

    // Palette - use shirt first, then pullover for color
    final dominantColor = (shirt != null && shirt.extractedColors.isNotEmpty)
        ? shirt.extractedColors.first
        : (pullover != null && pullover.extractedColors.isNotEmpty)
            ? pullover.extractedColors.first
            : const Color(0xff000000);

    final accentColor = (bottom != null && bottom.extractedColors.isNotEmpty)
        ? bottom.extractedColors.first
        : null;

    final palette = ColorPalette(
      dominant: dominantColor,
      accents: [
        if (accentColor != null) accentColor,
      ],
      neutrals: [const Color(0xfff0f0f0)],
    );

    return Outfit(
      shirt: shirt,
      pullover: pullover,
      bottom: bottom,
      outerwear: outer,
      shoes: shoes,
      accessories: accessories,
      score: scoreSum.toDouble(),
      palette: palette,
    );
  }
}