import 'package:weatherornot/models/day_forecast.dart';
import 'package:weatherornot/models/forecast.dart';
import 'package:weatherornot/models/weather.dart';
import 'package:weatherornot/models/weather_warning.dart';

class TestService {
  static Weather getTestWeather() {
    return Weather(
      stationName: 'TEST WEATHER',
      stationId: 'TEST0',
      source: 'Trust me bro',
      temperature: 29.0,
      precipitation: 0.0,
      precipitation_3h: 0.0,
      snow: 0.0,
      dewpoint: 10.0,
      sunshine: 8.0,
      windSpeed: 10.0,
      windGust: 15.0,
      windDirection: 180.0,
      cloudCover: 30,
      humidity: 50,
      pressure: 1015.0,
      condition: null,
      timestamp: DateTime.now(),
      icon: 1,
    );
  }

  static Forecast getTestForecast() {
    return Forecast(
      stationName: 'TEST WEATHER',
      stationId: 'TEST0',
      source: 'Trust me bro',
      start: DateTime.now(),
      timestep: 3600000,
      temperature: List<double>.generate(48, (index) => 15 + index * 0.5),
      windSpeed: List<double>.generate(48, (index) => 5 + index * 0.3),
      windGust: List<double>.generate(48, (index) => 10 + index * 0.4),
      windDirection: List<double>.generate(48, (index) => (index * 15) % 360),
      precipitation: List<double>.generate(
        48,
        (index) => index % 5 == 0 ? 1.0 : 0.0,
      ),
      sunshine: List<double>.generate(
        48,
        (index) => index % 3 == 0 ? 1.0 : 0.0,
      ),
      dewPoint: List<double>.generate(48, (index) => 10 + index * 0.2),
      pressure: List<double>.generate(48, (index) => 1010 + index * 0.5),
      humidity: List<double>.generate(48, (index) => 40 + (index % 60)),
      isDaylight: List<bool>.generate(
        48,
        (index) => index % 24 >= 6 && index % 24 <= 18,
      ),
      cloudCover: List<double>.generate(
        48,
        (index) => (index * 10) % 100.toDouble(),
      ),
      precipitationProbability: List<double>.generate(
        48,
        (index) => (index * 5) % 100.toDouble(),
      ),
      icon: List<int>.generate(48, (index) => (index % 8) + 1),
      days: [
        DayForecast(
          date: DateTime.now(),
          minTemperature: 25.0,
          maxTemperature: 30.0,
          precipitation: 0.0,
          windSpeed: 20.0,
          windGust: 30.0,
          windDirection: 180.0,
          sunshine: 10.0,
          sunrise: DateTime.now().add(Duration(hours: 6)),
          sunset: DateTime.now().add(Duration(hours: 18)),
          moonrise: DateTime.now().add(Duration(hours: 20)),
          moonset: DateTime.now().add(Duration(hours: 8)),
          moonphase: 2,
          icon: 3,
        ),
        DayForecast(
          date: DateTime.now(),
          minTemperature: 15.0,
          maxTemperature: 30.0,
          precipitation: 5.0,
          windSpeed: 20.0,
          windGust: 30.0,
          windDirection: 180.0,
          sunshine: 10.0,
          sunrise: DateTime.now().add(Duration(hours: 6)),
          sunset: DateTime.now().add(Duration(hours: 18)),
          moonrise: DateTime.now().add(Duration(hours: 20)),
          moonset: DateTime.now().add(Duration(hours: 8)),
          moonphase: 2,
          icon: 3,
        ),
      ],

      warnings: [
        WeatherWarning(
          warnId: "testwarning",
          type: 1,
          level: 2,
          event: "Weather",
          start: DateTime.now(),
          end: DateTime.now().add(Duration(hours: 6)),
          title: "Test Warning",
          description: "There is weather in your area.",
          instruction: "Always trust WeatherOrNot with your clothing choice!",
        ),
      ],
    );
  }
}
