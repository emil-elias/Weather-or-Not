class DayForecast {
  final DateTime date;
  final double? minTemperature;
  final double? maxTemperature;
  final double? precipitation;
  final double? windSpeed;
  final double? windGust;
  final double? windDirection;
  final double? sunshine;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? moonrise;
  final DateTime? moonset;
  final int? moonphase;
  final int? icon;

  DayForecast({
    required this.date,
    this.minTemperature,
    this.maxTemperature,
    this.precipitation,
    this.windSpeed,
    this.windGust,
    this.windDirection,
    this.sunshine,
    this.sunrise,
    this.sunset,
    this.moonrise,
    this.moonset,
    this.moonphase,
    this.icon,
  });

}