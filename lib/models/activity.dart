class Activity {
  final String id;
  final String name;
  final ActivityStyle style;
  final ActivityType type;
  final bool isWeekly;

  Activity({
    required this.id,
    required this.name,
    required this.style,
    required this.type,
    required this.isWeekly,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'style': style.name,
      'type': type.name,
      'isWeekly': isWeekly,
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      style: ActivityStyle.values.firstWhere(
        (e) => e.name == json['style'],
        orElse: () => ActivityStyle.casual,
      ),
      type: ActivityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ActivityType.other,
      ),
      isWeekly: json['isWeekly'] ?? false,
    );
  }
}

enum ActivityStyle {
  schick('Schick'),
  sportlich('Sportlich'),
  casual('Casual'),
  elegant('Elegant'),
  business('Business');

  final String displayName;
  const ActivityStyle(this.displayName);
}

enum ActivityType {
  sport('Sport'),
  feiern('Feiern'),
  spazierengehen('Spazierengehen'),
  meetings('Meetings'),
  uni('Uni'),
  reisen('Reisen'),
  putzen('Putzen'),
  gartenarbeit('Gartenarbeit'),
  other('Sonstiges');

  final String displayName;
  const ActivityType(this.displayName);
}
