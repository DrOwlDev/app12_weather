import 'bucket.dart';
import 'weather_event.dart';

enum BetStrategy { yesSingle, noBundle }

class BetRecommendation {
  const BetRecommendation({
    required this.event,
    required this.strategy,
    required this.targetBucket,
    required this.modelProbability,
    required this.entryCost,
    required this.expectedProfit,
    required this.effectiveEdge,
    required this.returnOnCost,
    this.noBuckets = const [],
    required this.cityStabilityScore,
    required this.confidenceNote,
  });

  final WeatherMarketEvent event;
  final BetStrategy strategy;
  final TemperatureBucket targetBucket;
  final double modelProbability;
  final double entryCost;
  final double expectedProfit;
  final double effectiveEdge;
  final double returnOnCost;
  final List<TemperatureBucket> noBuckets;
  final double cityStabilityScore;
  final String confidenceNote;

  String get strategyLabel {
    switch (strategy) {
      case BetStrategy.yesSingle:
        return 'YES on "${targetBucket.label}"';
      case BetStrategy.noBundle:
        return 'NO on all except "${targetBucket.label}"';
    }
  }

  bool get meetsMinEdge => effectiveEdge >= 0.07;
}
