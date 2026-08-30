import 'bucket.dart';

class WeatherMarketEvent {
  const WeatherMarketEvent({
    required this.id,
    required this.slug,
    required this.title,
    required this.city,
    required this.targetDate,
    required this.buckets,
    required this.resolutionSource,
    required this.icaoCode,
    required this.latitude,
    required this.longitude,
    this.volume24hr = 0,
    this.ensembleSpread,
    this.metRunningMax,
    this.isSameDay = false,
  });

  final String id;
  final String slug;
  final String title;
  final String city;
  final DateTime targetDate;
  final List<TemperatureBucket> buckets;
  final String resolutionSource;
  final String icaoCode;
  final double latitude;
  final double longitude;
  final double volume24hr;
  final double? ensembleSpread;
  final double? metRunningMax;
  final bool isSameDay;

  String get polymarketUrl => 'https://polymarket.com/event/$slug';

  TemperatureBucket? get favoriteBucket {
    if (buckets.isEmpty) return null;
    return buckets.reduce(
      (a, b) => a.modelProbability >= b.modelProbability ? a : b,
    );
  }

  WeatherMarketEvent copyWith({
    List<TemperatureBucket>? buckets,
    double? ensembleSpread,
    double? metRunningMax,
    bool? isSameDay,
  }) {
    return WeatherMarketEvent(
      id: id,
      slug: slug,
      title: title,
      city: city,
      targetDate: targetDate,
      buckets: buckets ?? this.buckets,
      resolutionSource: resolutionSource,
      icaoCode: icaoCode,
      latitude: latitude,
      longitude: longitude,
      volume24hr: volume24hr,
      ensembleSpread: ensembleSpread ?? this.ensembleSpread,
      metRunningMax: metRunningMax ?? this.metRunningMax,
      isSameDay: isSameDay ?? this.isSameDay,
    );
  }
}
