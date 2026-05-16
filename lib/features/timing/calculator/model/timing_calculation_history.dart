class TimingCalculationHistory {
  const TimingCalculationHistory({
    required this.id,
    required this.timingRecordId,
    required this.createdAt,
    required this.expression,
    required this.result,
    required this.ticketCount,
  });

  final String id;
  final int timingRecordId;
  final DateTime createdAt;
  final String expression;
  final double result;
  final int ticketCount;

  TimingCalculationHistory copyWith({
    String? id,
    int? timingRecordId,
    DateTime? createdAt,
    String? expression,
    double? result,
    int? ticketCount,
  }) {
    return TimingCalculationHistory(
      id: id ?? this.id,
      timingRecordId: timingRecordId ?? this.timingRecordId,
      createdAt: createdAt ?? this.createdAt,
      expression: expression ?? this.expression,
      result: result ?? this.result,
      ticketCount: ticketCount ?? this.ticketCount,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'timing_record_id': timingRecordId,
      'created_at': createdAt.toIso8601String(),
      'expression': expression,
      'result': result,
      'ticket_count': ticketCount,
    };
  }

  static TimingCalculationHistory fromMap(Map<String, Object?> m) {
    return TimingCalculationHistory(
      id: m['id'] as String,
      timingRecordId: m['timing_record_id'] as int,
      createdAt: DateTime.parse(m['created_at'] as String),
      expression: m['expression'] as String,
      result: (m['result'] as num).toDouble(),
      ticketCount: m['ticket_count'] as int,
    );
  }
}
