import '../models/closing_bet_row.dart';

class ClosingBetsSnapshot {
  const ClosingBetsSnapshot({
    required this.generatedAt,
    required this.rows,
  });

  final DateTime generatedAt;
  final List<ClosingBetRow> rows;

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  factory ClosingBetsSnapshot.fromJson(Map<String, dynamic> json) {
    return ClosingBetsSnapshot(
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      rows: (json['rows'] as List<dynamic>)
          .map((e) => ClosingBetRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
