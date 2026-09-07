import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// Simple wrapper around the OpenWeatherMap API. Given the user's current
// location, it returns a plain-English weather summary and a practical
// suggestion (umbrella, sunscreen, etc.), plus a short multi-day forecast
// — the "environmental awareness" piece of the Smart Lifestyle Companion.
class WeatherService {
  static const String _apiKey = 'WEATHER_API_KEY';

  Future<WeatherResult?> getCurrentWeather(Position position) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather'
      '?lat=${position.latitude}&lon=${position.longitude}'
      '&appid=$_apiKey&units=metric',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final mainCondition = data['weather'][0]['main'] as String;
      final description = data['weather'][0]['description'] as String;
      final temperature = (data['main']['temp'] as num).toDouble();

      return WeatherResult(
        condition: mainCondition,
        description: description,
        temperatureCelsius: temperature,
        suggestion: _buildSuggestion(mainCondition, temperature),
      );
    } catch (e) {
      return null;
    }
  }

  // Uses the free 5-day/3-hour forecast endpoint and groups the many
  // 3-hourly readings into one entry per day, picking the entry closest
  // to midday as representative of that day's weather.
  Future<List<DailyForecast>> getForecast(Position position) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/forecast'
      '?lat=${position.latitude}&lon=${position.longitude}'
      '&appid=$_apiKey&units=metric',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List<dynamic> entries = data['list'];

      // Group the 3-hourly entries by calendar day.
      final Map<String, List<dynamic>> byDay = {};
      for (final entry in entries) {
        final dt = DateTime.fromMillisecondsSinceEpoch((entry['dt'] as int) * 1000);
        final dayKey = '${dt.year}-${dt.month}-${dt.day}';
        byDay.putIfAbsent(dayKey, () => []).add(entry);
      }

      final List<DailyForecast> forecasts = [];
      for (final dayEntries in byDay.values) {
        // Pick the reading closest to midday (12:00) as representative.
        dayEntries.sort((a, b) {
          final aHour = DateTime.fromMillisecondsSinceEpoch((a['dt'] as int) * 1000).hour;
          final bHour = DateTime.fromMillisecondsSinceEpoch((b['dt'] as int) * 1000).hour;
          return (aHour - 12).abs().compareTo((bHour - 12).abs());
        });
        final representative = dayEntries.first;
        final dt = DateTime.fromMillisecondsSinceEpoch((representative['dt'] as int) * 1000);

        forecasts.add(DailyForecast(
          date: dt,
          condition: representative['weather'][0]['main'] as String,
          description: representative['weather'][0]['description'] as String,
          temperatureCelsius: (representative['main']['temp'] as num).toDouble(),
        ));
      }

      forecasts.sort((a, b) => a.date.compareTo(b.date));
      // The forecast API's first "day" is often just a few remaining
      // hours of today, so skip it and show the next several full days.
      return forecasts.length > 1 ? forecasts.sublist(1).take(5).toList() : forecasts.take(5).toList();
    } catch (e) {
      return [];
    }
  }

  // Turns a raw weather condition into a practical, human suggestion —
  // this is the "smart" part that makes it more than just a weather app.
  String _buildSuggestion(String condition, double tempCelsius) {
    switch (condition) {
      case 'Rain':
      case 'Drizzle':
      case 'Thunderstorm':
        return 'Rain expected — take an umbrella before you leave.';
      case 'Clear':
        if (tempCelsius > 30) {
          return 'Hot and sunny — stay hydrated and consider sunscreen.';
        }
        return 'Clear skies — good day to be out and about.';
      case 'Clouds':
        return 'Cloudy skies — no rain expected right now, but keep an eye out.';
      default:
        return 'Check conditions before heading out.';
    }
  }

  // Whether a condition counts as "you should probably bring an
  // umbrella" — used both for the current-weather suggestion and for
  // folding a weather warning into the "before you leave" check.
  static bool isRainy(String condition) {
    return condition == 'Rain' || condition == 'Drizzle' || condition == 'Thunderstorm';
  }

  static double celsiusToFahrenheit(double celsius) => (celsius * 9 / 5) + 32;
}

class WeatherResult {
  final String condition;
  final String description;
  final double temperatureCelsius;
  final String suggestion;

  WeatherResult({
    required this.condition,
    required this.description,
    required this.temperatureCelsius,
    required this.suggestion,
  });
}

class DailyForecast {
  final DateTime date;
  final String condition;
  final String description;
  final double temperatureCelsius;

  DailyForecast({
    required this.date,
    required this.condition,
    required this.description,
    required this.temperatureCelsius,
  });
}