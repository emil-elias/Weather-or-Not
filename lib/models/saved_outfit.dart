class SavedOutfit {
  final String id;
  final String name;
  final DateTime savedAt;
  final String? shirtId;
  final String? pulloverId;
  final String? bottomId;
  final String? outerwearId;
  final String? shoesId;
  final List<String> accessoryIds;
  final bool isFavorite;

  SavedOutfit({
    required this.id,
    required this.name,
    required this.savedAt,
    this.shirtId,
    this.pulloverId,
    this.bottomId,
    this.outerwearId,
    this.shoesId,
    this.accessoryIds = const [],
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'savedAt': savedAt.toIso8601String(),
      'shirtId': shirtId,
      'pulloverId': pulloverId,
      'bottomId': bottomId,
      'outerwearId': outerwearId,
      'shoesId': shoesId,
      'accessoryIds': accessoryIds,
      'isFavorite': isFavorite,
    };
  }

  factory SavedOutfit.fromJson(Map<String, dynamic> json) {
    return SavedOutfit(
      id: json['id'] as String,
      name: json['name'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
      shirtId: json['shirtId'] as String?,
      pulloverId: json['pulloverId'] as String?,
      bottomId: json['bottomId'] as String?,
      outerwearId: json['outerwearId'] as String?,
      shoesId: json['shoesId'] as String?,
      accessoryIds: List<String>.from(json['accessoryIds'] as List? ?? []),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
