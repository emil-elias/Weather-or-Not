import 'package:weatherornot/models/forecast.dart';
import 'package:weatherornot/models/weather.dart';

/// Application-wide constants
class AppConstants {
  // Prevent instantiation
  AppConstants._();

  /// Bremen coordinates
  static const double bremenLatitude = 53.0793;
  static const double bremenLongitude = 8.8017;

  /// Bright Sky API Base URL
  static const String brightSkyApiBaseUrl = 'https://api.brightsky.dev';

  static const String DWDApiBaseUrl = 'https://dwd.api.proxy.bund.dev/v30';
  static const String DWDApiBaseUrlAlt =
      'https://app-prod-ws.warnwetter.de/v30';

  static const String DWDAWSApiBaseUrl =
      "https://s3.eu-central-1.amazonaws.com/app-prod-static.warnwetter.de/v16";

  static const String LuftqualitaetApiBaseUrl =
      'https://umweltbundesamt.api.proxy.bund.dev/api/air_data/v2/airquality/json?';

  static const Map<String, String> stationIDs = {
    'BREMEN': "10224",
    'HAMBURG': "P0489", //(Innenstadt); Fuhlsbüttel: 10147, Neuwiedenthal: C720
    'BERLIN':
        "10389", //(Alexanderplatz); Brandenburg: 10385, Buch: G002, Kaniswall: G006, Tempelhof: 10384, ...
    'MÜNCHEN': "10865", //(Stadt); Flughafen: 10870
    'KÖLN': "10513", //(Köln/Bonn); Stammheim: H744
    'LISBON': "08536",
  };

}

/// Weather condition constants from Bright Sky API
class WeatherConditions {
  WeatherConditions._();

  /// Dry conditions
  static const String dry = 'dry';

  /// Fog
  static const String fog = 'fog';

  /// Rain
  static const String rain = 'rain';

  /// Sleet (mixed rain and snow)
  static const String sleet = 'sleet';

  /// Snow
  static const String snow = 'snow';

  /// Hail
  static const String hail = 'hail';

  /// Thunderstorm
  static const String thunderstorm = 'thunderstorm';

  /// German translations for weather conditions
  static const Map<String, String> germanTranslations = {
    dry: 'Trocken',
    fog: 'Neblig',
    rain: 'Regnerisch',
    sleet: 'Schneeregen',
    snow: 'Schneefall',
    hail: 'Hagel',
    thunderstorm: 'Gewitter',
  };

  /// Get German description for condition with additional context
  static String getGermanDescription(
    String? condition, {
    double? temperature,
    double? windSpeed,
    double? cloudCover,
  }) {
    if (condition == null) return 'Wetter unbekannt';

    List<String> descriptions = [];

    // Base condition
    String baseCondition =
        germanTranslations[condition.toLowerCase()] ?? 'Wechselhaft';

    // For dry conditions, check cloud cover
    if (condition.toLowerCase() == 'dry') {
      if (cloudCover != null) {
        if (cloudCover < 20) {
          baseCondition = 'Sonnig';
        } else if (cloudCover < 50) {
          baseCondition = 'Heiter';
        } else if (cloudCover < 80) {
          baseCondition = 'Teilweise bewölkt';
        } else {
          baseCondition = 'Bewölkt';
        }
      }
    }

    descriptions.add(baseCondition);

    // Add temperature context
    if (temperature != null) {
      if (temperature >= 28) {
        descriptions.add('heiß');
      } else if (temperature >= 20) {
        descriptions.add('warm');
      } else if (temperature >= 15) {
        descriptions.add('mild');
      } else if (temperature >= 5) {
        descriptions.add('kühl');
      } else if (temperature >= 0) {
        descriptions.add('kalt');
      } else {
        descriptions.add('eisig');
      }
    }

    // Add wind context
    if (windSpeed != null) {
      if (windSpeed >= 50) {
        descriptions.add('stürmisch');
      } else if (windSpeed >= 30) {
        descriptions.add('windig');
      } else if (windSpeed >= 20) {
        descriptions.add('mäßiger Wind');
      } else if (windSpeed >= 5) {
        descriptions.add('leichter Wind');
      }
    }

    // Join descriptions
    if (descriptions.length == 1) {
      return descriptions[0];
    } else if (descriptions.length == 2) {
      return '${descriptions[0]} und ${descriptions[1]}';
    } else {
      return '${descriptions[0]}, ${descriptions.sublist(1).join(', ')}';
    }
  }
}
