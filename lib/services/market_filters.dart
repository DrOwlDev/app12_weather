import '../config/constants.dart';
import '../models/bucket.dart';
import '../models/weather_event.dart';

/// Calendar date without time (local timezone).
DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

bool isYesterday(DateTime target) {
  final now = DateTime.now();
  return dateOnly(target) == dateOnly(now).subtract(const Duration(days: 1));
}

bool isToday(DateTime target) {
  final now = DateTime.now();
  return dateOnly(target) == dateOnly(now);
}

bool isTomorrow(DateTime target) {
  final now = DateTime.now();
  return dateOnly(target) == dateOnly(now).add(const Duration(days: 1));
}

bool isTodayOrTomorrow(DateTime target) => isToday(target) || isTomorrow(target);

class DateWindowFilter {
  const DateWindowFilter({
    this.showYesterday = defaultShowYesterday,
    this.showToday = defaultShowToday,
    this.showTomorrow = defaultShowTomorrow,
  });

  final bool showYesterday;
  final bool showToday;
  final bool showTomorrow;

  bool get hasAnySelected => showYesterday || showToday || showTomorrow;

  bool matches(DateTime targetDate) {
    if (!hasAnySelected) return false;
    if (showYesterday && isYesterday(targetDate)) return true;
    if (showToday && isToday(targetDate)) return true;
    if (showTomorrow && isTomorrow(targetDate)) return true;
    return false;
  }

  DateWindowFilter copyWith({
    bool? showYesterday,
    bool? showToday,
    bool? showTomorrow,
  }) {
    return DateWindowFilter(
      showYesterday: showYesterday ?? this.showYesterday,
      showToday: showToday ?? this.showToday,
      showTomorrow: showTomorrow ?? this.showTomorrow,
    );
  }

  List<String> activeLabels() {
    return [
      if (showYesterday) 'yesterday',
      if (showToday) 'today',
      if (showTomorrow) 'tomorrow',
    ];
  }
}

/// Bucket with no tradeable YES or NO price.
bool isZeroPriceBucket(TemperatureBucket bucket) {
  return bucket.effectiveYesAsk <= 0 && bucket.effectiveNoAsk <= 0;
}

WeatherMarketEvent filterEventBuckets(
  WeatherMarketEvent event, {
  required bool hideZeroPriceBuckets,
}) {
  if (!hideZeroPriceBuckets) return event;
  final filtered =
      event.buckets.where((b) => !isZeroPriceBucket(b)).toList();
  return event.copyWith(buckets: filtered);
}

/// One bucket is priced at certainty and no other bucket has a tradeable YES.
bool isLockedAt100(
  WeatherMarketEvent event, {
  double certaintyThreshold = 0.95,
  double minTradeableYes = 0.02,
}) {
  if (event.buckets.isEmpty) return false;

  final certainCount = event.buckets
      .where((b) =>
          b.yesPrice >= certaintyThreshold ||
          b.effectiveYesAsk >= certaintyThreshold)
      .length;

  final tradeableYesCount = event.buckets.where((b) {
    final yes = b.effectiveYesAsk;
    return yes >= minTradeableYes && yes < certaintyThreshold;
  }).length;

  return certainCount >= 1 && tradeableYesCount == 0;
}

List<WeatherMarketEvent> applyMarketFilters(
  List<WeatherMarketEvent> events, {
  required DateWindowFilter dateFilter,
  required bool hideLockedAt100,
  required bool hideZeroPriceBuckets,
}) {
  return events.where((event) {
    if (!dateFilter.matches(event.targetDate)) return false;
    if (hideLockedAt100 && isLockedAt100(event)) return false;
    if (hideZeroPriceBuckets && event.buckets.every(isZeroPriceBucket)) {
      return false;
    }
    return true;
  }).map((event) {
    return filterEventBuckets(event, hideZeroPriceBuckets: hideZeroPriceBuckets);
  }).where((event) => event.buckets.isNotEmpty).toList();
}

String dateLabel(DateTime target) {
  if (isYesterday(target)) return 'Yesterday';
  if (isToday(target)) return 'Today';
  if (isTomorrow(target)) return 'Tomorrow';
  return '';
}
