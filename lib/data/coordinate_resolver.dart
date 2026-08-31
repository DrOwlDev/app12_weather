import 'dart:convert';

import 'package:http/http.dart' as http;

import 'stations.dart';

class ResolvedCoordinates {
  const ResolvedCoordinates({
    required this.latitude,
    required this.longitude,
    this.icaoCode = '',
  });

  final double latitude;
  final double longitude;
  final String icaoCode;

  bool get isValid => latitude != 0 || longitude != 0;
}

/// ICAO → lat/lon from the station registry (all known airports).
final icaoCoordinateRegistry = {
  for (final station in stationRegistry.values)
    station.icao: (station.latitude, station.longitude),
};

class CoordinateResolver {
  CoordinateResolver({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _geocodeCache = <String, ResolvedCoordinates>{};

  Future<ResolvedCoordinates> resolve({
    required String city,
    String icaoCode = '',
  }) async {
    final station = lookupStation(city);
    if (station != null) {
      return ResolvedCoordinates(
        latitude: station.latitude,
        longitude: station.longitude,
        icaoCode: station.icao,
      );
    }

    if (icaoCode.isNotEmpty) {
      final coords = icaoCoordinateRegistry[icaoCode.toUpperCase()];
      if (coords != null) {
        return ResolvedCoordinates(
          latitude: coords.$1,
          longitude: coords.$2,
          icaoCode: icaoCode.toUpperCase(),
        );
      }
    }

    final cacheKey = city.toLowerCase().trim();
    if (_geocodeCache.containsKey(cacheKey)) {
      return _geocodeCache[cacheKey]!;
    }

    final geocoded = await _geocodeCity(city);
    _geocodeCache[cacheKey] = geocoded;
    return geocoded;
  }

  Future<ResolvedCoordinates> _geocodeCity(String city) async {
    final uri = Uri.parse('https://geocoding-api.open-meteo.com/v1/search').replace(
      queryParameters: {
        'name': city,
        'count': '1',
        'language': 'en',
        'format': 'json',
      },
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return const ResolvedCoordinates(latitude: 0, longitude: 0);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        return const ResolvedCoordinates(latitude: 0, longitude: 0);
      }

      final first = results.first as Map<String, dynamic>;
      return ResolvedCoordinates(
        latitude: (first['latitude'] as num).toDouble(),
        longitude: (first['longitude'] as num).toDouble(),
      );
    } catch (_) {
      return const ResolvedCoordinates(latitude: 0, longitude: 0);
    }
  }

  void dispose() => _client.close();
}
