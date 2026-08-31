import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app12_weather/config/constants.dart';
import 'package:app12_weather/models/web_snapshot.dart';
import 'package:app12_weather/services/market_filters.dart';
import 'package:app12_weather/services/scanner_service.dart';

/// CI entry point: writes pre-fetched scan data for GitHub Pages web builds.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const exportDateFilter = DateWindowFilter(
    showYesterday: true,
    showToday: true,
    showTomorrow: true,
  );

  final service = ScannerService();
  try {
    final result = await service.scan(
      minEdge: 0,
      dateFilter: exportDateFilter,
      hideLockedAt100: false,
      hideZeroPriceBuckets: false,
    );
    final stats = await service.fetchCityStats(refresh: true);

    final scanSnapshot = WebScanSnapshot.fromScannerResult(
      result,
      minEdge: 0,
      dateFilter: exportDateFilter,
      hideLockedAt100: defaultHideLockedAt100,
      hideZeroPriceBuckets: defaultHideZeroPriceBuckets,
    );
    final statsSnapshot = WebStatsSnapshot(
      generatedAt: DateTime.now(),
      stats: stats,
    );

    final outputDir = Directory('web_data');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    File('web_data/scan.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(scanSnapshot.toJson()),
    );
    File('web_data/stats.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(statsSnapshot.toJson()),
    );

    stdout.writeln(
      'Exported ${result.recommendations.length} recommendations, '
      '${result.events.length} events, and ${stats.length} city stats.',
    );
  } finally {
    service.dispose();
  }

  exit(0);
}
