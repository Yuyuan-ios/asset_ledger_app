import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectWriteOff', () {
    test('toMap writes amount_fen only and derives yuan getter', () {
      final writeOff = ProjectWriteOff(
        id: 'wo-1',
        projectId: 'p-1',
        amount: 88.5,
        reason: 'rounding',
        writeOffDate: '2026-05-19',
        createdAt: '2026-05-19T00:00:00.000Z',
        updatedAt: '2026-05-19T00:00:00.000Z',
      );

      final map = writeOff.toMap();
      expect(map.containsKey('amount'), isFalse);
      expect(map['amount_fen'], 8850);
      expect(writeOff.amount, 88.5);
    });

    test('fromMap reads fen only and ignores legacy REAL amount', () {
      final writeOff = ProjectWriteOff.fromMap({
        'id': 'wo-2',
        'project_id': 'p-2',
        'amount': 120.01,
        'amount_fen': 12000,
        'reason': 'bad_debt',
        'write_off_date': '2026-05-19',
        'created_at': '2026-05-19T00:00:00.000Z',
        'updated_at': '2026-05-19T00:00:00.000Z',
      });

      expect(writeOff.amount, 120);
      expect(writeOff.amountFen, 12000);
    });

    test('fromMap rejects legacy rows without amount_fen', () {
      expect(
        () => ProjectWriteOff.fromMap({
          'id': 'wo-3',
          'project_id': 'p-3',
          'amount': 73.21,
          'reason': 'underpaid',
          'write_off_date': '2025-12-31',
          'created_at': '2025-12-31T00:00:00.000Z',
          'updated_at': '2025-12-31T00:00:00.000Z',
        }),
        throwsA(isA<StateError>()),
      );
    });
  });
}
