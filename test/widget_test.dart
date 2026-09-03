import 'package:flutter_test/flutter_test.dart';
import 'package:app12_weather/models/bucket.dart';
import 'package:app12_weather/models/closing_bet_row.dart';
import 'package:app12_weather/models/weather_event.dart';
import 'package:app12_weather/services/bucket_parser.dart';
import 'package:app12_weather/services/closing_soon_scanner.dart';

void main() {
  test('parses Fahrenheit range bucket with slug and end date', () {
    final bucket = parseBucketFromMarket(market: {
      'groupItemTitle': '84-85°F',
      'question':
          'Will the highest temperature in Miami be between 84-85°F on August 30?',
      'outcomes': '["Yes","No"]',
      'outcomePrices': '["0.92","0.08"]',
      'bestAsk': 0.92,
      'bestBid': 0.90,
      'id': '1',
      'slug': 'miami-84-85',
      'endDateIso': '2026-08-30T12:00:00Z',
    });

    expect(bucket, isNotNull);
    expect(bucket!.minTemp, 84);
    expect(bucket.maxTemp, 85);
    expect(bucket.marketSlug, 'miami-84-85');
    expect(bucket.endDate, isNotNull);
    expect(bucket.effectiveYesAsk, 0.92);
  });

  test('buildClosingBetsFromEvents finds YES and NO in price band', () {
    final end = DateTime.now().add(const Duration(hours: 3));
    final event = WeatherMarketEvent(
      id: '1',
      slug: 'test-event',
      title: 'Highest temperature in Miami on September 2?',
      city: 'Miami',
      targetDate: DateTime(2026, 9, 2),
      endDate: end,
      metric: TemperatureMetric.highest,
      buckets: [
        TemperatureBucket(
          id: 'a',
          label: '90-91°F',
          question: 'q',
          minTemp: 90,
          maxTemp: 91,
          unit: TemperatureUnit.fahrenheit,
          isOrBelow: false,
          isOrAbove: false,
          yesPrice: 0.93,
          noPrice: 0.07,
          yesAsk: 0.93,
          noAsk: 0.07,
          marketSlug: 'miami-90-91',
          endDate: end,
        ),
        TemperatureBucket(
          id: 'b',
          label: '88-89°F',
          question: 'q',
          minTemp: 88,
          maxTemp: 89,
          unit: TemperatureUnit.fahrenheit,
          isOrBelow: false,
          isOrAbove: false,
          yesPrice: 0.50,
          noPrice: 0.50,
          marketSlug: 'miami-88-89',
          endDate: end,
        ),
      ],
      resolutionSource: 'NOAA',
      icaoCode: 'KMIA',
      latitude: 25.79,
      longitude: -80.29,
    );

    final rows = buildClosingBetsFromEvents(
      [event],
      closingWindowHours: 6,
      minPrice: 0.90,
      maxPrice: 0.97,
    );

    expect(rows.length, 1);
    expect(rows.first.side, BetSide.yes);
    expect(rows.first.sharePrice, 0.93);
    expect(rows.first.city, 'Miami');
    expect(rows.first.metric, TemperatureMetric.highest);
  });

  test('closesWithinHours rejects past and far-future markets', () {
    final now = DateTime(2026, 9, 2, 10, 0);
    expect(
      closesWithinHours(now.add(const Duration(hours: 2)), 6, now),
      isTrue,
    );
    expect(
      closesWithinHours(now.subtract(const Duration(minutes: 1)), 6, now),
      isFalse,
    );
    expect(
      closesWithinHours(now.add(const Duration(hours: 10)), 6, now),
      isFalse,
    );
  });

  test('filterClosingBetRows applies slider settings to exported rows', () {
    final end = DateTime.now().add(const Duration(hours: 2));
    final rows = [
      ClosingBetRow(
        city: 'Miami',
        metric: TemperatureMetric.highest,
        bucketLabel: '90-91°F',
        side: BetSide.yes,
        sharePrice: 0.93,
        polymarketUrl: 'https://polymarket.com/market/test',
        endDate: end,
        eventSlug: 'event',
        marketSlug: 'market',
      ),
      ClosingBetRow(
        city: 'Dallas',
        metric: TemperatureMetric.lowest,
        bucketLabel: '60-61°F',
        side: BetSide.no,
        sharePrice: 0.85,
        polymarketUrl: 'https://polymarket.com/market/test2',
        endDate: end,
        eventSlug: 'event2',
        marketSlug: 'market2',
      ),
    ];

    final filtered = filterClosingBetRows(
      rows,
      closingWindowHours: 6,
      minPrice: 0.90,
      maxPrice: 0.97,
    );

    expect(filtered.length, 1);
    expect(filtered.first.city, 'Miami');
  });
}
