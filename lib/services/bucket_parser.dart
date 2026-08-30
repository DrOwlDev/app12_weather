import '../models/bucket.dart';

TemperatureUnit? parseUnit(String text) {
  if (text.contains('°F') || text.toUpperCase().contains('F')) {
    return TemperatureUnit.fahrenheit;
  }
  if (text.contains('°C') || text.toUpperCase().contains('C')) {
    return TemperatureUnit.celsius;
  }
  return null;
}

double? parseTemp(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(cleaned);
}

TemperatureBucket? parseBucketFromMarket({
  required Map<String, dynamic> market,
}) {
  final groupTitle = (market['groupItemTitle'] as String?) ?? '';
  final question = (market['question'] as String?) ?? groupTitle;
  final label = groupTitle.isNotEmpty ? groupTitle : question;

  final unit = parseUnit(label) ?? parseUnit(question);
  if (unit == null) return null;

  final pricesRaw = market['outcomePrices'];
  final tokenIdsRaw = market['clobTokenIds'];

  List<dynamic> prices;
  List<dynamic> tokenIds;

  if (pricesRaw is String) {
    prices = _decodeJsonList(pricesRaw);
  } else {
    prices = pricesRaw as List<dynamic>? ?? [0.5, 0.5];
  }

  if (tokenIdsRaw is String) {
    tokenIds = _decodeJsonList(tokenIdsRaw);
  } else {
    tokenIds = tokenIdsRaw as List<dynamic>? ?? [];
  }

  final yesPrice = _toDouble(prices.isNotEmpty ? prices[0] : 0.5);
  final noPrice = _toDouble(prices.length > 1 ? prices[1] : 1 - yesPrice);
  final bestAsk = _toDouble(market['bestAsk']);
  final bestBid = _toDouble(market['bestBid']);

  double? yesAsk;
  double? noAsk;
  if (bestAsk > 0) {
    yesAsk = bestAsk;
    noAsk = bestBid > 0 ? 1 - bestBid : noPrice;
  }

  final parsed = _parseRange(label, unit);
  if (parsed == null) return null;

  return TemperatureBucket(
    id: (market['id'] ?? market['conditionId'] ?? label).toString(),
    label: label,
    question: question,
    minTemp: parsed.$1,
    maxTemp: parsed.$2,
    unit: unit,
    isOrBelow: parsed.$3,
    isOrAbove: parsed.$4,
    yesPrice: yesPrice,
    noPrice: noPrice,
    yesAsk: yesAsk,
    noAsk: noAsk,
    conditionId: market['conditionId']?.toString(),
    yesTokenId: tokenIds.isNotEmpty ? tokenIds[0].toString() : null,
    noTokenId: tokenIds.length > 1 ? tokenIds[1].toString() : null,
  );
}

List<dynamic> _decodeJsonList(String raw) {
  try {
    final decoded = raw
        .replaceAll('\\"', '"')
        .replaceAll('"[', '[')
        .replaceAll(']"', ']');
    if (decoded.startsWith('[')) {
      return decoded
          .substring(1, decoded.length - 1)
          .split(',')
          .map((e) => e.trim().replaceAll('"', ''))
          .toList();
    }
  } catch (_) {}
  return [];
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

(double?, double?, bool, bool)? _parseRange(String label, TemperatureUnit unit) {
  final normalized = label.replaceAll('–', '-').replaceAll('—', '-');

  final orBelow = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:°[CFcf]|°)?\s*or below',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (orBelow != null) {
    final max = parseTemp(orBelow.group(1)!);
    return (null, max, true, false);
  }

  final orAbove = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:°[CFcf]|°)?\s*or above',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (orAbove != null) {
    final min = parseTemp(orAbove.group(1)!);
    return (min, null, false, true);
  }

  final between = RegExp(
    r'(?:between\s+)?(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (between != null) {
    final min = parseTemp(between.group(1)!);
    final max = parseTemp(between.group(2)!);
    return (min, max, false, false);
  }

  final exact = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(?:°[CFcf]|°)?$',
    caseSensitive: false,
  ).firstMatch(normalized.trim());
  if (exact != null) {
    final temp = parseTemp(exact.group(1)!);
    return (temp, temp, false, false);
  }

  return null;
}

double celsiusToFahrenheit(double c) => c * 9 / 5 + 32;

double fahrenheitToCelsius(double f) => (f - 32) * 5 / 9;

double normalizeToBucketUnit(double temp, TemperatureUnit from, TemperatureUnit to) {
  if (from == to) return temp;
  if (from == TemperatureUnit.celsius && to == TemperatureUnit.fahrenheit) {
    return celsiusToFahrenheit(temp);
  }
  return fahrenheitToCelsius(temp);
}
