// outfit_engine.dart
// High-level outfit recommendation engine

import 'dart:math';
import 'dart:ui';
import 'package:weatherornot/models/outfit.dart';

class OutfitEngine {
  final List<ClothingItem> wardrobe;

  OutfitEngine(this.wardrobe);

  /// Generate an outfit based on weather, activities and optional constraints like rain probability.
  Outfit generate({
    required double temperature,
    required List<String> activities,
    double rainProbability = 0.0,
    double windSpeed = 0.0,
    String? weatherCondition,
    double? coldThreshold,
    double? warmThreshold,
  }) {
    // If caller didn't provide a rain probability but weather condition mentions rain, assume some rain
    double rp = rainProbability;
    if ((rp <= 0.0) &&
        (weatherCondition != null &&
            weatherCondition.toLowerCase().contains('rain'))) {
      rp = 0.8;
      print(
        'OutfitEngine: weatherCondition contains "rain", setting rainProbability=$rp',
      );
    }

    // Backwards-compatible single-outfit API: delegate to generateOutfits and return the top one
    final outfits = generateOutfits(
      temperature: temperature,
      activities: activities,
      rainProbability: rp,
      windSpeed: windSpeed,
      weatherCondition: weatherCondition,
      coldThreshold: coldThreshold,
      warmThreshold: warmThreshold,
      topNPerCategory: 3,
      maxOutfits: 1,
    );

    if (outfits.isNotEmpty) {
      final top = outfits.first;
      final itemNames = [
        top.shirt?.subtype ?? '-',
        top.pullover?.subtype ?? '-',
        top.bottom?.subtype ?? '-',
        top.outerwear?.subtype ?? '-',
        top.shoes?.subtype ?? '-',
      ].join(', ');
      print(
        'OutfitEngine.generate: selected top outfit score=${top.score.toStringAsFixed(2)} base=${top.baseScore.toStringAsFixed(2)} style=${top.styleScore.toStringAsFixed(1)} color=${top.colorScore.toStringAsFixed(1)} items=[$itemNames]',
      );
      return top;
    } else {
      final fallback = _buildOutfit(
        _scoreCandidates(
          wardrobe,
          temperature,
          activities,
          rp,
          windSpeed: windSpeed,
          coldThreshold: coldThreshold,
          warmThreshold: warmThreshold,
        ),
        temperature,
        activities,
        rp,
        windSpeed: windSpeed,
        coldThreshold: coldThreshold,
        warmThreshold: warmThreshold,
      );
      print(
        'OutfitEngine.generate: no multi-outfits generated, using fallback outfit score=${fallback.score.toStringAsFixed(2)}',
      );
      return fallback;
    }
  }

  // Kept for reference / future use, currently not used in the strict sense.
  List<ClothingItem> _filterByBasicConstraints(
    double temp,
    List<String> activities,
    double rainProbability,
  ) {
    print(
      'Filter: (unused) Checking ${wardrobe.length} items for temp=$temp, activities=$activities, rainProb=${rainProbability.toStringAsFixed(2)}',
    );

    return wardrobe.where((item) {
      final c = item.usageConstraints;

      // Report but do not strictly exclude here (we score instead)
      final withinTemp = temp >= c.weatherMinTemp && temp <= c.weatherMaxTemp;
      final unsuitable =
          c.unsuitableFor.isNotEmpty &&
          c.unsuitableFor.any((a) => activities.contains(a));
      final notOptimal =
          c.optimalActivities.isNotEmpty &&
          activities.every((act) => !c.optimalActivities.contains(act));

      print(
        'FilterCheck: ${item.subtype} (cat: ${item.category}) - withinTemp=$withinTemp, unsuitable=$unsuitable, notOptimal=$notOptimal',
      );

      return withinTemp && !unsuitable && !notOptimal;
    }).toList();
  }

  /// Score all provided items. Values are heuristics: higher = better.
  Map<ClothingItem, double> _scoreCandidates(
    List<ClothingItem> items,
    double temp,
    List<String> activities,
    double rainProbability, {
    double windSpeed = 0.0,
    double? coldThreshold,
    double? warmThreshold,
    double? minScore,
  }) {
    final scores = <ClothingItem, double>{};
    final tempDiffs = <ClothingItem, double>{};
    final lowerActivities = activities.map((a) => a.toLowerCase()).toList();
    print(
      'ScoreCandidates: activities(raw)=$activities | lower=$lowerActivities',
    );
    final int actCount = lowerActivities.isNotEmpty
        ? lowerActivities.length
        : 1;
    final double actWeight = 1.0 / actCount;

    ClothingItem? bestItem = null;
    ClothingItem? bestTempDiff = null;

    for (final item in items) {
      double score = 0;
      final c = item.usageConstraints;

      // 1) Temperature match: measure distance to the allowed [min,max] range.
      double tempDiff;
      if (temp < c.weatherMinTemp) {
        tempDiff = c.weatherMinTemp - temp;
      } else if (temp > c.weatherMaxTemp)
        tempDiff = temp - c.weatherMaxTemp;
      else
        tempDiff = 0;

      if (tempDiff == 0) {
        score += 30; // inside preferred range
      } else {
        score += max(
          0,
          30 - tempDiff * 2,
        ); // closer outside items still get some points
      }

      tempDiffs[item] = tempDiff;

      if (bestTempDiff == null || tempDiff < tempDiffs[bestTempDiff]!) {
        bestTempDiff = item;
      }

      // 2) Activities match: support multiple activities with equal weighting
      final optimalLower = c.optimalActivities
          .map((a) => a.toLowerCase())
          .toSet();
      final unsuitableLower = c.unsuitableFor
          .map((a) => a.toLowerCase())
          .toSet();

      print(
        'ItemActs: ${item.subtype} (${item.category}) optimal=${c.optimalActivities} unsuitable=${c.unsuitableFor}',
      );

      if (c.optimalActivities.isEmpty) {
        score += 8; // slightly stronger default boost
      } else {
        for (final act in lowerActivities) {
          if (optimalLower.contains(act)) {
            score += 45 * actWeight;
          }
          if (unsuitableLower.contains(act)) {
            score -= 55 * actWeight; // weighted penalty
          }
        }
      }

      // 3) Warmth suitability: prefer items whose warmthLevel matches the ideal for temp.
      // When it's raining, prefer slightly warmer items (wetness reduces insulation)
      double idealWarmth = (((20.0 - temp) / 3.0) + rainProbability * 1.5)
          .clamp(1.0, 10.0);
      // Respect user thresholds: if it's colder than their 'cold' threshold, bias towards warmer clothing.
      if (coldThreshold != null && temp <= coldThreshold) {
        idealWarmth = (idealWarmth + 1.5).clamp(1.0, 10.0);
      }
      // If it's warmer than the user's warm threshold, bias towards lighter clothing
      if (warmThreshold != null && temp >= warmThreshold) {
        idealWarmth = (idealWarmth - 1.5).clamp(1.0, 10.0);
      }
      final double warmthDiff = (item.attributes.warmthLevel - idealWarmth)
          .abs();
      score += max(0, 10 - warmthDiff * 2.0);

      // Additional threshold-driven bonus/penalty: when below cold threshold, prefer items with warmth >= ideal
      if (coldThreshold != null && temp <= coldThreshold) {
        if (item.attributes.warmthLevel >= idealWarmth)
          score += 2.0;
        else
          score -= 2.0;
      }
      // When above warm threshold, prefer lighter items
      if (warmThreshold != null && temp >= warmThreshold) {
        if (item.attributes.warmthLevel <= idealWarmth)
          score += 2.0;
        else
          score -= 2.0;
      }

      // 4) Sports-specific properties (if any activity is sports)
      if (lowerActivities.contains("sports")) {
        score += item.attributes.breathability * 2;
        score += item.attributes.stretch * 2;
      }

      // 5) Rain-specific: prefer items with higher water resistance proportional to rainProbability
      score += rainProbability * item.attributes.waterResistance * 1.5;

      // 6) Wind-specific: prefer higher wind resistance when wind is strong
      final double windFactor = (windSpeed / 20.0).clamp(
        0.0,
        2.0,
      ); // ~0-2 for 0-40 m/s
      score += windFactor * item.attributes.windResistance * 1.2;

      // 7) Formality alignment: match item formality to activity expectations
      final double desiredFormality = _desiredFormalityLevel(lowerActivities);
      final double itemFormality = _formalityValue(item.attributes.formality);
      final double formalityDiff = (itemFormality - desiredFormality).abs();
      score += max(0, 18 - formalityDiff * 3.6); // stronger formality alignment

      // 8) Small tie-breakers (optional): metadata tie-breaker slot (unused)
      // Logging to help tuning
      print(
        'ScoreCalc: ${item.subtype} (${item.category}) => score=${score.toStringAsFixed(2)} (tempDiff=${tempDiff.toStringAsFixed(1)}, idealWarmth=${idealWarmth.toStringAsFixed(2)}, warmth=${item.attributes.warmthLevel}, rainProb=${rainProbability.toStringAsFixed(2)})',
      );

      scores[item] = score;

      if (bestItem == null || score > scores[bestItem]!) {
        bestItem = item;
      }
    }

    /*if (minScore != null &&
        scores[bestItem]! < minScore &&
        bestTempDiff != null) {
      //if no item reaches the minScore, choose the one with the best (lowest) tempDiff to go through (only for low temperatures though)
      scores[bestTempDiff] = minScore;
    }*/

    return scores;
  }

  Outfit _buildOutfit(
    Map<ClothingItem, double> scores,
    double temp,
    List<String> activities,
    double rainProbability, {
    double windSpeed = 0.0,
    double? coldThreshold,
    double? warmThreshold,
  }) {
    ClothingItem? shirt;
    ClothingItem? pullover;
    ClothingItem? bottom;
    ClothingItem? shoes;
    ClothingItem? outer;
    List<ClothingItem> accessories = [];

    double computeFallbackScoreForItem(
      ClothingItem item,
      List<String> activities,
      double rainProbability,
      double windSpeed,
    ) {
      final lowerActivities = activities.map((a) => a.toLowerCase()).toList();
      final optimalLower = item.usageConstraints.optimalActivities
          .map((a) => a.toLowerCase())
          .toSet();
      final unsuitableLower = item.usageConstraints.unsuitableFor
          .map((a) => a.toLowerCase())
          .toSet();
      // Keep a fallback heuristic similar to _scoreCandidates (for consistency)
      final c = item.usageConstraints;
      double tempDiff;
      if (temp < c.weatherMinTemp) {
        tempDiff = c.weatherMinTemp - temp;
      } else if (temp > c.weatherMaxTemp)
        tempDiff = temp - c.weatherMaxTemp;
      else
        tempDiff = 0;

      double s = (tempDiff == 0) ? 30 : max(0, 30 - tempDiff * 2);
      double idealWarmth = (((20.0 - temp) / 3.0) + rainProbability * 1.5)
          .clamp(1.0, 10.0);
      if (coldThreshold != null && temp <= coldThreshold)
        idealWarmth = (idealWarmth + 1.5).clamp(1.0, 10.0);
      if (warmThreshold != null && temp >= warmThreshold)
        idealWarmth = (idealWarmth - 1.5).clamp(1.0, 10.0);
      final double warmthDiff = (item.attributes.warmthLevel - idealWarmth)
          .abs();
      s += max(0, 10 - warmthDiff * 2.0);

      if (coldThreshold != null && temp <= coldThreshold) {
        if (item.attributes.warmthLevel >= idealWarmth)
          s += 2.0;
        else
          s -= 2.0;
      }
      if (warmThreshold != null && temp >= warmThreshold) {
        if (item.attributes.warmthLevel <= idealWarmth)
          s += 2.0;
        else
          s -= 2.0;
      }
      if (c.optimalActivities.isEmpty)
        s += 8;
      else {
        final int actCount = lowerActivities.isNotEmpty
            ? lowerActivities.length
            : 1;
        final double actWeight = 1.0 / actCount;
        for (final act in lowerActivities) {
          if (optimalLower.contains(act)) s += 45 * actWeight;
          if (unsuitableLower.contains(act)) s -= 55 * actWeight;
        }
      }

      if (lowerActivities.contains("sports")) {
        s += item.attributes.breathability * 2;
        s += item.attributes.stretch * 2;
      }

      s += rainProbability * item.attributes.waterResistance * 1.5;

      final double windFactor = (windSpeed / 20.0).clamp(0.0, 2.0);
      s += windFactor * item.attributes.windResistance * 1.2;

      final double desiredFormality = _desiredFormalityLevel(lowerActivities);
      final double itemFormality = _formalityValue(item.attributes.formality);
      final double formalityDiff = (itemFormality - desiredFormality).abs();
      s += max(0, 18 - formalityDiff * 3.6);

      return s;
    }

    ClothingItem? pickByCategory(
      List<String> categoryVariations, {
      List<String>? subtypeFilter,
      int? maxWarmth,
    }) {
      // First, prefer items that match the requested category among the scored items
      var filtered = scores.entries.where((e) {
        final catLower = e.key.category.toLowerCase();
        return categoryVariations.any(
          (cat) => catLower.contains(cat.toLowerCase()),
        );
      }).toList();

      // Apply subtype filter if provided (to differentiate shirts from pullovers within tops)
      if (subtypeFilter != null && subtypeFilter.isNotEmpty) {
        filtered = filtered.where((e) {
          final subtypeLower = e.key.subtype.toLowerCase();
          return subtypeFilter.any(
            (subtype) => subtypeLower.contains(subtype.toLowerCase()),
          );
        }).toList();
      }

      // Apply warmth filter if provided
      if (maxWarmth != null) {
        filtered = filtered
            .where((e) => e.key.attributes.warmthLevel <= maxWarmth)
            .toList();
      }

      if (filtered.isNotEmpty) {
        filtered.sort((a, b) => b.value.compareTo(a.value));
        print(
          "Pick: Selected from scored candidates $categoryVariations (subtypes=$subtypeFilter, maxWarmth=$maxWarmth): ${filtered.first.key.subtype} (${filtered.first.key.category}) with score ${filtered.first.value.toStringAsFixed(2)}",
        );
        return filtered.first.key;
      }

      // If no scored candidate exists for that category (edge case), fallback to scoring wardrobe items manually
      var fallbackCandidates = wardrobe.where((item) {
        final catLower = item.category.toLowerCase();
        return categoryVariations.any(
          (cat) => catLower.contains(cat.toLowerCase()),
        );
      }).toList();

      // Apply subtype filter to fallback
      if (subtypeFilter != null && subtypeFilter.isNotEmpty) {
        fallbackCandidates = fallbackCandidates.where((item) {
          final subtypeLower = item.subtype.toLowerCase();
          return subtypeFilter.any(
            (subtype) => subtypeLower.contains(subtype.toLowerCase()),
          );
        }).toList();
      }

      // Apply warmth filter to fallback
      if (maxWarmth != null) {
        fallbackCandidates = fallbackCandidates
            .where((item) => item.attributes.warmthLevel <= maxWarmth)
            .toList();
      }

      if (fallbackCandidates.isEmpty) {
        print(
          'Pick: No items available in wardrobe to satisfy categories=$categoryVariations',
        );
        return null;
      }

      final scoredFallback =
          fallbackCandidates
              .map(
                (item) => MapEntry(
                  item,
                  computeFallbackScoreForItem(
                    item,
                    activities,
                    rainProbability,
                    windSpeed,
                  ),
                ),
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      print(
        "Pick: Fallback selected ${scoredFallback.first.key.subtype} (${scoredFallback.first.key.category}) with fallback score ${scoredFallback.first.value.toStringAsFixed(2)}",
      );
      return scoredFallback.first.key;
    }

    // Pick items based on subcategory group names from categories.json
    // Lighter tops (t-shirts, shirts & blouses, sportswear, women specific) - prefer items with lower warmth
    shirt = pickByCategory(
      [
        't-shirt',
        't-shirts',
        'tshirt',
        'tshirts',
        'shirt',
        'shirts',
        'blouse',
        'blouses',
        'shirts & blouses',
        'shirts_blouses',
        'sportswear',
        'women specific',
        'women_specific',
        'tops',
      ],
      subtypeFilter: [
        'dress shirt',
        'tee',
        'shirt',
        'blouse',
        'tank',
        'sleeveless',
        'crop',
        'tunic',
        'top',
        'performance',
        'running',
        'training',
        'compression',
        'bodysuit',
        'bralette',
        'tube',
        'bustier',
        'corsage',
      ],
      maxWarmth: 4,
    );

    // Heavier tops (knitwear, sweat) - prefer warmer items
    pullover = pickByCategory(
      ['knitwear', 'knits', 'sweat', 'sweats', 'sweater', 'sweaters'],
      subtypeFilter: [
        'sweater',
        'pullover',
        'turtleneck',
        'cardigan',
        'hoodie',
        'sweatshirt',
        'fleece',
        'poncho',
        'cape',
        'knit',
        'crewneck',
        'vneck',
        'quarter',
        'zip',
      ],
    );

    // Bottoms - all groups under bottoms category
    bottom = pickByCategory([
      'trouser',
      'trousers',
      'short',
      'shorts',
      'skirt',
      'skirts',
      'sports bottom',
      'sports_bottoms',
      'sports_bottom',
      'pant',
      'pants',
      'jean',
      'jeans',
    ]);

    // Shoes - all groups under shoes category
    shoes = pickByCategory([
      'casual shoe',
      'casual_shoes',
      'casual_shoe',
      'dress shoe',
      'dress_shoes',
      'dress_shoe',
      'sport shoe',
      'sport_shoes',
      'sport_shoe',
      'boot',
      'boots',
      'shoes',
    ]);

    // Outerwear - only include when below warmThreshold or raining
    final bool includeOuterwear =
        (warmThreshold != null && temp < warmThreshold) ||
        rainProbability > 0.0;
    outer = includeOuterwear
        ? pickByCategory([
            'jacket',
            'jackets',
            'coat',
            'coats',
            'technical outerwear',
            'technical_outerwear',
            'outerwear',
            'outer',
          ])
        : null;

    // Accessories: pick up to 2 highest-score from scores first, then fallback to wardrobe
    final accessoryEntries =
        scores.entries
            .where((e) => e.key.category.toLowerCase().contains("access"))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    accessories = accessoryEntries.take(2).map((e) => e.key).toList();

    if (accessories.length < 2) {
      final fallbackAccessories =
          wardrobe
              .where((item) => item.category.toLowerCase().contains("access"))
              .toList()
            ..sort(
              (a, b) =>
                  computeFallbackScoreForItem(
                    b,
                    activities,
                    rainProbability,
                    windSpeed,
                  ).compareTo(
                    computeFallbackScoreForItem(
                      a,
                      activities,
                      rainProbability,
                      windSpeed,
                    ),
                  ),
            );
      for (final a in fallbackAccessories) {
        if (!accessories.contains(a)) accessories.add(a);
        if (accessories.length >= 2) break;
      }
    }

    // No more fallback logic - items are only selected from their proper categories

    // No fallback assignments - categories remain null if no items found

    // Compute average score from the chosen items (use scored values when available, else fallback heuristic)
    final chosenItems = [
      if (shirt != null) shirt,
      if (pullover != null) pullover,
      if (bottom != null) bottom,
      if (shoes != null) shoes,
      if (outer != null) outer,
      ...accessories,
    ];
    double total = 0;
    for (final item in chosenItems) {
      if (scores.containsKey(item)) {
        total += scores[item]!;
      } else {
        total += computeFallbackScoreForItem(
          item,
          activities,
          rainProbability,
          windSpeed,
        );
      }
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
      accents: [if (accentColor != null) accentColor],
      neutrals: [const Color(0xfff0f0f0)],
    );

    // Compute style & color scores and final composite score
    final styleScore = _computeStyleScore(chosenItems);
    final colorScore = _computeColorScore(chosenItems, shirt, pullover, bottom);
    final double baseScore = scoreSum.toDouble();
    final double finalScore = _composeFinalScore(
      baseScore,
      styleScore,
      colorScore,
    );

    return Outfit(
      shirt: shirt,
      pullover: pullover,
      bottom: bottom,
      outerwear: outer,
      shoes: shoes,
      accessories: accessories,
      score: finalScore,
      baseScore: baseScore,
      styleScore: styleScore,
      colorScore: colorScore,
      palette: palette,
    );
  }

  /// Generate multiple ranked outfits using top candidates per category
  List<Outfit> generateOutfits({
    required double temperature,
    required List<String> activities,
    double rainProbability = 0.0,
    double windSpeed = 0.0,
    String? weatherCondition,
    double? coldThreshold,
    double? warmThreshold,
    int topNPerCategory = 3,
    int maxOutfits = 10,
  }) {
    // If rainProbability not explicitly provided, derive from weatherCondition
    double rp = rainProbability;
    if ((rp <= 0.0) &&
        (weatherCondition != null &&
            weatherCondition.toLowerCase().contains('rain'))) {
      rp = 0.8;
      print(
        'OutfitEngine: weatherCondition contains "rain", setting rainProbability=$rp',
      );
    }

    print(
      'OutfitEngine: Generating multiple outfits with topN=$topNPerCategory and maxOutfits=$maxOutfits (rainProb=${rp.toStringAsFixed(2)})',
    );

    final scores = _scoreCandidates(
      wardrobe,
      temperature,
      activities,
      rp,
      windSpeed: windSpeed,
      coldThreshold: coldThreshold,
      warmThreshold: warmThreshold,
      minScore: 25.0,
    );

    List<ClothingItem> pickTopNByCategory(
      List<String> categoryVariations,
      int n, {
      List<String>? subtypeFilter,
      int? maxWarmth,
      double? minScore = 25.0,
    }) {
      var filtered = scores.entries.where((e) {
        final catLower = e.key.category.toLowerCase();
        return categoryVariations.any(
          (cat) => catLower.contains(cat.toLowerCase()),
        );
      }).toList();

      // Apply subtype filter if provided
      if (subtypeFilter != null && subtypeFilter.isNotEmpty) {
        filtered = filtered.where((e) {
          final subtypeLower = e.key.subtype.toLowerCase();
          return subtypeFilter.any(
            (subtype) => subtypeLower.contains(subtype.toLowerCase()),
          );
        }).toList();
      }

      // Apply warmth filter if provided
      if (maxWarmth != null) {
        filtered = filtered
            .where((e) => e.key.attributes.warmthLevel <= maxWarmth)
            .toList();
      }

      // Apply minimum score filter if provided
      if (minScore != null) {
        final minScorefiltered = filtered
            .where((e) => e.value >= minScore)
            .toList();
        if (minScorefiltered.isNotEmpty) {
          filtered = minScorefiltered;
          filtered.sort((a, b) => b.value.compareTo(a.value));
        } else {
          //if no item reaches the minScore, take the ones which best fit the temperature
          filtered.sort((a, b) {
            double aTempDiff = 0;
            double bTempDiff = 0;
            if (temperature >= 10) {
              final aMaxTemp = a.key.usageConstraints.weatherMaxTemp;

              final bMaxTemp = b.key.usageConstraints.weatherMaxTemp;
              aTempDiff = (temperature - aMaxTemp).abs();
              bTempDiff = (temperature - bMaxTemp).abs();
            } else {
              final aMinTemp = a.key.usageConstraints.weatherMinTemp;
              final bMinTemp = b.key.usageConstraints.weatherMinTemp;
              aTempDiff = (temperature - aMinTemp).abs();
              bTempDiff = (temperature - bMinTemp).abs();
            }
            return aTempDiff.compareTo(bTempDiff);
          });
        }
      }

      if (filtered.isNotEmpty)
        return filtered.take(n).map((e) => e.key).toList();

      // Fallback: score wardrobe items manually and pick top n
      double computeFallback(ClothingItem item) => _fallbackScoreForItem(
        item,
        temperature,
        activities,
        rainProbability,
        windSpeed: windSpeed,
        coldThreshold: coldThreshold,
        warmThreshold: warmThreshold,
      );

      var fallbackCandidates = wardrobe.where((item) {
        final catLower = item.category.toLowerCase();
        return categoryVariations.any(
          (cat) => catLower.contains(cat.toLowerCase()),
        );
      }).toList();

      // Apply subtype filter to fallback
      if (subtypeFilter != null && subtypeFilter.isNotEmpty) {
        fallbackCandidates = fallbackCandidates.where((item) {
          final subtypeLower = item.subtype.toLowerCase();
          return subtypeFilter.any(
            (subtype) => subtypeLower.contains(subtype.toLowerCase()),
          );
        }).toList();
      }

      // Apply warmth filter to fallback
      if (maxWarmth != null) {
        fallbackCandidates = fallbackCandidates
            .where((item) => item.attributes.warmthLevel <= maxWarmth)
            .toList();
      }

      if (fallbackCandidates.isNotEmpty) {
        final scoredFallback =
            fallbackCandidates
                .map((item) => MapEntry(item, computeFallback(item)))
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        final filteredFallback = minScore == null
            ? scoredFallback
            : scoredFallback.where((e) => e.value >= minScore).toList();

        return filteredFallback.take(n).map((e) => e.key).toList();
      }

      // No items found for this category
      return [];
    }

    // Candidate pools - use subcategory group names from categories.json
    // Lighter tops (t-shirts, shirts & blouses, sportswear, women specific)
    final shirts = pickTopNByCategory(
      [
        't-shirt',
        't-shirts',
        'tshirt',
        'tshirts',
        'shirt',
        'shirts',
        'blouse',
        'blouses',
        'shirts & blouses',
        'shirts_blouses',
        'sportswear',
        'women specific',
        'women_specific',
        'tops',
      ],
      topNPerCategory,
      subtypeFilter: [
        "dress shirt",
        'tee',
        'shirt',
        'blouse',
        'tank',
        'sleeveless',
        'crop',
        'tunic',
        'top',
        'performance',
        'running',
        'training',
        'compression',
        'bodysuit',
        'bralette',
        'tube',
        'bustier',
        'corsage',
      ],
      maxWarmth: 4,
    );

    final bool includePullover =
        (warmThreshold != null && temperature < warmThreshold);
    // Heavier tops (knitwear, sweat)
    final pullovers = includePullover
        ? pickTopNByCategory(
            ['knitwear', 'knits', 'sweat', 'sweats', 'sweater', 'sweaters'],
            topNPerCategory,
            subtypeFilter: [
              'sweater',
              'pullover',
              'turtleneck',
              'cardigan',
              'hoodie',
              'sweatshirt',
              'fleece',
              'poncho',
              'cape',
              'knit',
              'crewneck',
              'vneck',
              'quarter',
              'zip',
            ],
          )
        : <ClothingItem>[];

    // Bottoms - all groups under bottoms category
    final bottoms = pickTopNByCategory([
      'trouser',
      'trousers',
      'short',
      'shorts',
      'skirt',
      'skirts',
      'sports bottom',
      'sports_bottoms',
      'sports_bottom',
      'pant',
      'pants',
      'jean',
      'jeans',
    ], topNPerCategory);

    // Shoes - all groups under shoes category
    final shoes = pickTopNByCategory([
      'casual shoe',
      'casual_shoes',
      'casual_shoe',
      'dress shoe',
      'dress_shoes',
      'dress_shoe',
      'sport shoe',
      'sport_shoes',
      'sport_shoe',
      'boot',
      'boots',
      'shoes',
    ], topNPerCategory);

    // Outerwear - only include when below warmThreshold or raining
    final bool includeOuterwear =
        (warmThreshold != null && temperature < warmThreshold) ||
        rainProbability > 0.0;
    final outers = includeOuterwear
        ? pickTopNByCategory([
            'jacket',
            'jackets',
            'coat',
            'coats',
            'technical outerwear',
            'technical_outerwear',
            'outerwear',
            'outer',
          ], topNPerCategory)
        : <ClothingItem>[];
    print(
      'OutfitEngine: pickTopNByCategory(outers) found ${outers.length} candidates => ${outers.map((o) => '${o.subtype}(${o.category})').join(', ')}',
    );

    final accessoryEntries =
        scores.entries
            .where((e) => e.key.category.toLowerCase().contains('access'))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final topAccessories = accessoryEntries.map((e) => e.key).toList();

    // Use category lists as-is without fallback
    final shirtsNonEmpty = shirts;
    final pulloversNonEmpty = pullovers;
    final bottomsNonEmpty = bottoms;
    final shoesNonEmpty = shoes;
    final outersNonEmpty = outers;

    final List<Outfit> allOutfits = [];

    // Build combinations (cartesian product) - handle empty categories by using placeholders
    // If a category is empty, use [null] to still generate outfits with missing pieces
    final shirtsList = shirtsNonEmpty.isEmpty ? [null] : shirtsNonEmpty;
    final pulloversList = pulloversNonEmpty.isEmpty
        ? [null]
        : pulloversNonEmpty;
    final bottomsList = bottomsNonEmpty.isEmpty ? [null] : bottomsNonEmpty;
    final shoesList = shoesNonEmpty.isEmpty ? [null] : shoesNonEmpty;
    final outersList = outersNonEmpty.isEmpty ? [null] : outersNonEmpty;

    for (final sh in shirtsList) {
      for (final pu in pulloversList) {
        for (final bo in bottomsList) {
          for (final shs in shoesList) {
            for (final ou in outersList) {
              final chosen = [
                if (sh != null) sh,
                if (pu != null) pu,
                if (bo != null) bo,
                if (shs != null) shs,
                if (ou != null) ou,
              ];

              // choose up to 2 accessories that are not already part of chosen
              final accessories = <ClothingItem>[];
              for (final a in topAccessories) {
                if (!chosen.contains(a)) accessories.add(a);
                if (accessories.length >= 2) break;
              }

              final outfit = _createOutfitFromSelection(
                chosen,
                accessories,
                scores,
                temperature,
                activities,
                rainProbability,
                windSpeed: windSpeed,
                coldThreshold: coldThreshold,
                warmThreshold: warmThreshold,
                pulloverHint: pu,
              );
              allOutfits.add(outfit);
            }
          }
        }
      }
    }

    allOutfits.sort((a, b) => b.score.compareTo(a.score));

    // Debug: list top candidates being returned
    final returnedCount = allOutfits.length < maxOutfits
        ? allOutfits.length
        : maxOutfits;
    print(
      'OutfitEngine.generateOutfits: total candidates=${allOutfits.length}, returning top=$returnedCount',
    );
    for (int i = 0; i < returnedCount; i++) {
      final o = allOutfits[i];
      final itemNames = [
        o.shirt?.subtype ?? '-',
        o.pullover?.subtype ?? '-',
        o.bottom?.subtype ?? '-',
        o.outerwear?.subtype ?? '-',
        o.shoes?.subtype ?? '-',
      ].join(', ');
      print(
        ' Candidate #${i + 1}: score=${o.score.toStringAsFixed(2)} base=${o.baseScore.toStringAsFixed(2)} style=${o.styleScore.toStringAsFixed(1)} color=${o.colorScore.toStringAsFixed(1)} items=[$itemNames]',
      );
    }

    return allOutfits.take(maxOutfits).toList();
  }

  double _fallbackScoreForItem(
    ClothingItem item,
    double temp,
    List<String> activities,
    double rainProbability, {
    double windSpeed = 0.0,
    double? coldThreshold,
    double? warmThreshold,
  }) {
    final lowerActivities = activities.map((a) => a.toLowerCase()).toList();
    final optimalLower = item.usageConstraints.optimalActivities
        .map((a) => a.toLowerCase())
        .toSet();
    final unsuitableLower = item.usageConstraints.unsuitableFor
        .map((a) => a.toLowerCase())
        .toSet();
    final c = item.usageConstraints;
    double tempDiff;
    if (temp < c.weatherMinTemp) {
      tempDiff = c.weatherMinTemp - temp;
    } else if (temp > c.weatherMaxTemp)
      tempDiff = temp - c.weatherMaxTemp;
    else
      tempDiff = 0;

    double s = (tempDiff == 0) ? 30 : max(0, 30 - tempDiff * 2);
    double idealWarmth = (((20.0 - temp) / 3.0) + rainProbability * 1.5).clamp(
      1.0,
      10.0,
    );
    if (coldThreshold != null && temp <= coldThreshold)
      idealWarmth = (idealWarmth + 1.5).clamp(1.0, 10.0);
    if (warmThreshold != null && temp >= warmThreshold)
      idealWarmth = (idealWarmth - 1.5).clamp(1.0, 10.0);
    final double warmthDiff = (item.attributes.warmthLevel - idealWarmth).abs();
    s += max(0, 10 - warmthDiff * 2.0);

    if (coldThreshold != null && temp <= coldThreshold) {
      if (item.attributes.warmthLevel >= idealWarmth)
        s += 2.0;
      else
        s -= 2.0;
    }
    if (warmThreshold != null && temp >= warmThreshold) {
      if (item.attributes.warmthLevel <= idealWarmth)
        s += 2.0;
      else
        s -= 2.0;
    }

    if (c.optimalActivities.isEmpty) {
      s += 8;
    } else {
      final int actCount = lowerActivities.isNotEmpty
          ? lowerActivities.length
          : 1;
      final double actWeight = 1.0 / actCount;
      for (final act in lowerActivities) {
        if (optimalLower.contains(act)) s += 45 * actWeight;
        if (unsuitableLower.contains(act)) s -= 55 * actWeight;
      }
    }

    if (lowerActivities.contains("sports")) {
      s += item.attributes.breathability * 2;
      s += item.attributes.stretch * 2;
    }

    s += rainProbability * item.attributes.waterResistance * 1.5;

    final double windFactor = (windSpeed / 20.0).clamp(0.0, 2.0);
    s += windFactor * item.attributes.windResistance * 1.2;

    final double desiredFormality = _desiredFormalityLevel(lowerActivities);
    final double itemFormality = _formalityValue(item.attributes.formality);
    final double formalityDiff = (itemFormality - desiredFormality).abs();
    s += max(0, 18 - formalityDiff * 3.6);

    return s;
  }

  // Helper: safely find first matching ClothingItem or return null
  ClothingItem? _firstWhereOrNull(
    List<ClothingItem> list,
    bool Function(ClothingItem) test,
  ) {
    for (final c in list) {
      if (test(c)) return c;
    }
    return null;
  }

  Outfit _createOutfitFromSelection(
    List<ClothingItem> chosen,
    List<ClothingItem> accessories,
    Map<ClothingItem, double> scores,
    double temp,
    List<String> activities,
    double rainProbability, {
    double windSpeed = 0.0,
    double? coldThreshold,
    double? warmThreshold,
    ClothingItem? pulloverHint,
  }) {
    final items = [...chosen, ...accessories];

    // base score
    double total = 0;
    for (final item in items) {
      if (scores.containsKey(item))
        total += scores[item]!;
      else {
        total += _fallbackScoreForItem(
          item,
          temp,
          activities,
          rainProbability,
          windSpeed: windSpeed,
          coldThreshold: coldThreshold,
          warmThreshold: warmThreshold,
        );
      }
    }
    final baseScore = items.isNotEmpty ? total / items.length : 0.0;

    final shirt = _firstWhereOrNull(
      chosen,
      (c) =>
          c.category.toLowerCase().contains('top') ||
          c.category.toLowerCase().contains('t-shirt') ||
          c.category.toLowerCase().contains('shirt') ||
          c.category.toLowerCase().contains('tops'),
    );
    final pullover =
        pulloverHint ??
        _firstWhereOrNull(
          chosen,
          (c) =>
              c.category.toLowerCase().contains('sweat') ||
              c.category.toLowerCase().contains('hoodie') ||
              c.category.toLowerCase().contains('pullover') ||
              c.category.toLowerCase().contains('sweater'),
        );
    final bottom = _firstWhereOrNull(
      chosen,
      (c) =>
          c.category.toLowerCase().contains('bottom') ||
          c.category.toLowerCase().contains('trous') ||
          c.category.toLowerCase().contains('pant') ||
          c.category.toLowerCase().contains('short') ||
          c.category.toLowerCase().contains('skirt') ||
          c.category.toLowerCase().contains('jean'),
    );

    final styleScore = _computeStyleScore(items);
    final colorScore = _computeColorScore(items, shirt, pullover, bottom);

    final finalScore = _composeFinalScore(baseScore, styleScore, colorScore);

    // palette
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
      accents: [if (accentColor != null) accentColor],
      neutrals: [const Color(0xfff0f0f0)],
    );

    // Debug: print item-level scores and outfit summary
    try {
      print(
        'OutfitEngine._createOutfitFromSelection: built outfit items=${items.map((i) => i.subtype).join(', ')} final=${finalScore.toStringAsFixed(2)} base=${baseScore.toStringAsFixed(2)} style=${styleScore.toStringAsFixed(1)} color=${colorScore.toStringAsFixed(1)}',
      );
      for (final item in items) {
        final double itemScore = scores.containsKey(item)
            ? scores[item]!
            : _fallbackScoreForItem(
                item,
                temp,
                activities,
                rainProbability,
                windSpeed: windSpeed,
                coldThreshold: coldThreshold,
                warmThreshold: warmThreshold,
              );
        print(
          '  - ${item.subtype} (${item.category}): score=${itemScore.toStringAsFixed(2)} warmth=${item.attributes.warmthLevel} water=${item.attributes.waterResistance} optimalActs=${item.usageConstraints.optimalActivities}',
        );
      }
    } catch (e) {
      print('OutfitEngine.debug: failed to print outfit details: $e');
    }

    return Outfit(
      shirt: shirt,
      pullover: pullover,
      bottom: bottom,
      outerwear: _firstWhereOrNull(
        chosen,
        (c) =>
            c.category.toLowerCase().contains('outer') ||
            c.category.toLowerCase().contains('jacket') ||
            c.category.toLowerCase().contains('coat'),
      ),
      shoes: _firstWhereOrNull(
        chosen,
        (c) =>
            c.category.toLowerCase().contains('shoe') ||
            c.category.toLowerCase().contains('boot'),
      ),
      accessories: accessories,
      score: finalScore,
      baseScore: baseScore,
      styleScore: styleScore,
      colorScore: colorScore,
      palette: palette,
    );
  }

  // Map stored formality strings to a numeric scale for scoring
  double _formalityValue(String formality) {
    switch (formality.toLowerCase()) {
      case 'black_tie':
        return 10.0;
      case 'formal':
        return 9.0;
      case 'business_formal':
      case 'business':
        return 8.0;
      case 'smart_casual':
      case 'business_casual':
        return 6.5;
      case 'casual':
        return 4.5;
      case 'sport':
      case 'athletic':
        return 2.5;
      default:
        return 4.5;
    }
  }

  // Estimate desired formality from activities (keywords derived from activities.json)
  double _desiredFormalityLevel(List<String> activities) {
    final acts = activities.map((a) => a.toLowerCase()).toList();

    if (acts.any(
      (a) =>
          a.contains('wedding') ||
          a.contains('dinner_event') ||
          a.contains('formal'),
    )) {
      return 8.5;
    }
    if (acts.any(
      (a) =>
          a.contains('presentation') ||
          a.contains('dates') ||
          a.contains('night_out') ||
          a.contains('party'),
    )) {
      return 7.5;
    }
    if (acts.any(
      (a) =>
          a.contains('office') ||
          a.contains('business') ||
          a.contains('meeting') ||
          a.contains('work'),
    )) {
      return 7.0;
    }
    if (acts.any(
      (a) =>
          a.contains('manual') ||
          a.contains('workshop') ||
          a.contains('construction'),
    )) {
      return 5.0;
    }
    if (acts.any(
      (a) =>
          a.contains('sports') ||
          a.contains('gym') ||
          a.contains('run') ||
          a.contains('cycling') ||
          a.contains('yoga'),
    )) {
      return 3.0;
    }
    if (acts.any(
      (a) =>
          a.contains('hiking') ||
          a.contains('outdoor') ||
          a.contains('camping'),
    )) {
      return 4.0;
    }
    if (acts.any(
      (a) =>
          a.contains('travel') ||
          a.contains('commute') ||
          a.contains('transport'),
    )) {
      return 4.5;
    }

    return 4.5; // default casual
  }

  double _composeFinalScore(
    double baseScore,
    double styleScore,
    double colorScore,
  ) {
    const baseWeight = 0.6;
    const styleWeight = 0.25;
    const colorWeight = 0.15;
    // styleScore and colorScore are in 0..100, while baseScore is in similar scale (approximately 0..100)
    return baseScore * baseWeight +
        styleScore * styleWeight +
        colorScore * colorWeight;
  }

  double _computeStyleScore(List<ClothingItem> items) {
    if (items.isEmpty) return 0.0;

    // Style tags cohesion
    final tagCounts = <String, int>{};
    for (final item in items) {
      for (final tag in item.attributes.styleTags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final bool hasStyleTags = tagCounts.isNotEmpty;
    final double styleTagScore = hasStyleTags
        ? (tagCounts.values.reduce(max) / items.length) * 100.0
        : 0.0;

    // Fit cohesion (e.g., regular/slim/relaxed); rewards consistent fit within outfit
    final fitCounts = <String, int>{};
    for (final item in items) {
      final fit = item.attributes.fit.toLowerCase();
      fitCounts[fit] = (fitCounts[fit] ?? 0) + 1;
    }
    final bool hasFits = fitCounts.isNotEmpty;
    final double fitScore = hasFits
        ? (fitCounts.values.reduce(max) / items.length) * 100.0
        : 0.0;

    if (!hasStyleTags && !hasFits) return 0.0;

    // Blend style cohesion and fit cohesion (70/30)
    return styleTagScore * 0.7 + fitScore * 0.3;
  }

  double _computeColorScore(
    List<ClothingItem> items,
    ClothingItem? shirt,
    ClothingItem? pullover,
    ClothingItem? bottom,
  ) {
    if (items.isEmpty) return 0.0;
    final Color dominantColor =
        (shirt != null && shirt.extractedColors.isNotEmpty)
        ? shirt.extractedColors.first
        : (pullover != null && pullover.extractedColors.isNotEmpty)
        ? pullover.extractedColors.first
        : const Color(0xff000000);

    final Color? accentColor =
        (bottom != null && bottom.extractedColors.isNotEmpty)
        ? bottom.extractedColors.first
        : null;

    const maxDist = 441.6729559; // sqrt(3*255^2)

    double sumScore = 0.0;
    for (final item in items) {
      if (item.extractedColors.isEmpty) {
        sumScore += 50.0; // neutral fallback
        continue;
      }
      double minDist = double.infinity;
      for (final c in item.extractedColors) {
        final d1 = _colorDistance(c, dominantColor);
        minDist = min(minDist, d1);
        if (accentColor != null) {
          final d2 = _colorDistance(c, accentColor);
          minDist = min(minDist, d2);
        }
      }
      final score = (1.0 - (minDist / maxDist)).clamp(0.0, 1.0) * 100.0;
      sumScore += score;
    }

    return sumScore / items.length;
  }

  double _colorDistance(Color a, Color b) {
    final ar = (a.value >> 16) & 0xFF;
    final ag = (a.value >> 8) & 0xFF;
    final ab = a.value & 0xFF;

    final br = (b.value >> 16) & 0xFF;
    final bg = (b.value >> 8) & 0xFF;
    final bb = b.value & 0xFF;

    final dr = ar - br;
    final dg = ag - bg;
    final db = ab - bb;
    return sqrt(dr * dr + dg * dg + db * db);
  }
}
