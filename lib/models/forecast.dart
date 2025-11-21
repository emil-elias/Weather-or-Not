import 'package:weatherornot/models/day_forecast.dart';
import 'package:weatherornot/models/weather_warning.dart';

class Forecast {
  final String stationName;
  final String stationId;
  final String? source;
  final DateTime? start;
  final int? timestep;
  final List<double>? temperature;
  final List<double>? windSpeed;
  final List<double>? windGust;
  final List<double>? windDirection;
  final List<double>? precipitation;
  final List<double>? sunshine;
  final List<double>? dewPoint;
  final List<double>? pressure;
  final List<double>? humidity;
  final List<bool>? isDaylight;
  final List<double>? cloudCover;
  final List<double>? precipitationProbability;
  final List<int>? icon;
  final List<DayForecast>? days;
  final List<WeatherWarning>? warnings;

  Forecast({
    required this.stationName,
    required this.stationId,
    this.source,
    this.start,
    this.timestep,
    this.temperature,
    this.windSpeed,
    this.windGust,
    this.windDirection,
    this.precipitation,
    this.sunshine,
    this.dewPoint,
    this.pressure,
    this.humidity,
    this.isDaylight,
    this.cloudCover,
    this.precipitationProbability,
    this.icon,
    this.days,
    this.warnings,
  });





}