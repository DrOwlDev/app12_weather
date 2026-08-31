import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/web_snapshot.dart';

class WebSnapshotLoader {
  WebSnapshotLoader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const scanPath = 'data/scan.json';
  static const statsPath = 'data/stats.json';

  Future<WebScanSnapshot> loadScan() async {
    final uri = Uri.base.resolve(scanPath);
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load web scan data (${response.statusCode}) from $uri',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return WebScanSnapshot.fromJson(json);
  }

  Future<WebStatsSnapshot> loadStats() async {
    final uri = Uri.base.resolve(statsPath);
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load web stats data (${response.statusCode}) from $uri',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return WebStatsSnapshot.fromJson(json);
  }

  void dispose() {
    _client.close();
  }

  static const _headers = {
    'Accept': 'application/json',
    'Cache-Control': 'no-cache',
  };
}
