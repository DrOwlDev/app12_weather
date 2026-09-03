import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/closing_bets_snapshot.dart';

class WebSnapshotLoader {
  WebSnapshotLoader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const closingBetsPath = 'data/closing_bets.json';

  Future<ClosingBetsSnapshot> loadClosingBets({bool bustCache = false}) async {
    var uri = Uri.base.resolve(closingBetsPath);
    if (bustCache) {
      uri = uri.replace(
        queryParameters: {
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
    }
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load closing bets data (${response.statusCode}) from $uri',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ClosingBetsSnapshot.fromJson(json);
  }

  void dispose() {
    _client.close();
  }

  static const _headers = {
    'Accept': 'application/json',
    'Cache-Control': 'no-cache',
  };
}
