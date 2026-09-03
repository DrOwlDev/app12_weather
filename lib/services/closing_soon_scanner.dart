import '../config/constants.dart';
import '../data/polymarket_client.dart';
import '../models/closing_bet_row.dart';
import '../models/weather_event.dart';

class ClosingSoonResult {
  const ClosingSoonResult({
    required this.rows,
    required this.scannedAt,
  });

  final List<ClosingBetRow> rows;
  final DateTime scannedAt;
}

class ClosingSoonScanner {
  ClosingSoonScanner({PolymarketClient? polymarketClient})
      : _polymarket = polymarketClient ?? PolymarketClient();

  final PolymarketClient _polymarket;

  Future<ClosingSoonResult> scan({
    int closingWindowHours = defaultClosingWindowHours,
    double minPrice = defaultClosingBetMinPrice,
    double maxPrice = defaultClosingBetMaxPrice,
  }) async {
    final events = await fetchEvents();
    final now = DateTime.now();
    final rows = buildClosingBetsFromEvents(
      events,
      closingWindowHours: closingWindowHours,
      minPrice: minPrice,
      maxPrice: maxPrice,
      now: now,
    );
    return ClosingSoonResult(rows: rows, scannedAt: now);
  }

  Future<List<WeatherMarketEvent>> fetchEvents() =>
      _polymarket.fetchAllActiveTemperatureEvents();

  void dispose() => _polymarket.dispose();
}

/// Shared filter logic for native scan and web client-side filtering.
List<ClosingBetRow> buildClosingBetsFromEvents(
  List<WeatherMarketEvent> events, {
  required int closingWindowHours,
  required double minPrice,
  required double maxPrice,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final rows = <ClosingBetRow>[];

  for (final event in events) {
    for (final bucket in event.buckets) {
      final endDate = bucket.endDate ?? event.endDate;
      if (endDate == null) continue;
      if (!closesWithinHours(endDate, closingWindowHours, reference)) continue;

      final yesPrice = bucket.effectiveYesAsk;
      final noPrice = bucket.effectiveNoAsk;
      final marketUrl = bucket.marketSlug.isNotEmpty
          ? '$polymarketMarketUrl${bucket.marketSlug}'
          : event.polymarketUrl;

      if (priceInRange(yesPrice, minPrice, maxPrice)) {
        rows.add(
          ClosingBetRow(
            city: event.city,
            metric: event.metric,
            bucketLabel: bucket.label,
            side: BetSide.yes,
            sharePrice: yesPrice,
            polymarketUrl: marketUrl,
            endDate: endDate,
            eventSlug: event.slug,
            marketSlug: bucket.marketSlug,
          ),
        );
      }

      if (priceInRange(noPrice, minPrice, maxPrice)) {
        rows.add(
          ClosingBetRow(
            city: event.city,
            metric: event.metric,
            bucketLabel: bucket.label,
            side: BetSide.no,
            sharePrice: noPrice,
            polymarketUrl: marketUrl,
            endDate: endDate,
            eventSlug: event.slug,
            marketSlug: bucket.marketSlug,
          ),
        );
      }
    }
  }

  rows.sort((a, b) {
    final endCmp = a.endDate.compareTo(b.endDate);
    if (endCmp != 0) return endCmp;
    final cityCmp = a.city.compareTo(b.city);
    if (cityCmp != 0) return cityCmp;
    return a.bucketLabel.compareTo(b.bucketLabel);
  });

  return rows;
}

bool closesWithinHours(DateTime endDate, int hours, DateTime now) {
  final diff = endDate.difference(now);
  if (diff.inSeconds <= 0) return false;
  return diff.inMinutes <= hours * 60;
}

bool priceInRange(double price, double min, double max) {
  return price >= min && price <= max;
}

List<ClosingBetRow> filterClosingBetRows(
  List<ClosingBetRow> rows, {
  required int closingWindowHours,
  required double minPrice,
  required double maxPrice,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  return rows.where((row) {
    if (!closesWithinHours(row.endDate, closingWindowHours, reference)) {
      return false;
    }
    return priceInRange(row.sharePrice, minPrice, maxPrice);
  }).toList();
}
