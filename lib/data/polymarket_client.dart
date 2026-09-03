import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/bucket.dart';
import '../models/weather_event.dart';
import '../services/bucket_parser.dart';
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

  /// Paginates all active daily-temperature events (highest and lowest).
  Future<List<WeatherMarketEvent>> fetchAllActiveTemperatureEvents() async {
    final bySlug = <String, WeatherMarketEvent>{};
    String? cursor;

    for (var page = 0; page < maxEventPages; page++) {
      final batch = await fetchActiveTemperatureEvents(
        limit: maxEventsPerFetch,
        afterCursor: cursor,
      );
      if (batch.isEmpty) break;

      for (final event in batch) {
        bySlug[event.slug] = event;
      }

      if (batch.length < maxEventsPerFetch) break;
      cursor = batch.last.id;
    }

    return bySlug.values.toList()
      ..sort((a, b) {
        final endA = a.endDate ?? a.targetDate;
        final endB = b.endDate ?? b.targetDate;
        final endCmp = endA.compareTo(endB);
        if (endCmp != 0) return endCmp;
        return a.city.compareTo(b.city);
      });
  }

  Future<List<WeatherMarketEvent>> _fetchEvents({
    required bool closed,
    required int limit,
    String? afterCursor,
  }) async {
    final params = <String, String>{
      'closed': closed.toString(),
      'tag_slug': 'daily-temperature',
      'order': closed ? 'endDate' : 'endDate',
      'ascending': closed ? 'false' : 'true',
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
    final lower = title.toLowerCase();
    if (!lower.contains('temperature')) return null;
    if (!lower.contains('highest') && !lower.contains('lowest')) return null;

    final city = extractCityFromTitle(title);
    final targetDate = extractDateFromTitle(title) ?? DateTime.now();
    final metric = extractMetricFromTitle(title);
    final station = lookupStation(city);

    final eventEndDate = _parseEndDate(raw);

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
      endDate: eventEndDate,
      metric: metric,
      isSameDay: dateOnly(targetDate) == dateOnly(DateTime.now()),
    );
  }

  DateTime? _parseEndDate(Map<String, dynamic> raw) {
    final iso = raw['endDateIso'] as String?;
    if (iso != null && iso.isNotEmpty) {
      return DateTime.tryParse(iso);
    }
    final end = raw['endDate'] as String?;
    if (end != null && end.isNotEmpty) {
      return DateTime.tryParse(end);
    }
    return null;
  }

  double _sumVolume(List<dynamic> markets) {
    var total = 0.0;
    for (final m in markets) {
      final map = m as Map<String, dynamic>;
      total += _toDouble(map['volume24hr']);
    }
    return total;
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
