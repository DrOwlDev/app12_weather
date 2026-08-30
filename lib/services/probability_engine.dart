import '../data/open_meteo_client.dart';
import '../models/weather_event.dart';

class ProbabilityEngine {
  Future<WeatherMarketEvent> enrichEvent({
    required WeatherMarketEvent event,
    required OpenMeteoClient meteoClient,
    double? metRunningMax,
  }) async {
    if (event.buckets.isEmpty) return event;

    final unit = event.buckets.first.unit;
    final forecast = await meteoClient.fetchDailyMaxEnsemble(
      latitude: event.latitude,
      longitude: event.longitude,
      targetDate: event.targetDate,
      unit: unit,
    );

    if (forecast == null) return event;

    final probs = bucketProbabilitiesFromEnsemble(
      buckets: event.buckets,
      memberMaxTemps: forecast.memberMaxTemps,
      runningMaxObserved: metRunningMax,
    );

    final enrichedBuckets = event.buckets
        .map((b) => b.copyWith(modelProbability: probs[b.id] ?? 0))
        .toList();

    return event.copyWith(
      buckets: enrichedBuckets,
      ensembleSpread: forecast.ensembleSpread,
      metRunningMax: metRunningMax,
      isSameDay: event.isSameDay,
    );
  }
}

String confidenceNoteForEvent(WeatherMarketEvent event) {
  if (event.isSameDay && DateTime.now().hour < 14) {
    return 'Same-day market before 2pm local — daily high may not be set yet.';
  }
  if ((event.ensembleSpread ?? 99) < 0.8) {
    return 'Tight ensemble consensus — higher confidence.';
  }
  if ((event.ensembleSpread ?? 0) > 2.0) {
    return 'Wide ensemble spread — models disagree.';
  }
  if (event.metRunningMax != null) {
    return 'METAR running max incorporated for same-day nowcast.';
  }
  return 'Standard ensemble forecast.';
}
