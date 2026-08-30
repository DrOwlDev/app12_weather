import '../models/weather_event.dart';

/// Calendar date without time (local timezone).
DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

bool isToday(DateTime target) {
  final now = DateTime.now();
  return dateOnly(target) == dateOnly(now);
}

bool isTomorrow(DateTime target) {
  final now = DateTime.now();
  return dateOnly(target) == dateOnly(now).add(const Duration(days: 1));
}

bool isTodayOrTomorrow(DateTime target) => isToday(target) || isTomorrow(target);

/// One bucket is priced at certainty and no other bucket has a tradeable YES.
bool isLockedAt100(
  WeatherMarketEvent event, {
  double certaintyThreshold = 0.95,
  double minTradeableYes = 0.02,
}) {
  if (event.buckets.isEmpty) return false;

  final certainCount = event.buckets
      .where((b) => b.yesPrice >= certaintyThreshold || b.effectiveYesAsk >= certaintyThreshold)
      .length;

  final tradeableYesCount = event.buckets.where((b) {
    final yes = b.effectiveYesAsk;
    return yes >= minTradeableYes && yes < certaintyThreshold;
  }).length;

  return certainCount >= 1 && tradeableYesCount == 0;
}

List<WeatherMarketEvent> applyMarketFilters(
  List<WeatherMarketEvent> events, {
  required bool todayTomorrowOnly,
  required bool hideLockedAt100,
}) {
  return events.where((event) {
    if (todayTomorrowOnly && !isTodayOrTomorrow(event.targetDate)) {
      return false;
    }
    if (hideLockedAt100 && isLockedAt100(event)) {
      return false;
    }
    return true;
  }).toList();
}

String dateLabel(DateTime target) {
  if (isToday(target)) return 'Today';
  if (isTomorrow(target)) return 'Tomorrow';
  return '';
}
