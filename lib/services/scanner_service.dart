import '../config/constants.dart';
import '../data/metar_client.dart';
import '../data/open_meteo_client.dart';
import '../data/polymarket_client.dart';
import '../models/recommendation.dart';
import '../models/weather_event.dart';
import 'city_ranker.dart';
import 'edge_calculator.dart';
import 'history_tracker.dart';
import 'market_filters.dart';
import 'probability_engine.dart';

class ScannerService {
  ScannerService({
    PolymarketClient? polymarketClient,
    OpenMeteoClient? meteoClient,
    MetarClient? metarClient,
    ProbabilityEngine? probabilityEngine,
    EdgeCalculator? edgeCalculator,
    CityRanker? cityRanker,
    HistoryTracker? historyTracker,
  })  : _polymarket = polymarketClient ?? PolymarketClient(),
        _meteo = meteoClient ?? OpenMeteoClient(),
        _metar = metarClient ?? MetarClient(),
        _probability = probabilityEngine ?? ProbabilityEngine(),
        _edge = edgeCalculator ?? EdgeCalculator(),
        _ranker = cityRanker ?? CityRanker(),
        _history = historyTracker ?? HistoryTracker();

  final PolymarketClient _polymarket;
  final OpenMeteoClient _meteo;
  final MetarClient _metar;
  final ProbabilityEngine _probability;
  final EdgeCalculator _edge;
  final CityRanker _ranker;
  final HistoryTracker _history;

  Future<ScannerResult> scan({
    double minEdge = defaultMinEdge,
    bool todayTomorrowOnly = defaultTodayTomorrowOnly,
    bool hideLockedAt100 = defaultHideLockedAt100,
  }) async {
    final cityWinRates = await _history.getCityWinRates();
    final rawEvents = todayTomorrowOnly
        ? await _polymarket.fetchTodayAndTomorrowEvents()
        : await _polymarket.fetchActiveTemperatureEvents();

    final eventsToScan = applyMarketFilters(
      rawEvents,
      todayTomorrowOnly: false,
      hideLockedAt100: hideLockedAt100,
    );
    final enrichedEvents = <WeatherMarketEvent>[];
    final recommendations = <BetRecommendation>[];

    for (final event in eventsToScan) {
      double? runningMax;
      if (event.isSameDay && event.icaoCode.isNotEmpty) {
        final unit = event.buckets.isNotEmpty
            ? event.buckets.first.unit
            : null;
        if (unit != null) {
          runningMax = await _metar.fetchRunningDailyMax(
            icao: event.icaoCode,
            targetDate: event.targetDate,
            unit: unit,
          );
        }
      }

      var enriched = await _probability.enrichEvent(
        event: event,
        meteoClient: _meteo,
        metRunningMax: runningMax,
      );

      if (enriched.latitude == 0 || enriched.longitude == 0) {
        continue;
      }

      enrichedEvents.add(enriched);

      final stability = _ranker.scoreEvent(
        enriched,
        cityWinRates: cityWinRates,
      );

      final rec = _edge.bestRecommendation(
        event: enriched,
        minEdge: minEdge,
        cityStabilityScore: stability,
      );
      if (rec != null) recommendations.add(rec);
    }

    recommendations.sort((a, b) {
      final edgeCmp = b.effectiveEdge.compareTo(a.effectiveEdge);
      if (edgeCmp != 0) return edgeCmp;
      return b.cityStabilityScore.compareTo(a.cityStabilityScore);
    });

    final rankedEvents = _ranker.rankEvents(
      enrichedEvents,
      cityWinRates: cityWinRates,
    );

    return ScannerResult(
      recommendations: recommendations,
      events: rankedEvents,
      scannedAt: DateTime.now(),
    );
  }

  Future<List<CityStats>> fetchCityStats({bool refresh = false}) async {
    if (refresh) await _history.clearCache();
    return _history.computeStats();
  }

  void dispose() {
    _polymarket.dispose();
    _meteo.dispose();
    _metar.dispose();
  }
}

class ScannerResult {
  const ScannerResult({
    required this.recommendations,
    required this.events,
    required this.scannedAt,
  });

  final List<BetRecommendation> recommendations;
  final List<WeatherMarketEvent> events;
  final DateTime scannedAt;
}
