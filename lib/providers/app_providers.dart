import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../data/web_snapshot_loader.dart';
import '../models/closing_bet_row.dart';
import '../models/weather_event.dart';
import '../services/closing_soon_scanner.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref);
});

class AppSettings {
  const AppSettings({
    this.closingWindowHours = defaultClosingWindowHours,
    this.minPrice = defaultClosingBetMinPrice,
    this.maxPrice = defaultClosingBetMaxPrice,
    this.refreshMinutes = defaultRefreshMinutes,
  });

  final int closingWindowHours;
  final double minPrice;
  final double maxPrice;
  final int refreshMinutes;

  AppSettings copyWith({
    int? closingWindowHours,
    double? minPrice,
    double? maxPrice,
    int? refreshMinutes,
  }) {
    return AppSettings(
      closingWindowHours: closingWindowHours ?? this.closingWindowHours,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      refreshMinutes: refreshMinutes ?? this.refreshMinutes,
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
      closingWindowHours:
          prefs.getInt('closing_window_hours') ?? defaultClosingWindowHours,
      minPrice: prefs.getDouble('closing_min_price') ?? defaultClosingBetMinPrice,
      maxPrice: prefs.getDouble('closing_max_price') ?? defaultClosingBetMaxPrice,
      refreshMinutes: prefs.getInt('refresh_minutes') ?? defaultRefreshMinutes,
    );
  }

  Future<void> setClosingWindowHours(int value) async {
    state = state.copyWith(closingWindowHours: value);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt('closing_window_hours', value);
  }

  Future<void> setMinPrice(double value) async {
    final newMin = value.clamp(0.50, 0.95);
    final newMax = newMin > state.maxPrice ? newMin : state.maxPrice;
    state = state.copyWith(minPrice: newMin, maxPrice: newMax);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setDouble('closing_min_price', newMin);
    await prefs.setDouble('closing_max_price', newMax);
  }

  Future<void> setMaxPrice(double value) async {
    final newMax = value.clamp(0.85, 0.99);
    final newMin = newMax < state.minPrice ? newMax : state.minPrice;
    state = state.copyWith(minPrice: newMin, maxPrice: newMax);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setDouble('closing_min_price', newMin);
    await prefs.setDouble('closing_max_price', newMax);
  }

  Future<void> setRefreshMinutes(int value) async {
    state = state.copyWith(refreshMinutes: value);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt('refresh_minutes', value);
  }

  Future<void> resetToDefaults() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    state = const AppSettings();
    await prefs.setInt('closing_window_hours', defaultClosingWindowHours);
    await prefs.setDouble('closing_min_price', defaultClosingBetMinPrice);
    await prefs.setDouble('closing_max_price', defaultClosingBetMaxPrice);
    await prefs.setInt('refresh_minutes', defaultRefreshMinutes);
  }
}

final closingSoonScannerProvider = Provider<ClosingSoonScanner>((ref) {
  final scanner = ClosingSoonScanner();
  ref.onDispose(scanner.dispose);
  return scanner;
});

final webSnapshotLoaderProvider = Provider<WebSnapshotLoader>((ref) {
  final loader = WebSnapshotLoader();
  ref.onDispose(loader.dispose);
  return loader;
});

final closingSoonProvider =
    AsyncNotifierProvider<ClosingSoonNotifier, ClosingSoonResult?>(
  ClosingSoonNotifier.new,
);

class ClosingSoonNotifier extends AsyncNotifier<ClosingSoonResult?> {
  List<ClosingBetRow>? _cachedWebRows;
  DateTime? _cachedWebGeneratedAt;
  List<WeatherMarketEvent>? _cachedEvents;

  @override
  Future<ClosingSoonResult?> build() async {
    ref.listen<AppSettings>(settingsProvider, (previous, next) {
      if (previous == null) return;
      if (kIsWeb && _cachedWebRows != null) {
        state = AsyncData(_filterWebRows(_cachedWebRows!, next));
      } else if (!kIsWeb && _cachedEvents != null) {
        state = AsyncData(_buildFromCachedEvents(next));
      }
    });
    return _scan();
  }

  Future<void> refresh() async {
    _cachedWebRows = null;
    _cachedEvents = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_scan);
  }

  Future<ClosingSoonResult?> _scan() async {
    final settings = ref.read(settingsProvider);

    if (kIsWeb) {
      final loader = ref.read(webSnapshotLoaderProvider);
      final snapshot = await loader.loadClosingBets();
      _cachedWebRows = snapshot.rows;
      _cachedWebGeneratedAt = snapshot.generatedAt;
      return _filterWebRows(snapshot.rows, settings);
    }

    final scanner = ref.read(closingSoonScannerProvider);
    _cachedEvents = await scanner.fetchEvents();
    return _buildFromCachedEvents(settings);
  }

  ClosingSoonResult _buildFromCachedEvents(AppSettings settings) {
    final events = _cachedEvents ?? [];
    final rows = buildClosingBetsFromEvents(
      events,
      closingWindowHours: settings.closingWindowHours,
      minPrice: settings.minPrice,
      maxPrice: settings.maxPrice,
    );
    return ClosingSoonResult(rows: rows, scannedAt: DateTime.now());
  }

  ClosingSoonResult _filterWebRows(List<ClosingBetRow> rows, AppSettings settings) {
    final filtered = filterClosingBetRows(
      rows,
      closingWindowHours: settings.closingWindowHours,
      minPrice: settings.minPrice,
      maxPrice: settings.maxPrice,
    );
    return ClosingSoonResult(
      rows: filtered,
      scannedAt: _cachedWebGeneratedAt ?? DateTime.now(),
    );
  }
}
