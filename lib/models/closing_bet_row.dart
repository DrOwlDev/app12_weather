enum TemperatureMetric {
  highest,
  lowest;

  String get label => switch (this) {
        TemperatureMetric.highest => 'Highest',
        TemperatureMetric.lowest => 'Lowest',
      };
}

enum BetSide {
  yes,
  no;

  String get label => name.toUpperCase();
}

class ClosingBetRow {
  const ClosingBetRow({
    required this.city,
    required this.metric,
    required this.bucketLabel,
    required this.side,
    required this.sharePrice,
    required this.polymarketUrl,
    required this.endDate,
    required this.eventSlug,
    this.marketSlug = '',
  });

  final String city;
  final TemperatureMetric metric;
  final String bucketLabel;
  final BetSide side;
  final double sharePrice;
  final String polymarketUrl;
  final DateTime endDate;
  final String eventSlug;
  final String marketSlug;

  Map<String, dynamic> toJson() => {
        'city': city,
        'metric': metric.name,
        'bucketLabel': bucketLabel,
        'side': side.name,
        'sharePrice': sharePrice,
        'polymarketUrl': polymarketUrl,
        'endDate': endDate.toUtc().toIso8601String(),
        'eventSlug': eventSlug,
        'marketSlug': marketSlug,
      };

  factory ClosingBetRow.fromJson(Map<String, dynamic> json) {
    return ClosingBetRow(
      city: json['city'] as String,
      metric: TemperatureMetric.values.byName(json['metric'] as String),
      bucketLabel: json['bucketLabel'] as String,
      side: BetSide.values.byName(json['side'] as String),
      sharePrice: (json['sharePrice'] as num).toDouble(),
      polymarketUrl: json['polymarketUrl'] as String,
      endDate: DateTime.parse(json['endDate'] as String),
      eventSlug: json['eventSlug'] as String? ?? '',
      marketSlug: json['marketSlug'] as String? ?? '',
    );
  }
}
