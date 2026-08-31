import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../data/web_snapshot_loader.dart';
import '../models/recommendation.dart';
import '../models/weather_event.dart';
import '../services/history_tracker.dart';
import '../services/scanner_service.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref);
});

class AppSettings {
  const AppSettings({
    this.minEdge = defaultMinEdge,
    this.refreshMinutes = defaultRefreshMinutes,
    this.preferredCities = const [],
    this.todayTomorrowOnly = defaultTodayTomorrowOnly,
    this.hideLockedAt100 = defaultHideLockedAt100,
  });

  final double minEdge;
  final int refreshMinutes;
  final List<String> preferredCities;
  final bool todayTomorrowOnly;
  final bool hideLockedAt100;

  AppSettings copyWith({
    double? minEdge,
    int? refreshMinutes,
    List<String>? preferredCities,
    bool? todayTomorrowOnly,
    bool? hideLockedAt100,
  }) {
    return AppSettings(
      minEdge: minEdge ?? this.minEdge,
      refreshMinutes: refreshMinutes ?? this.refreshMinutes,
      preferredCities: preferredCities ?? this.preferredCities,
      todayTomorrowOnly: todayTomorrowOnly ?? this.todayTomorrowOnly,
      hideLockedAt100: hideLockedAt100 ?? this.hideLockedAt100,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this.ref) : super(const AppSettings()) {
    _load();
  }

  final Ref ref;

  Future<void> _load() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    state = AppSettings(
      minEdge: prefs.getDouble('min_edge') ?? defaultMinEdge,
      refreshMinutes: prefs.getInt('refresh_minutes') ?? defaultRefreshMinutes,
      preferredCities: prefs.getStringList('preferred_cities') ?? [],
      todayTomorrowOnly:
          prefs.getBool('today_tomorrow_only') ?? defaultTodayTomorrowOnly,
      hideLockedAt100:
          prefs.getBool('hide_locked_at_100') ?? defaultHideLockedAt100,
    );
  }

  Future<void> setMinEdge(double value) async {
    state = state.copyWith(minEdge: value);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setDouble('min_edge', value);
  }

  Future<void> setRefreshMinutes(int value) async {
    state = state.copyWith(refreshMinutes: value);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt('refresh_minutes', value);
  }

  Future<void> setPreferredCities(List<String> cities) async {
    state = state.copyWith(preferredCities: cities);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setStringList('preferred_cities', cities);
  }

  Future<void> setTodayTomorrowOnly(bool value) async {
    state = state.copyWith(todayTomorrowOnly: value);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('today_tomorrow_only', value);
  }

  Future<void> setHideLockedAt100(bool value) async {
    state = state.copyWith(hideLockedAt100: value);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('hide_locked_at_100', value);
  }
}

final scannerServiceProvider = Provider<ScannerService>((ref) {
  final service = ScannerService();
  ref.onDispose(service.dispose);
  return service;
});

final webSnapshotLoaderProvider = Provider<WebSnapshotLoader>((ref) {
  final loader = WebSnapshotLoader();
  ref.onDispose(loader.dispose);
  return loader;
});

final scannerProvider =
    AsyncNotifierProvider<ScannerNotifier, ScannerResult?>(ScannerNotifier.new);

class ScannerNotifier extends AsyncNotifier<ScannerResult?> {
  @override
  Future<ScannerResult?> build() async {
    return _scan();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_scan);
  }

  Future<ScannerResult?> _scan() async {
    final settings = ref.read(settingsProvider);

    final ScannerResult result;
    if (kIsWeb) {
      final loader = ref.read(webSnapshotLoaderProvider);
      final snapshot = await loader.loadScan();
      result = snapshot.toScannerResult();
    } else {
      result = await ref.read(scannerServiceProvider).scan(
            minEdge: settings.minEdge,
            todayTomorrowOnly: settings.todayTomorrowOnly,
            hideLockedAt100: settings.hideLockedAt100,
          );
    }

    return _applyClientFilters(result, settings);
  }

  ScannerResult _applyClientFilters(ScannerResult result, AppSettings settings) {
    var recommendations = result.recommendations;
    if (kIsWeb) {
      recommendations = recommendations
          .where((r) => r.effectiveEdge >= settings.minEdge)
          .toList();
    }

    if (settings.preferredCities.isEmpty) {
      return ScannerResult(
        recommendations: recommendations,
        events: result.events,
        scannedAt: result.scannedAt,
      );
    }

    final preferred = settings.preferredCities.map((c) => c.toLowerCase()).toSet();
    final filteredRecs = recommendations
        .where((r) => preferred.any((p) => r.event.city.toLowerCase().contains(p)))
        .toList();
    final filteredEvents = result.events
        .where((e) => preferred.any((p) => e.city.toLowerCase().contains(p)))
        .toList();

    return ScannerResult(
      recommendations: filteredRecs,
      events: filteredEvents,
      scannedAt: result.scannedAt,
    );
  }
}

final cityStatsProvider =
    AsyncNotifierProvider<CityStatsNotifier, List<CityStats>>(CityStatsNotifier.new);

class CityStatsNotifier extends AsyncNotifier<List<CityStats>> {
  @override
  Future<List<CityStats>> build() async {
    if (kIsWeb) {
      final loader = ref.read(webSnapshotLoaderProvider);
      final snapshot = await loader.loadStats();
      return snapshot.stats;
    }
    final service = ref.read(scannerServiceProvider);
    return service.fetchCityStats();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (kIsWeb) {
        final loader = ref.read(webSnapshotLoaderProvider);
        final snapshot = await loader.loadStats();
        return snapshot.stats;
      }
      final service = ref.read(scannerServiceProvider);
      return service.fetchCityStats(refresh: true);
    });
  }
}

final selectedEventProvider = StateProvider<WeatherMarketEvent?>((ref) => null);

final selectedRecommendationProvider =
    StateProvider<BetRecommendation?>((ref) => null);
