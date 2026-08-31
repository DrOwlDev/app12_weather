import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:app12_weather/config/constants.dart';
import 'package:app12_weather/models/web_snapshot.dart';
import 'package:app12_weather/services/scanner_service.dart';

/// CI entry point: writes pre-fetched scan data for GitHub Pages web builds.
///
/// Run with: flutter test test/export_web_data_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export web snapshots for GitHub Pages', () async {
    final service = ScannerService();
    addTearDown(service.dispose);

    final result = await service.scan(
      minEdge: 0,
      todayTomorrowOnly: defaultTodayTomorrowOnly,
      hideLockedAt100: defaultHideLockedAt100,
    );
    final stats = await service.fetchCityStats(refresh: true);

    final scanSnapshot = WebScanSnapshot.fromScannerResult(
      result,
      minEdge: 0,
      todayTomorrowOnly: defaultTodayTomorrowOnly,
      hideLockedAt100: defaultHideLockedAt100,
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

    expect(File('web_data/scan.json').existsSync(), isTrue);
    expect(File('web_data/stats.json').existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
