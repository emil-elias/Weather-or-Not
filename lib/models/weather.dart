class Weather {
  final String stationName;
  final String stationId;
  final double? temperature;
  final double? precipitation;
  final double? windSpeed;
  final int? cloudCover;
  final int? humidity;
  final double? pressure;
  final String? condition;
  final DateTime timestamp;

  Weather({
    required this.stationName,
    required this.stationId,
    this.temperature,
    this.precipitation,
    this.windSpeed,
    this.cloudCover,
    this.humidity,
    this.pressure,
    this.condition,
    required this.timestamp,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      stationName: json['station_name'] ?? '',
      stationId: json['station_id'] ?? '',
      temperature: json['temperature']?.toDouble(),
      precipitation: json['precipitation']?.toDouble(),
      windSpeed: json['wind_speed']?.toDouble(),
      cloudCover: json['cloud_cover']?.toInt(),
      humidity: json['humidity']?.toInt(),
      pressure: json['pressure']?.toDouble(),
      condition: json['condition'],
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

}
