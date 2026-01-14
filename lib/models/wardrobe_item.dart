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
      attributes: (json['attributes'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
      usageConstraints: (json['usageConstraints'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
      isInWash: json['isInWash'] as bool? ?? false,
    );
  }
}
