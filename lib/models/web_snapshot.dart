import 'recommendation.dart';
import 'bucket.dart';
import 'weather_event.dart';
import '../services/history_tracker.dart';
import '../services/scanner_service.dart';

class WebScanSnapshot {
  const WebScanSnapshot({
    required this.generatedAt,
    required this.minEdge,
    required this.todayTomorrowOnly,
    required this.hideLockedAt100,
    required this.recommendations,
    required this.events,
  });

  final DateTime generatedAt;
  final double minEdge;
  final bool todayTomorrowOnly;
  final bool hideLockedAt100;
  final List<BetRecommendation> recommendations;
  final List<WeatherMarketEvent> events;

  ScannerResult toScannerResult() {
    return ScannerResult(
      recommendations: recommendations,
      events: events,
      scannedAt: generatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'minEdge': minEdge,
        'todayTomorrowOnly': todayTomorrowOnly,
        'hideLockedAt100': hideLockedAt100,
        'recommendations': recommendations.map(_recommendationToJson).toList(),
        'events': events.map(_eventToJson).toList(),
      };

  factory WebScanSnapshot.fromJson(Map<String, dynamic> json) {
    return WebScanSnapshot(
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      minEdge: (json['minEdge'] as num).toDouble(),
      todayTomorrowOnly: json['todayTomorrowOnly'] as bool,
      hideLockedAt100: json['hideLockedAt100'] as bool,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => _recommendationFromJson(e as Map<String, dynamic>))
          .toList(),
      events: (json['events'] as List<dynamic>)
          .map((e) => _eventFromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory WebScanSnapshot.fromScannerResult(
    ScannerResult result, {
    required double minEdge,
    required bool todayTomorrowOnly,
    required bool hideLockedAt100,
  }) {
    return WebScanSnapshot(
      generatedAt: result.scannedAt,
      minEdge: minEdge,
      todayTomorrowOnly: todayTomorrowOnly,
      hideLockedAt100: hideLockedAt100,
      recommendations: result.recommendations,
      events: result.events,
    );
  }
}

class WebStatsSnapshot {
  const WebStatsSnapshot({
    required this.generatedAt,
    required this.stats,
  });

  final DateTime generatedAt;
  final List<CityStats> stats;

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'stats': stats.map(_cityStatsToJson).toList(),
      };

  factory WebStatsSnapshot.fromJson(Map<String, dynamic> json) {
    return WebStatsSnapshot(
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      stats: (json['stats'] as List<dynamic>)
          .map((e) => _cityStatsFromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

Map<String, dynamic> _recommendationToJson(BetRecommendation rec) => {
      'strategy': rec.strategy.name,
      'targetBucket': _bucketToJson(rec.targetBucket),
      'modelProbability': rec.modelProbability,
      'entryCost': rec.entryCost,
      'expectedProfit': rec.expectedProfit,
      'effectiveEdge': rec.effectiveEdge,
      'returnOnCost': rec.returnOnCost,
      'noBuckets': rec.noBuckets.map(_bucketToJson).toList(),
      'cityStabilityScore': rec.cityStabilityScore,
      'confidenceNote': rec.confidenceNote,
      'event': _eventToJson(rec.event),
    };

BetRecommendation _recommendationFromJson(Map<String, dynamic> json) {
  return BetRecommendation(
    event: _eventFromJson(json['event'] as Map<String, dynamic>),
    strategy: BetStrategy.values.byName(json['strategy'] as String),
    targetBucket: _bucketFromJson(json['targetBucket'] as Map<String, dynamic>),
    modelProbability: (json['modelProbability'] as num).toDouble(),
    entryCost: (json['entryCost'] as num).toDouble(),
    expectedProfit: (json['expectedProfit'] as num).toDouble(),
    effectiveEdge: (json['effectiveEdge'] as num).toDouble(),
    returnOnCost: (json['returnOnCost'] as num).toDouble(),
    noBuckets: (json['noBuckets'] as List<dynamic>)
        .map((e) => _bucketFromJson(e as Map<String, dynamic>))
        .toList(),
    cityStabilityScore: (json['cityStabilityScore'] as num).toDouble(),
    confidenceNote: json['confidenceNote'] as String,
  );
}

Map<String, dynamic> _eventToJson(WeatherMarketEvent event) => {
      'id': event.id,
      'slug': event.slug,
      'title': event.title,
      'city': event.city,
      'targetDate': event.targetDate.toUtc().toIso8601String(),
      'buckets': event.buckets.map(_bucketToJson).toList(),
      'resolutionSource': event.resolutionSource,
      'icaoCode': event.icaoCode,
      'latitude': event.latitude,
      'longitude': event.longitude,
      'volume24hr': event.volume24hr,
      'ensembleSpread': event.ensembleSpread,
      'metRunningMax': event.metRunningMax,
      'isSameDay': event.isSameDay,
    };

WeatherMarketEvent _eventFromJson(Map<String, dynamic> json) {
  return WeatherMarketEvent(
    id: json['id'] as String,
    slug: json['slug'] as String,
    title: json['title'] as String,
    city: json['city'] as String,
    targetDate: DateTime.parse(json['targetDate'] as String),
    buckets: (json['buckets'] as List<dynamic>)
        .map((e) => _bucketFromJson(e as Map<String, dynamic>))
        .toList(),
    resolutionSource: json['resolutionSource'] as String,
    icaoCode: json['icaoCode'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    volume24hr: (json['volume24hr'] as num?)?.toDouble() ?? 0,
    ensembleSpread: (json['ensembleSpread'] as num?)?.toDouble(),
    metRunningMax: (json['metRunningMax'] as num?)?.toDouble(),
    isSameDay: json['isSameDay'] as bool? ?? false,
  );
}

Map<String, dynamic> _bucketToJson(TemperatureBucket bucket) => {
      'id': bucket.id,
      'label': bucket.label,
      'question': bucket.question,
      'minTemp': bucket.minTemp,
      'maxTemp': bucket.maxTemp,
      'unit': bucket.unit.name,
      'isOrBelow': bucket.isOrBelow,
      'isOrAbove': bucket.isOrAbove,
      'yesPrice': bucket.yesPrice,
      'noPrice': bucket.noPrice,
      'yesAsk': bucket.yesAsk,
      'noAsk': bucket.noAsk,
      'conditionId': bucket.conditionId,
      'yesTokenId': bucket.yesTokenId,
      'noTokenId': bucket.noTokenId,
      'modelProbability': bucket.modelProbability,
    };

TemperatureBucket _bucketFromJson(Map<String, dynamic> json) {
  return TemperatureBucket(
    id: json['id'] as String,
    label: json['label'] as String,
    question: json['question'] as String,
    minTemp: (json['minTemp'] as num?)?.toDouble(),
    maxTemp: (json['maxTemp'] as num?)?.toDouble(),
    unit: TemperatureUnit.values.byName(json['unit'] as String),
    isOrBelow: json['isOrBelow'] as bool,
    isOrAbove: json['isOrAbove'] as bool,
    yesPrice: (json['yesPrice'] as num).toDouble(),
    noPrice: (json['noPrice'] as num).toDouble(),
    yesAsk: (json['yesAsk'] as num?)?.toDouble(),
    noAsk: (json['noAsk'] as num?)?.toDouble(),
    conditionId: json['conditionId'] as String?,
    yesTokenId: json['yesTokenId'] as String?,
    noTokenId: json['noTokenId'] as String?,
    modelProbability: (json['modelProbability'] as num?)?.toDouble() ?? 0,
  );
}

Map<String, dynamic> _cityStatsToJson(CityStats stats) => {
      'city': stats.city,
      'totalMarkets': stats.totalMarkets,
      'modelCorrect': stats.modelCorrect,
      'yesWouldWin': stats.yesWouldWin,
      'noWouldWin': stats.noWouldWin,
    };

CityStats _cityStatsFromJson(Map<String, dynamic> json) {
  return CityStats(
    city: json['city'] as String,
    totalMarkets: json['totalMarkets'] as int,
    modelCorrect: json['modelCorrect'] as int,
    yesWouldWin: json['yesWouldWin'] as int,
    noWouldWin: json['noWouldWin'] as int,
  );
}
