import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../data/web_snapshot_loader.dart';
import '../models/recommendation.dart';
import '../models/weather_event.dart';
import '../services/history_tracker.dart';
import '../services/market_filters.dart';
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
    this.showYesterday = defaultShowYesterday,
    this.showToday = defaultShowToday,
    this.showTomorrow = defaultShowTomorrow,
    this.hideLockedAt100 = defaultHideLockedAt100,
    this.hideZeroPriceBuckets = defaultHideZeroPriceBuckets,
  });

  final double minEdge;
  final int refreshMinutes;
  final List<String> preferredCities;
  final bool showYesterday;
  final bool showToday;
  final bool showTomorrow;
  final bool hideLockedAt100;
  final bool hideZeroPriceBuckets;

  DateWindowFilter get dateFilter => DateWindowFilter(
        showYesterday: showYesterday,
        showToday: showToday,
        showTomorrow: showTomorrow,
      );

  AppSettings copyWith({
    double? minEdge,
    int? refreshMinutes,
    List<String>? preferredCities,
    bool? showYesterday,
    bool? showToday,
    bool? showTomorrow,
    bool? hideLockedAt100,
    bool? hideZeroPriceBuckets,
  }) {
    return AppSettings(
      minEdge: minEdge ?? this.minEdge,
      refreshMinutes: refreshMinutes ?? this.refreshMinutes,
      preferredCities: preferredCities ?? this.preferredCities,
      showYesterday: showYesterday ?? this.showYesterday,
      showToday: showToday ?? this.showToday,
      showTomorrow: showTomorrow ?? this.showTomorrow,
      hideLockedAt100: hideLockedAt100 ?? this.hideLockedAt100,
      hideZeroPriceBuckets: hideZeroPriceBuckets ?? this.hideZeroPriceBuckets,
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

    // Migrate legacy today_tomorrow_only → separate day toggles.
    final legacyTodayTomorrow = prefs.getBool('today_tomorrow_only');
    if (legacyTodayTomorrow != null &&
        !prefs.containsKey('show_yesterday') &&
        !prefs.containsKey('show_today') &&
        !prefs.containsKey('show_tomorrow')) {
      final allDays = legacyTodayTomorrow;
      await prefs.setBool('show_yesterday', allDays);
      await prefs.setBool('show_today', allDays);
      await prefs.setBool('show_tomorrow', allDays);
      await prefs.remove('today_tomorrow_only');
    }

    state = AppSettings(
      minEdge: prefs.getDouble('min_edge') ?? defaultMinEdge,
      refreshMinutes: prefs.getInt('refresh_minutes') ?? defaultRefreshMinutes,
      preferredCities: prefs.getStringList('preferred_cities') ?? [],
      showYesterday: prefs.getBool('show_yesterday') ?? defaultShowYesterday,
      showToday: prefs.getBool('show_today') ?? defaultShowToday,
      showTomorrow: prefs.getBool('show_tomorrow') ?? defaultShowTomorrow,
      hideLockedAt100:
          prefs.getBool('hide_locked_at_100') ?? defaultHideLockedAt100,
      hideZeroPriceBuckets: prefs.getBool('hide_zero_price_buckets') ??
          defaultHideZeroPriceBuckets,
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

  Future<void> setShowYesterday(bool value) async {
    state = state.copyWith(showYesterday: value);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('show_yesterday', value);
  }

  Future<void> setShowToday(bool value) async {
    state = state.copyWith(showToday: value);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('show_today', value);
  }

  Future<void> setShowTomorrow(bool value) async {
    state = state.copyWith(showTomorrow: value);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('show_tomorrow', value);
  }

  Future<void> setHideLockedAt100(bool value) async {
    state = state.copyWith(hideLockedAt100: value);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('hide_locked_at_100', value);
  }

  Future<void> setHideZeroPriceBuckets(bool value) async {
    state = state.copyWith(hideZeroPriceBuckets: value);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('hide_zero_price_buckets', value);
  }

  Future<void> resetToDefaults() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    state = const AppSettings();
    await prefs.setDouble('min_edge', defaultMinEdge);
    await prefs.setInt('refresh_minutes', defaultRefreshMinutes);
    await prefs.setStringList('preferred_cities', []);
    await prefs.setBool('show_yesterday', defaultShowYesterday);
    await prefs.setBool('show_today', defaultShowToday);
    await prefs.setBool('show_tomorrow', defaultShowTomorrow);
    await prefs.setBool('hide_locked_at_100', defaultHideLockedAt100);
    await prefs.setBool('hide_zero_price_buckets', defaultHideZeroPriceBuckets);
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
            dateFilter: settings.dateFilter,
            hideLockedAt100: settings.hideLockedAt100,
            hideZeroPriceBuckets: settings.hideZeroPriceBuckets,
          );
    }

    return _applyClientFilters(result, settings);
  }

  ScannerResult _applyClientFilters(ScannerResult result, AppSettings settings) {
    var events = result.events;
    var recommendations = result.recommendations;

    if (kIsWeb) {
      events = applyMarketFilters(
        events,
        dateFilter: settings.dateFilter,
        hideLockedAt100: settings.hideLockedAt100,
        hideZeroPriceBuckets: settings.hideZeroPriceBuckets,
      );
      recommendations = recommendations
          .where((r) => r.effectiveEdge >= settings.minEdge)
          .where((r) => settings.dateFilter.matches(r.event.targetDate))
          .where((r) {
            if (settings.hideLockedAt100 && isLockedAt100(r.event)) {
              return false;
            }
            return true;
          })
          .where((r) {
            if (settings.hideZeroPriceBuckets &&
                isZeroPriceBucket(r.targetBucket)) {
              return false;
            }
            return true;
          })
          .toList();
    }

    if (settings.preferredCities.isEmpty) {
      return ScannerResult(
        recommendations: recommendations,
        events: events,
        scannedAt: result.scannedAt,
      );
    }

    final preferred = settings.preferredCities.map((c) => c.toLowerCase()).toSet();
    final filteredRecs = recommendations
        .where((r) => preferred.any((p) => r.event.city.toLowerCase().contains(p)))
        .toList();
    final filteredEvents = events
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
