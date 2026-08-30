import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/polymarket_client.dart';
import '../models/bucket.dart';
import '../models/weather_event.dart';

class CityStats {
  const CityStats({
    required this.city,
    required this.totalMarkets,
    required this.modelCorrect,
    required this.yesWouldWin,
    required this.noWouldWin,
  });

  final String city;
  final int totalMarkets;
  final int modelCorrect;
  final int yesWouldWin;
  final int noWouldWin;

  double get modelAccuracy =>
      totalMarkets > 0 ? modelCorrect / totalMarkets : 0;

  double get yesWinRate => totalMarkets > 0 ? yesWouldWin / totalMarkets : 0;

  double get noWinRate => totalMarkets > 0 ? noWouldWin / totalMarkets : 0;
}

class HistoryTracker {
  HistoryTracker({
    PolymarketClient? client,
    SharedPreferences? prefs,
  })  : _client = client ?? PolymarketClient(),
        _prefs = prefs;

  final PolymarketClient _client;
  SharedPreferences? _prefs;

  static const _cacheKey = 'history_stats_v1';

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> init() async {
    await _ensurePrefs();
  }

  Future<Map<String, double>> getCityWinRates() async {
    final stats = await computeStats();
    return {
      for (final s in stats) s.city.toLowerCase(): s.modelAccuracy,
    };
  }

  Future<List<CityStats>> computeStats() async {
    final prefs = await _ensurePrefs();
    final cached = _readCache(prefs);
    if (cached != null) return cached;

    final events = await _client.fetchClosedTemperatureEvents(limit: 100);
    final byCity = <String, _CityAccumulator>{};

    for (final event in events) {
      final winner = _resolvedWinner(event);
      if (winner == null) continue;

      final favorite = event.buckets.reduce(
        (a, b) => a.yesPrice >= b.yesPrice ? a : b,
      );

      final acc = byCity.putIfAbsent(
        event.city,
        () => _CityAccumulator(event.city),
      );
      acc.total += 1;
      if (favorite.id == winner.id) acc.modelCorrect += 1;
      if (winner.yesPrice > 0.9) acc.yesWouldWin += 1;
      final losers = event.buckets.where((b) => b.id != winner.id);
      if (losers.every((b) => b.noPrice > 0.9 || b.yesPrice < 0.05)) {
        acc.noWouldWin += 1;
      }
    }

    final stats = byCity.values
        .map(
          (a) => CityStats(
            city: a.city,
            totalMarkets: a.total,
            modelCorrect: a.modelCorrect,
            yesWouldWin: a.yesWouldWin,
            noWouldWin: a.noWouldWin,
          ),
        )
        .toList()
      ..sort((a, b) => b.modelAccuracy.compareTo(a.modelAccuracy));

    await _writeCache(stats, prefs);
    return stats;
  }

  TemperatureBucket? _resolvedWinner(WeatherMarketEvent event) {
    for (final bucket in event.buckets) {
      if (bucket.yesPrice > 0.95) return bucket;
    }
    return null;
  }

  List<CityStats>? _readCache(SharedPreferences prefs) {
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => CityStats(
              city: e['city'] as String,
              totalMarkets: e['totalMarkets'] as int,
              modelCorrect: e['modelCorrect'] as int,
              yesWouldWin: e['yesWouldWin'] as int,
              noWouldWin: e['noWouldWin'] as int,
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(List<CityStats> stats, SharedPreferences prefs) async {
    final encoded = jsonEncode(
      stats
          .map(
            (s) => {
              'city': s.city,
              'totalMarkets': s.totalMarkets,
              'modelCorrect': s.modelCorrect,
              'yesWouldWin': s.yesWouldWin,
              'noWouldWin': s.noWouldWin,
            },
          )
          .toList(),
    );
    await prefs.setString(_cacheKey, encoded);
  }

  Future<void> clearCache() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_cacheKey);
  }
}

class _CityAccumulator {
  _CityAccumulator(this.city);

  final String city;
  int total = 0;
  int modelCorrect = 0;
  int yesWouldWin = 0;
  int noWouldWin = 0;
}
