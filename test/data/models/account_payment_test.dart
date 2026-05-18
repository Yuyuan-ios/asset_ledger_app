import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project_id.dart';
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
      const payment = AccountPayment(
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
        'amount': 88.5,
        'amount_fen': 8850,
        'note': null,
        'source_type': AccountPayment.sourceTypeManual,
        'merge_group_id': null,
        'merge_batch_id': null,
        'merge_batch_total_amount': null,
        'merge_batch_total_amount_fen': null,
        'merge_batch_note': null,
        'created_at': null,
      });

      final rebuilt = AccountPayment.fromMap({
        'id': 3,
        'amount': 120.01,
        'amount_fen': 12000,
      });

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
        'amount': 1490,
        'note': '合并分摊',
        'source_type': AccountPayment.sourceTypeMergeAllocation,
        'merge_group_id': 3,
        'merge_batch_id': 'batch-20260515',
        'merge_batch_total_amount': 5000,
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

    test('fromMap falls back to legacy REAL amount when fen is absent', () {
      // Pre-v18 historical row / old backup import: only the REAL columns
      // exist. The model must read them and still derive fen on write-back.
      final legacy = AccountPayment.fromMap({
        'id': 7,
        'project_key': 'Carol||Yard C',
        'ymd': 20251231,
        'amount': 73.21,
        'merge_batch_total_amount': 200.05,
        'source_type': AccountPayment.sourceTypeMergeAllocation,
      });

      expect(legacy.amount, 73.21);
      expect(legacy.mergeBatchTotalAmount, 200.05);
      expect(legacy.amountFen, 7321);
      expect(legacy.mergeBatchTotalAmountFen, 20005);

      final remapped = legacy.toMap();
      expect(remapped['amount'], 73.21);
      expect(remapped['amount_fen'], 7321);
      expect(remapped['merge_batch_total_amount'], 200.05);
      expect(remapped['merge_batch_total_amount_fen'], 20005);
    });

    test('fromMap prefers fen and tolerates a NULL fen column', () {
      final nullFen = AccountPayment.fromMap({
        'id': 8,
        'project_key': 'Dan||Yard D',
        'ymd': 20260101,
        'amount': 9.99,
        'amount_fen': null,
      });

      expect(nullFen.amount, 9.99);
      expect(nullFen.amountFen, 999);
    });
  });
}
