import 'package:flutter_test/flutter_test.dart';
import 'package:app12_weather/models/bucket.dart';
import 'package:app12_weather/models/weather_event.dart';
import 'package:app12_weather/services/bucket_parser.dart';
import 'package:app12_weather/services/edge_calculator.dart';
import 'package:app12_weather/services/market_filters.dart';

void main() {
  test('parses Fahrenheit range bucket', () {
    final bucket = parseBucketFromMarket(market: {
      'groupItemTitle': '84-85°F',
      'question': 'Will the highest temperature in Miami be between 84-85°F on August 30?',
      'outcomes': '["Yes","No"]',
      'outcomePrices': '["0.35","0.65"]',
      'bestAsk': 0.36,
      'bestBid': 0.34,
      'id': '1',
    });

    expect(bucket, isNotNull);
    expect(bucket!.minTemp, 84);
    expect(bucket.maxTemp, 85);
    expect(bucket.unit, TemperatureUnit.fahrenheit);
    expect(bucket.containsTemperature(84), isTrue);
    expect(bucket.containsTemperature(86), isFalse);
  });

  test('parses Celsius or-below bucket', () {
    final bucket = parseBucketFromMarket(market: {
      'groupItemTitle': '26°C or below',
      'question': 'Will the highest temperature in Hong Kong be 26°C or below?',
      'outcomes': ['Yes', 'No'],
      'outcomePrices': ['0.05', '0.95'],
      'id': '2',
    });

    expect(bucket, isNotNull);
    expect(bucket!.isOrBelow, isTrue);
    expect(bucket.maxTemp, 26);
    expect(bucket.containsTemperature(25), isTrue);
    expect(bucket.containsTemperature(27), isFalse);
  });

  test('edge calculator finds YES recommendation above threshold', () {
    final buckets = [
      TemperatureBucket(
        id: 'a',
        label: '80-81°F',
        question: 'q',
        minTemp: 80,
        maxTemp: 81,
        unit: TemperatureUnit.fahrenheit,
        isOrBelow: false,
        isOrAbove: false,
        yesPrice: 0.30,
        noPrice: 0.70,
        yesAsk: 0.32,
        noAsk: 0.72,
        modelProbability: 0.55,
      ),
      TemperatureBucket(
        id: 'b',
        label: '82-83°F',
        question: 'q',
        minTemp: 82,
        maxTemp: 83,
        unit: TemperatureUnit.fahrenheit,
        isOrBelow: false,
        isOrAbove: false,
        yesPrice: 0.60,
        noPrice: 0.40,
        yesAsk: 0.62,
        noAsk: 0.42,
        modelProbability: 0.35,
      ),
    ];

    final event = WeatherMarketEvent(
      id: '1',
      slug: 'test-event',
      title: 'Highest temperature in Miami on August 30?',
      city: 'Miami',
      targetDate: DateTime(2026, 8, 30),
      buckets: buckets,
      resolutionSource: 'NOAA',
      icaoCode: 'KMIA',
      latitude: 25.79,
      longitude: -80.29,
    );

    final calc = EdgeCalculator();
    final rec = calc.bestRecommendation(
      event: event,
      minEdge: 0.07,
      cityStabilityScore: 0.9,
    );

    expect(rec, isNotNull);
    expect(rec!.targetBucket.id, 'a');
    expect(rec.effectiveEdge, greaterThan(0.07));
  });

  test('detects market locked at 100%', () {
    final event = WeatherMarketEvent(
      id: '1',
      slug: 'locked',
      title: 'Test',
      city: 'Miami',
      targetDate: DateTime.now(),
      buckets: [
        TemperatureBucket(
          id: 'a',
          label: '88-89°F',
          question: 'q',
          minTemp: 88,
          maxTemp: 89,
          unit: TemperatureUnit.fahrenheit,
          isOrBelow: false,
          isOrAbove: false,
          yesPrice: 0.9995,
          noPrice: 0.0005,
        ),
        TemperatureBucket(
          id: 'b',
          label: '90-91°F',
          question: 'q',
          minTemp: 90,
          maxTemp: 91,
          unit: TemperatureUnit.fahrenheit,
          isOrBelow: false,
          isOrAbove: false,
          yesPrice: 0.0005,
          noPrice: 0.9995,
        ),
      ],
      resolutionSource: 'NOAA',
      icaoCode: 'KMIA',
      latitude: 25.79,
      longitude: -80.29,
    );

    expect(isLockedAt100(event), isTrue);
  });

  test('isTodayOrTomorrow matches calendar days', () {
    final now = DateTime.now();
    expect(isTodayOrTomorrow(now), isTrue);
    expect(isTodayOrTomorrow(now.add(const Duration(days: 1))), isTrue);
    expect(isTodayOrTomorrow(now.add(const Duration(days: 2))), isFalse);
  });

  test('DateWindowFilter matches yesterday today and tomorrow', () {
    final now = DateTime.now();
    const filter = DateWindowFilter(
      showYesterday: true,
      showToday: true,
      showTomorrow: true,
    );
    expect(filter.matches(now.subtract(const Duration(days: 1))), isTrue);
    expect(filter.matches(now), isTrue);
    expect(filter.matches(now.add(const Duration(days: 1))), isTrue);
    expect(filter.matches(now.add(const Duration(days: 2))), isFalse);
  });

  test('isZeroPriceBucket detects untradeable buckets', () {
    const bucket = TemperatureBucket(
      id: 'z',
      label: '0-1°C',
      question: 'q',
      minTemp: 0,
      maxTemp: 1,
      unit: TemperatureUnit.celsius,
      isOrBelow: false,
      isOrAbove: false,
      yesPrice: 0,
      noPrice: 0,
    );
    expect(isZeroPriceBucket(bucket), isTrue);
  });
}
