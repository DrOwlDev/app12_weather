import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/bucket.dart';
import '../models/weather_event.dart';
import '../services/bucket_parser.dart';
import '../services/market_filters.dart';
import 'stations.dart';

class PolymarketClient {
  PolymarketClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<WeatherMarketEvent>> fetchActiveTemperatureEvents({
    int limit = maxEventsPerFetch,
    String? afterCursor,
  }) async {
    return _fetchEvents(
      closed: false,
      limit: limit,
      afterCursor: afterCursor,
    );
  }

  /// Paginates active events until all today/tomorrow markets are collected.
  Future<List<WeatherMarketEvent>> fetchTodayAndTomorrowEvents() async {
    final bySlug = <String, WeatherMarketEvent>{};
    String? cursor;

    for (var page = 0; page < maxEventPages; page++) {
      final batch = await fetchActiveTemperatureEvents(
        limit: maxEventsPerFetch,
        afterCursor: cursor,
      );
      if (batch.isEmpty) break;

      for (final event in batch) {
        if (isTodayOrTomorrow(event.targetDate)) {
          bySlug[event.slug] = event;
        }
      }

      if (batch.length < maxEventsPerFetch) break;
      cursor = batch.last.id;
    }

    final results = bySlug.values.toList()
      ..sort((a, b) {
        final dateCmp = a.targetDate.compareTo(b.targetDate);
        if (dateCmp != 0) return dateCmp;
        return b.volume24hr.compareTo(a.volume24hr);
      });
    return results;
  }

  Future<List<WeatherMarketEvent>> fetchClosedTemperatureEvents({
    int limit = 100,
    String? afterCursor,
  }) async {
    return _fetchEvents(
      closed: true,
      limit: limit,
      afterCursor: afterCursor,
    );
  }

  Future<List<WeatherMarketEvent>> _fetchEvents({
    required bool closed,
    required int limit,
    String? afterCursor,
  }) async {
    final params = <String, String>{
      'closed': closed.toString(),
      'tag_slug': 'daily-temperature',
      'order': closed ? 'endDate' : 'volume24hr',
      'ascending': 'false',
      'limit': limit.toString(),
    };
    if (afterCursor != null) {
      params['after_cursor'] = afterCursor;
    }

    final uri = Uri.parse('$gammaApiBase/events').replace(queryParameters: params);
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Gamma API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    final events = <WeatherMarketEvent>[];
    for (final raw in data) {
      final event = _parseEvent(raw as Map<String, dynamic>);
      if (event != null) events.add(event);
    }
    return events;
  }

  WeatherMarketEvent? _parseEvent(Map<String, dynamic> raw) {
    final title = (raw['title'] as String?) ?? '';
    if (!title.toLowerCase().contains('temperature')) return null;
    if (!title.toLowerCase().contains('highest')) return null;

    final city = extractCityFromTitle(title);
    final targetDate = extractDateFromTitle(title) ?? DateTime.now();
    final station = lookupStation(city);

    final markets = raw['markets'] as List<dynamic>? ?? [];
    final buckets = <TemperatureBucket>[];
    String resolutionSource = station?.resolutionSource ?? '';
    String icao = station?.icao ?? '';
    double lat = station?.latitude ?? 0;
    double lon = station?.longitude ?? 0;

    for (final marketRaw in markets) {
      final market = marketRaw as Map<String, dynamic>;
      final bucket = parseBucketFromMarket(market: market);
      if (bucket != null) buckets.add(bucket);

      final desc = (market['description'] as String?) ?? '';
      final source = (market['resolutionSource'] as String?) ?? desc;
      if (source.isNotEmpty) resolutionSource = source;
      final extracted = extractIcaoFromText('$desc $source');
      if (extracted != null) icao = extracted;
    }

    if (buckets.isEmpty) return null;

    final slug = (raw['slug'] as String?) ?? '';
    final volume = _sumVolume(markets);

    return WeatherMarketEvent(
      id: (raw['id'] ?? slug).toString(),
      slug: slug,
      title: title,
      city: city,
      targetDate: targetDate,
      buckets: buckets,
      resolutionSource: resolutionSource,
      icaoCode: icao,
      latitude: lat,
      longitude: lon,
      volume24hr: volume,
      isSameDay: _isSameDay(targetDate),
    );
  }

  double _sumVolume(List<dynamic> markets) {
    var total = 0.0;
    for (final m in markets) {
      final map = m as Map<String, dynamic>;
      total += _toDouble(map['volume24hr']);
    }
    return total;
  }

  bool _isSameDay(DateTime target) {
    final now = DateTime.now();
    return target.year == now.year &&
        target.month == now.month &&
        target.day == now.day;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Map<String, String> get _headers => const {
        'Accept': 'application/json',
        'User-Agent': 'PolymarketWeatherScanner/1.0',
      };

  void dispose() => _client.close();
}
