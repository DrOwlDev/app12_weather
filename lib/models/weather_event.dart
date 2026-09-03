import '../config/constants.dart';
import 'bucket.dart';
import 'closing_bet_row.dart';

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
    this.endDate,
    this.metric = TemperatureMetric.highest,
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
  final DateTime? endDate;
  final TemperatureMetric metric;
  final double? ensembleSpread;
  final double? metRunningMax;
  final bool isSameDay;

  String get polymarketUrl => '$polymarketEventUrl$slug';

  WeatherMarketEvent copyWith({
    List<TemperatureBucket>? buckets,
    double? ensembleSpread,
    double? metRunningMax,
    bool? isSameDay,
    String? icaoCode,
    double? latitude,
    double? longitude,
    DateTime? endDate,
    TemperatureMetric? metric,
  }) {
    return WeatherMarketEvent(
      id: id,
      slug: slug,
      title: title,
      city: city,
      targetDate: targetDate,
      buckets: buckets ?? this.buckets,
      resolutionSource: resolutionSource,
      icaoCode: icaoCode ?? this.icaoCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      volume24hr: volume24hr,
      endDate: endDate ?? this.endDate,
      metric: metric ?? this.metric,
      ensembleSpread: ensembleSpread ?? this.ensembleSpread,
      metRunningMax: metRunningMax ?? this.metRunningMax,
      isSameDay: isSameDay ?? this.isSameDay,
    );
  }
}
