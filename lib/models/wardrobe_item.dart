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
  final DateTime createdAt;
  final bool isFavorite;

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
    required this.createdAt,
    this.isFavorite = false,
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
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
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
      createdAt: DateTime.parse(json['createdAt'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
