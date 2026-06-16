import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountPayment', () {
    test('copyWith overrides selected fields and preserves the rest', () {
      final payment = AccountPayment(
        id: 1,
        projectKey: 'Alice||Yard A',
        ymd: 20260301,
        amount: 300,
        note: '首付款',
      );

      final updated = payment.copyWith(
        amount: 450,
        note: '补款',
        sourceType: AccountPayment.sourceTypeMergeAllocation,
        mergeGroupId: 7,
        mergeBatchId: 'batch-1',
        mergeBatchTotalAmount: 1000,
        mergeBatchNote: '合并收款',
        createdAt: '2026-05-16T01:02:03.000Z',
      );

      expect(updated.id, 1);
      expect(updated.projectKey, 'Alice||Yard A');
      expect(updated.ymd, 20260301);
      expect(updated.amount, 450);
      expect(updated.note, '补款');
      expect(updated.sourceType, AccountPayment.sourceTypeMergeAllocation);
      expect(updated.mergeGroupId, 7);
      expect(updated.mergeBatchId, 'batch-1');
      expect(updated.mergeBatchTotalAmount, 1000);
      expect(updated.mergeBatchNote, '合并收款');
      expect(updated.createdAt, '2026-05-16T01:02:03.000Z');
    });

    test('toMap and fromMap use storage field names and defaults', () {
      final payment = AccountPayment(
        id: 2,
        projectKey: 'Bob||Yard B',
        ymd: 20260302,
        amount: 88.5,
      );

      expect(payment.toMap(), {
        'id': 2,
        'project_id': ProjectId.legacyFromKey('Bob||Yard B'),
        'project_key': 'Bob||Yard B',
        'ymd': 20260302,
        'amount_fen': 8850,
        'note': null,
        'source_type': AccountPayment.sourceTypeManual,
        'merge_group_id': null,
        'merge_batch_id': null,
        'merge_batch_total_amount_fen': null,
        'merge_batch_note': null,
        'created_at': null,
      });

      final rebuilt = AccountPayment.fromMap({'id': 3, 'amount_fen': 12000});

      expect(rebuilt.id, 3);
      expect(rebuilt.projectId, '');
      expect(rebuilt.projectKey, '');
      expect(rebuilt.ymd, 0);
      expect(rebuilt.amount, 120);
      expect(rebuilt.note, isNull);
      expect(rebuilt.sourceType, AccountPayment.sourceTypeManual);
      expect(rebuilt.mergeGroupId, isNull);
      expect(rebuilt.mergeBatchId, isNull);
      expect(rebuilt.mergeBatchTotalAmount, isNull);
      expect(rebuilt.mergeBatchNote, isNull);
      expect(rebuilt.createdAt, isNull);
    });

    test('fromMap rebuilds merge allocation batch fields', () {
      final payment = AccountPayment.fromMap({
        'id': 9,
        'project_key': '李杰||尚义',
        'ymd': 20260515,
        'amount_fen': 149000,
        'note': '合并分摊',
        'source_type': AccountPayment.sourceTypeMergeAllocation,
        'merge_group_id': 3,
        'merge_batch_id': 'batch-20260515',
        'merge_batch_total_amount_fen': 499999,
        'merge_batch_note': '微信收款',
        'created_at': '2026-05-16T01:02:03.000Z',
      });

      expect(payment.id, 9);
      expect(payment.projectKey, '李杰||尚义');
      expect(payment.ymd, 20260515);
      expect(payment.amount, 1490);
      expect(payment.note, '合并分摊');
      expect(payment.sourceType, AccountPayment.sourceTypeMergeAllocation);
      expect(payment.mergeGroupId, 3);
      expect(payment.mergeBatchId, 'batch-20260515');
      expect(payment.mergeBatchTotalAmount, 4999.99);
      expect(payment.mergeBatchNote, '微信收款');
      expect(payment.createdAt, '2026-05-16T01:02:03.000Z');
    });

    test('fromMap requires fen authority and ignores legacy REAL amount', () {
      expect(
        () => AccountPayment.fromMap({
          'id': 7,
          'project_key': 'Carol||Yard C',
          'ymd': 20251231,
          'amount': 73.21,
          'merge_batch_total_amount': 200.05,
          'source_type': AccountPayment.sourceTypeMergeAllocation,
        }),
        throwsA(isA<StateError>()),
      );

      final payment = AccountPayment.fromMap({
        'id': 7,
        'project_key': 'Carol||Yard C',
        'ymd': 20251231,
        'amount': 1.0,
        'amount_fen': 7321,
        'merge_batch_total_amount': 200.05,
        'merge_batch_total_amount_fen': 20005,
        'source_type': AccountPayment.sourceTypeMergeAllocation,
      });

      expect(payment.amount, 73.21);
      expect(payment.mergeBatchTotalAmount, 200.05);

      final remapped = payment.toMap();
      expect(remapped.containsKey('amount'), isFalse);
      expect(remapped['amount_fen'], 7321);
      expect(remapped.containsKey('merge_batch_total_amount'), isFalse);
      expect(remapped['merge_batch_total_amount_fen'], 20005);
    });

    test('copyWith can preserve or override fen authority directly', () {
      final payment = AccountPayment(
        id: 8,
        projectKey: 'Dan||Yard D',
        ymd: 20260101,
        amount: 9.99,
      );

      expect(payment.copyWith().amountFen, 999);
      expect(payment.copyWith(amount: 10.01).amountFen, 1001);
      expect(payment.copyWith(amountFen: 1002).amount, 10.02);
    });
  });
}
