import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/features/account/model/account_project_payment_display_vm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildMergedPaymentDisplayItems', () {
    test('shows normal member payments with site source labels', () {
      final items = buildMergedPaymentDisplayItems(
        memberProjectKeys: const ['李杰||尚义', '李杰||鲜滩'],
        payments: [
          AccountPayment(
            id: 1,
            projectKey: '李杰||尚义',
            ymd: 20260501,
            amount: 5000,
            note: '现金',
          ),
          AccountPayment(
            id: 2,
            projectKey: '李杰||鲜滩',
            ymd: 20260502,
            amount: 300,
          ),
        ],
      );

      expect(items, hasLength(2));
      expect(items.map((item) => item.sourceLabel).toList(), ['鲜滩', '尚义']);
      expect(items.last.note, '现金');
      expect(items.last.relatedSite, '尚义');
    });

    test('groups merge allocation rows by mergeBatchId', () {
      final items = buildMergedPaymentDisplayItems(
        memberProjectKeys: const ['李杰||尚义', '李杰||鲜滩'],
        payments: [
          AccountPayment(
            id: 1,
            projectKey: '李杰||尚义',
            ymd: 20260515,
            amount: 1490,
            sourceType: AccountPayment.sourceTypeMergeAllocation,
            mergeGroupId: 3,
            mergeBatchId: 'batch-1',
            mergeBatchTotalAmount: 5000,
            mergeBatchNote: '微信收款',
          ),
          AccountPayment(
            id: 2,
            projectKey: '李杰||鲜滩',
            ymd: 20260515,
            amount: 3510,
            sourceType: AccountPayment.sourceTypeMergeAllocation,
            mergeGroupId: 3,
            mergeBatchId: 'batch-1',
            mergeBatchTotalAmount: 5000,
            mergeBatchNote: '微信收款',
          ),
        ],
      );

      expect(items, hasLength(1));
      expect(
        items.single.type,
        AccountProjectPaymentDisplayType.mergeBatchPayment,
      );
      expect(items.single.id, 'batch-1');
      expect(items.single.amount, 5000);
      expect(items.single.note, '微信收款');
      expect(items.single.sourceLabel, '合并分摊');
    });

    test('falls back to allocation amount sum when batch total is missing', () {
      final items = buildMergedPaymentDisplayItems(
        memberProjectKeys: const ['李杰||尚义', '李杰||鲜滩'],
        payments: [
          AccountPayment(
            id: 1,
            projectKey: '李杰||尚义',
            ymd: 20260515,
            amount: 1490,
            sourceType: AccountPayment.sourceTypeMergeAllocation,
            mergeBatchId: 'batch-1',
          ),
          AccountPayment(
            id: 2,
            projectKey: '李杰||鲜滩',
            ymd: 20260515,
            amount: 3510,
            sourceType: AccountPayment.sourceTypeMergeAllocation,
            mergeBatchId: 'batch-1',
          ),
        ],
      );

      expect(items.single.amount, 5000);
    });

    test('sorts mixed payments by ymd, createdAt, and id descending', () {
      final items = buildMergedPaymentDisplayItems(
        memberProjectKeys: const ['李杰||尚义', '李杰||鲜滩'],
        payments: [
          AccountPayment(
            id: 1,
            projectKey: '李杰||尚义',
            ymd: 20260514,
            amount: 100,
            createdAt: '2026-05-16T01:05:00.000Z',
          ),
          AccountPayment(
            id: 2,
            projectKey: '李杰||尚义',
            ymd: 20260515,
            amount: 200,
            createdAt: '2026-05-16T01:01:00.000Z',
          ),
          AccountPayment(
            id: 3,
            projectKey: '李杰||鲜滩',
            ymd: 20260515,
            amount: 300,
            createdAt: '2026-05-16T01:02:00.000Z',
          ),
          AccountPayment(
            id: 5,
            projectKey: '李杰||尚义',
            ymd: 20260515,
            amount: 50,
            sourceType: AccountPayment.sourceTypeMergeAllocation,
            mergeBatchId: 'batch-1',
            mergeBatchTotalAmount: 500,
            createdAt: '2026-05-16T01:03:00.000Z',
          ),
          AccountPayment(
            id: 4,
            projectKey: '李杰||鲜滩',
            ymd: 20260515,
            amount: 450,
            sourceType: AccountPayment.sourceTypeMergeAllocation,
            mergeBatchId: 'batch-1',
            mergeBatchTotalAmount: 500,
            createdAt: '2026-05-16T01:03:00.000Z',
          ),
        ],
      );

      expect(items.map((item) => item.id).toList(), ['batch-1', '3', '2', '1']);
    });
  });
}
