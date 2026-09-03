import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app12_weather/config/constants.dart';
import 'package:app12_weather/models/closing_bets_snapshot.dart';
import 'package:app12_weather/services/closing_soon_scanner.dart';

/// CI entry point: writes pre-fetched closing-bet data for GitHub Pages web builds.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final scanner = ClosingSoonScanner();
  try {
    final events = await scanner.fetchEvents();
    final rows = buildClosingBetsFromEvents(
      events,
      closingWindowHours: exportClosingWindowHours,
      minPrice: 0.01,
      maxPrice: 0.99,
    );

    final snapshot = ClosingBetsSnapshot(
      generatedAt: DateTime.now(),
      rows: rows,
    );

    final outputDir = Directory('web_data');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    File('web_data/closing_bets.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );

    stdout.writeln(
      'Exported ${rows.length} closing bet rows from ${events.length} events.',
    );
  } finally {
    scanner.dispose();
  }

  exit(0);
}
