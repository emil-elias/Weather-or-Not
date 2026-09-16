class Weather {
  final String stationName;
  final String stationId;
  final String? source;
  final double? temperature;
  final double? precipitation;
  final double? precipitation_3h;
  final double? snow;
  final double? dewpoint;
  final double? sunshine;
  final double? windSpeed;
  final double? windGust;
  final double? windDirection;
  final double? cloudCover;
  final double? humidity;
  final double? pressure;
  final String? condition;
  final DateTime timestamp;
  final int? icon;


  Weather({
    required this.stationName,
    required this.stationId,
    this.source,
    this.temperature,
    this.precipitation,
    this.precipitation_3h,
    this.snow,
    this.dewpoint,
    this.sunshine,
    this.windSpeed,
    this.windGust,
    this.windDirection,
    this.cloudCover,
    this.humidity,
    this.pressure,
    this.condition,
    required this.timestamp,
    this.icon,
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
