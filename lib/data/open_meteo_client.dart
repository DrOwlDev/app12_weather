import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/bucket.dart';

class ForecastResult {
  const ForecastResult({
    required this.memberMaxTemps,
    required this.ensembleMean,
    required this.ensembleSpread,
    required this.unit,
  });

  final List<double> memberMaxTemps;
  final double ensembleMean;
  final double ensembleSpread;
  final TemperatureUnit unit;
}

class OpenMeteoClient {
  OpenMeteoClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ForecastResult?> fetchDailyMaxEnsemble({
    required double latitude,
    required double longitude,
    required DateTime targetDate,
    required TemperatureUnit unit,
  }) async {
    if (latitude == 0 && longitude == 0) return null;

    final params = {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'hourly': 'temperature_2m',
      'models': 'gfs_seamless',
      'forecast_days': '7',
      'timezone': 'auto',
      'temperature_unit': unit == TemperatureUnit.fahrenheit ? 'fahrenheit' : 'celsius',
    };

    final uri = Uri.parse(openMeteoEnsembleBase).replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return null;

    final times = (hourly['time'] as List<dynamic>).cast<String>();
    final targetKey = _dateKey(targetDate);

    final memberKeys = hourly.keys
        .where((k) => k.startsWith('temperature_2m_member'))
        .cast<String>()
        .toList();

    if (memberKeys.isEmpty) {
      final temps = hourly['temperature_2m'] as List<dynamic>?;
      if (temps == null) return null;
      final dayTemps = <double>[];
      for (var i = 0; i < times.length; i++) {
        if (times[i].startsWith(targetKey)) {
          final t = temps[i];
          if (t != null) dayTemps.add((t as num).toDouble());
        }
      }
      if (dayTemps.isEmpty) return null;
      final maxTemp = dayTemps.reduce(max);
      return ForecastResult(
        memberMaxTemps: [maxTemp],
        ensembleMean: maxTemp,
        ensembleSpread: 0,
        unit: unit,
      );
    }

    final memberMaxes = <double>[];
    for (final key in memberKeys) {
      final temps = hourly[key] as List<dynamic>;
      final dayTemps = <double>[];
      for (var i = 0; i < times.length; i++) {
        if (times[i].startsWith(targetKey)) {
          final t = temps[i];
          if (t != null) dayTemps.add((t as num).toDouble());
        }
      }
      if (dayTemps.isNotEmpty) {
        memberMaxes.add(dayTemps.reduce(max));
      }
    }

    if (memberMaxes.isEmpty) return null;

    final mean = memberMaxes.reduce((a, b) => a + b) / memberMaxes.length;
    final variance = memberMaxes
            .map((t) => pow(t - mean, 2))
            .reduce((a, b) => a + b) /
        memberMaxes.length;
    final spread = sqrt(variance) * spreadInflationFactor;

    return ForecastResult(
      memberMaxTemps: memberMaxes,
      ensembleMean: mean,
      ensembleSpread: spread,
      unit: unit,
    );
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void dispose() => _client.close();
}

Map<String, double> bucketProbabilitiesFromEnsemble({
  required List<TemperatureBucket> buckets,
  required List<double> memberMaxTemps,
  double? runningMaxObserved,
}) {
  if (buckets.isEmpty || memberMaxTemps.isEmpty) return {};

  final adjustedMembers = memberMaxTemps.map((t) {
    if (runningMaxObserved != null && runningMaxObserved > t) {
      return runningMaxObserved;
    }
    return t;
  }).toList();

  final counts = <String, int>{};
  for (final bucket in buckets) {
    counts[bucket.id] = 0;
  }

  for (final temp in adjustedMembers) {
    for (final bucket in buckets) {
      if (bucket.containsTemperature(temp)) {
        counts[bucket.id] = (counts[bucket.id] ?? 0) + 1;
        break;
      }
    }
  }

  final total = adjustedMembers.length;
  return counts.map((id, count) => MapEntry(id, count / total));
}
