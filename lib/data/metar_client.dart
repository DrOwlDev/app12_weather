import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/bucket.dart';
import '../services/bucket_parser.dart';

class MetarClient {
  MetarClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<double?> fetchRunningDailyMax({
    required String icao,
    required DateTime targetDate,
    required TemperatureUnit unit,
  }) async {
    if (icao.isEmpty) return null;

    final uri = Uri.parse(metarApiBase).replace(
      queryParameters: {
        'ids': icao.toUpperCase(),
        'format': 'json',
        'hours': '24',
      },
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! List || data.isEmpty) return null;

      final now = DateTime.now();
      final isToday = targetDate.year == now.year &&
          targetDate.month == now.month &&
          targetDate.day == now.day;
      if (!isToday) return null;

      var maxTemp = double.negativeInfinity;
      for (final obs in data) {
        if (obs is! Map<String, dynamic>) continue;
        final temp = obs['temp'];
        if (temp == null) continue;
        final celsius = (temp as num).toDouble();
        final converted = unit == TemperatureUnit.fahrenheit
            ? celsiusToFahrenheit(celsius)
            : celsius;
        maxTemp = max(maxTemp, converted);
      }

      if (maxTemp == double.negativeInfinity) return null;
      return maxTemp;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
