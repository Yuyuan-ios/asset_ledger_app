import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountPayment', () {
    test('copyWith overrides selected fields and preserves the rest', () {
      const payment = AccountPayment(
        id: 1,
        projectKey: 'Alice||Yard A',
        ymd: 20260301,
        amount: 300,
        note: '首付款',
      );

      final updated = payment.copyWith(
        amount: 450,
        note: '补款',
      );

      expect(updated.id, 1);
      expect(updated.projectKey, 'Alice||Yard A');
      expect(updated.ymd, 20260301);
      expect(updated.amount, 450);
      expect(updated.note, '补款');
    });

    test('toMap and fromMap use storage field names and defaults', () {
      const payment = AccountPayment(
        id: 2,
        projectKey: 'Bob||Yard B',
        ymd: 20260302,
        amount: 88.5,
      );

      expect(payment.toMap(), {
        'id': 2,
        'project_key': 'Bob||Yard B',
        'ymd': 20260302,
        'amount': 88.5,
        'note': null,
      });

      final rebuilt = AccountPayment.fromMap({
        'id': 3,
        'amount': 120,
      });

      expect(rebuilt.id, 3);
      expect(rebuilt.projectKey, '');
      expect(rebuilt.ymd, 0);
      expect(rebuilt.amount, 120);
      expect(rebuilt.note, isNull);
    });
  });
}
