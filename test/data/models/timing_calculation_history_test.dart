import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimingCalculationHistory', () {
    test('toMap and fromMap persist storage field names and ISO time', () {
      final createdAt = DateTime.utc(2026, 5, 14, 7, 30);
      final history = TimingCalculationHistory(
        id: 'history-1',
        timingRecordId: 12,
        createdAt: createdAt,
        expression: '8+8.2+8.3+8.1',
        result: 32.6,
        ticketCount: 4,
      );

      final map = history.toMap();

      expect(map, {
        'id': 'history-1',
        'timing_record_id': 12,
        'created_at': createdAt.toIso8601String(),
        'expression': '8+8.2+8.3+8.1',
        'result': 32.6,
        'ticket_count': 4,
      });

      final rebuilt = TimingCalculationHistory.fromMap(map);

      expect(rebuilt.id, history.id);
      expect(rebuilt.timingRecordId, history.timingRecordId);
      expect(rebuilt.createdAt, history.createdAt);
      expect(rebuilt.expression, history.expression);
      expect(rebuilt.result, history.result);
      expect(rebuilt.ticketCount, history.ticketCount);
    });

    test('copyWith overrides selected fields and preserves the rest', () {
      final history = TimingCalculationHistory(
        id: 'history-1',
        timingRecordId: 12,
        createdAt: DateTime(2026, 5, 14, 15, 30),
        expression: '8+8',
        result: 16.0,
        ticketCount: 2,
      );

      final updated = history.copyWith(timingRecordId: 13, result: 16.2);

      expect(updated.id, history.id);
      expect(updated.timingRecordId, 13);
      expect(updated.createdAt, history.createdAt);
      expect(updated.expression, history.expression);
      expect(updated.result, 16.2);
      expect(updated.ticketCount, history.ticketCount);
    });
  });
}
