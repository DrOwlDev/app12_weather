enum TemperatureUnit { celsius, fahrenheit }

class TemperatureBucket {
  const TemperatureBucket({
    required this.id,
    required this.label,
    required this.question,
    this.minTemp,
    this.maxTemp,
    required this.unit,
    required this.isOrBelow,
    required this.isOrAbove,
    required this.yesPrice,
    required this.noPrice,
    this.yesAsk,
    this.noAsk,
    this.conditionId,
    this.yesTokenId,
    this.noTokenId,
    this.modelProbability = 0,
    this.marketSlug = '',
    this.endDate,
  });

  final String id;
  final String label;
  final String question;
  final double? minTemp;
  final double? maxTemp;
  final TemperatureUnit unit;
  final bool isOrBelow;
  final bool isOrAbove;
  final double yesPrice;
  final double noPrice;
  final double? yesAsk;
  final double? noAsk;
  final String? conditionId;
  final String? yesTokenId;
  final String? noTokenId;
  final double modelProbability;
  final String marketSlug;
  final DateTime? endDate;

  double get effectiveYesAsk => yesAsk ?? yesPrice;
  double get effectiveNoAsk => noAsk ?? noPrice;

  bool containsTemperature(double temp) {
    if (isOrBelow && maxTemp != null) {
      return temp <= maxTemp!;
    }
    if (isOrAbove && minTemp != null) {
      return temp >= minTemp!;
    }
    if (minTemp != null && maxTemp != null) {
      return temp >= minTemp! && temp <= maxTemp!;
    }
    if (minTemp != null && maxTemp == null) {
      return temp == minTemp!;
    }
    return false;
  }

  TemperatureBucket copyWith({
    double? modelProbability,
    String? marketSlug,
    DateTime? endDate,
  }) {
    return TemperatureBucket(
      id: id,
      label: label,
      question: question,
      minTemp: minTemp,
      maxTemp: maxTemp,
      unit: unit,
      isOrBelow: isOrBelow,
      isOrAbove: isOrAbove,
      yesPrice: yesPrice,
      noPrice: noPrice,
      yesAsk: yesAsk,
      noAsk: noAsk,
      conditionId: conditionId,
      yesTokenId: yesTokenId,
      noTokenId: noTokenId,
      modelProbability: modelProbability ?? this.modelProbability,
      marketSlug: marketSlug ?? this.marketSlug,
      endDate: endDate ?? this.endDate,
    );
  }
}
