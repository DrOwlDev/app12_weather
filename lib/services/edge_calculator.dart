import '../models/bucket.dart';
import '../models/recommendation.dart';
import '../models/weather_event.dart';
import 'probability_engine.dart';

class EdgeCalculator {
  List<BetRecommendation> evaluate({
    required WeatherMarketEvent event,
    required double minEdge,
    required double cityStabilityScore,
  }) {
    if (event.buckets.isEmpty) return [];

    final favorite = event.favoriteBucket;
    if (favorite == null || favorite.modelProbability <= 0) return [];

    final confidenceNote = confidenceNoteForEvent(event);
    final recommendations = <BetRecommendation>[];

    final yesRec = _evaluateYes(
      event: event,
      bucket: favorite,
      minEdge: minEdge,
      cityStabilityScore: cityStabilityScore,
      confidenceNote: confidenceNote,
    );
    if (yesRec != null) recommendations.add(yesRec);

    final noRec = _evaluateNoBundle(
      event: event,
      winnerBucket: favorite,
      minEdge: minEdge,
      cityStabilityScore: cityStabilityScore,
      confidenceNote: confidenceNote,
    );
    if (noRec != null) recommendations.add(noRec);

    recommendations.sort((a, b) => b.returnOnCost.compareTo(a.returnOnCost));
    return recommendations;
  }

  BetRecommendation? _evaluateYes({
    required WeatherMarketEvent event,
    required TemperatureBucket bucket,
    required double minEdge,
    required double cityStabilityScore,
    required String confidenceNote,
  }) {
    final modelProb = bucket.modelProbability;
    final entry = bucket.effectiveYesAsk;
    if (entry <= 0 || entry >= 1) return null;

    final effectiveEdge = modelProb - entry;
    final expectedProfit = modelProb * (1 - entry) - (1 - modelProb) * entry;
    final returnOnCost = expectedProfit / entry;

    if (effectiveEdge < minEdge) return null;

    return BetRecommendation(
      event: event,
      strategy: BetStrategy.yesSingle,
      targetBucket: bucket,
      modelProbability: modelProb,
      entryCost: entry,
      expectedProfit: expectedProfit,
      effectiveEdge: effectiveEdge,
      returnOnCost: returnOnCost,
      cityStabilityScore: cityStabilityScore,
      confidenceNote: confidenceNote,
    );
  }

  BetRecommendation? _evaluateNoBundle({
    required WeatherMarketEvent event,
    required TemperatureBucket winnerBucket,
    required double minEdge,
    required double cityStabilityScore,
    required String confidenceNote,
  }) {
    final winProb = winnerBucket.modelProbability;
    if (winProb <= 0) return null;

    final noBuckets =
        event.buckets.where((b) => b.id != winnerBucket.id).toList();
    if (noBuckets.isEmpty) return null;

    var totalCost = 0.0;

    for (final bucket in noBuckets) {
      final noAsk = bucket.effectiveNoAsk;
      if (noAsk <= 0 || noAsk >= 1) continue;
      totalCost += noAsk;
    }

    if (totalCost <= 0) return null;

    // If winner hits, each NO share pays $1 (profit = 1 - cost per share).
    var evIfWin = 0.0;
    for (final bucket in noBuckets) {
      evIfWin += 1 - bucket.effectiveNoAsk;
    }
    final expectedProfit = winProb * evIfWin - totalCost;
    final returnOnCost = expectedProfit / totalCost;
    final effectiveEdge = returnOnCost;

    if (effectiveEdge < minEdge) return null;

    return BetRecommendation(
      event: event,
      strategy: BetStrategy.noBundle,
      targetBucket: winnerBucket,
      modelProbability: winProb,
      entryCost: totalCost,
      expectedProfit: expectedProfit,
      effectiveEdge: effectiveEdge,
      returnOnCost: returnOnCost,
      noBuckets: noBuckets,
      cityStabilityScore: cityStabilityScore,
      confidenceNote: confidenceNote,
    );
  }

  BetRecommendation? bestRecommendation({
    required WeatherMarketEvent event,
    required double minEdge,
    required double cityStabilityScore,
  }) {
    final all = evaluate(
      event: event,
      minEdge: minEdge,
      cityStabilityScore: cityStabilityScore,
    );
    return all.isEmpty ? null : all.first;
  }
}
