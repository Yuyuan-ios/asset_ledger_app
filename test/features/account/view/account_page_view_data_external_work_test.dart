import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/features/account/domain/services/external_work_receivable.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/view/account_page_view_data.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('externalWorkRecordReceivableFen', () {
    test('hours record with source unit price uses hours x source price', () {
      final record = _record(
        id: 'r1',
        batchId: 'b1',
        // 1.5h × ¥300/h = ¥450（与应付 amountFen 解耦）。
        sourceUnitPriceFen: 30000,
        localUnitPriceFen: 20000,
      );

      expect(record.amountFen, 30000); // 应付：1.5h × ¥200
      expect(externalWorkRecordReceivableFen(record), 45000); // 应收：1.5h × ¥300
    });

    test('record without source unit price falls back to payable amount', () {
      final record = _imported(id: 'r1', batchId: 'b1', amountFen: 90000);

      expect(record.sourceUnitPriceFen, isNull);
      expect(externalWorkRecordReceivableFen(record), 90000);
    });
  });

  group('rollupExternalWorkReceivable', () {
    test('totals each batch once and splits linked batches by project', () {
      final items = [
        _item(
          _imported(
            id: 'a',
            batchId: 'b1',
            amountFen: 90000,
            linkedProjectId: 'project:a',
          ),
        ),
        _item(
          _imported(
            id: 'b',
            batchId: 'b2',
            amountFen: 60000,
            linkedProjectId: 'project:a',
          ),
        ),
        _item(_imported(id: 'c', batchId: 'b3', amountFen: 30000)),
      ];

      final rollup = rollupExternalWorkReceivable(items);

      expect(rollup.totalReceivableFen, 180000);
      expect(rollup.receivableFenByProjectId, {'project:a': 150000});
      expect(rollup.hoursByProjectId, {'project:a': 2.0});
    });

    test('counts project received once per batch', () {
      final items = [
        _item(
          _imported(
            id: 'a',
            batchId: 'b1',
            amountFen: 90000,
            projectReceivedFen: 50000,
          ),
        ),
        _item(
          _imported(
            id: 'b',
            batchId: 'b1',
            amountFen: 60000,
            projectReceivedFen: 50000,
          ),
        ),
        _item(
          _imported(
            id: 'c',
            batchId: 'b2',
            amountFen: 30000,
            projectReceivedFen: 20000,
          ),
        ),
      ];

      final rollup = rollupExternalWorkReceivable(items);

      expect(rollup.totalReceivableFen, 180000);
      expect(rollup.totalReceivedFen, 70000);
      expect(rollup.totalPaidExternalWorkFen, 0);
    });

    test('ignores inactive records and inactive batches', () {
      final items = [
        _item(
          _imported(
            id: 'a',
            batchId: 'b1',
            amountFen: 90000,
            projectReceivedFen: 50000,
          ),
        ),
        _item(
          _imported(
            id: 'b',
            batchId: 'b2',
            amountFen: 60000,
            projectReceivedFen: 60000,
            status: ExternalWorkRecordStatus.voided,
          ),
        ),
        _item(
          _imported(
            id: 'c',
            batchId: 'b3',
            amountFen: 30000,
            projectReceivedFen: 30000,
          ),
          batchStatus: ExternalImportBatchStatus.archived,
        ),
      ];

      final rollup = rollupExternalWorkReceivable(items);

      expect(rollup.totalReceivableFen, 90000);
      expect(rollup.totalReceivedFen, 50000);
    });
  });

  group('augmentComputedWithExternalWork', () {
    test('linked external work marks the card but never mixes receivable', () {
      final computed = _computed(
        [
          _project(id: 'project:a', displayName: '李洋 · 天眉乐', receivable: 1000),
          _project(id: 'project:b', receivable: 500),
        ],
        totalReceivable: 1500,
        totalRemaining: 1500,
      );

      final rollup = rollupExternalWorkReceivable([
        _item(
          _imported(
            id: 'a',
            batchId: 'b1',
            amountFen: 90000,
            linkedProjectId: 'project:a',
          ),
        ),
        _item(
          _imported(
            id: 'b',
            batchId: 'b2',
            amountFen: 60000,
            linkedProjectId: 'project:a',
          ),
        ),
        _item(_imported(id: 'c', batchId: 'b3', amountFen: 30000)),
      ]);

      final augmented = augmentComputedWithExternalWork(computed, rollup);
      final projectA = augmented.projects.firstWhere(
        (p) => p.effectiveProjectId == 'project:a',
      );
      final projectB = augmented.projects.firstWhere(
        (p) => p.effectiveProjectId == 'project:b',
      );

      // §6.4/§6.5 隔离红线：关联外协只标记徽标与工时展示,我方应收不混入。
      expect(projectA.receivable, 1000);
      expect(projectA.externalWorkHours, 2.0);
      expect(projectA.displayName, '李洋 · 天眉乐');
      expect(projectA.hasLinkedExternalWork, isTrue);
      // 未关联外协包不影响项目卡片。
      expect(projectB.receivable, 500);
      expect(projectB.displayName, isNot(contains('关联')));
      expect(projectB.hasLinkedExternalWork, isFalse);
      // 总览总应收/待收不混入任何外协设备应收。
      expect(augmented.totalReceivable, 1500);
      expect(augmented.totalRemaining, 1500);
    });

    test('independent external packages never touch overview totals', () {
      final computed = _computed(
        [_project(id: 'project:a', receivable: 1000, received: 300)],
        totalReceivable: 1000,
        totalReceived: 300,
        totalRemaining: 700,
        totalRatio: 0.3,
      );

      final rollup = rollupExternalWorkReceivable([
        _item(
          _imported(
            id: 'external',
            batchId: 'external-batch',
            amountFen: 100000,
            projectReceivedFen: 40000,
          ),
        ),
      ]);

      final augmented = augmentComputedWithExternalWork(computed, rollup);

      // 隔离红线：外协导入前后,总览四个数字一律不变。
      expect(augmented.totalReceivable, 1000);
      expect(augmented.totalReceived, 300);
      expect(augmented.totalRemaining, 700);
      expect(augmented.totalRatio, 0.3);
    });

    test('keeps explicit settled state when adding linked external work', () {
      final computed = _computed(
        [
          _project(
            id: 'project:settled',
            displayName: '李洋 · 天眉乐',
            receivable: 1458,
            received: 1458,
            remaining: 0,
            ratio: 1,
            isSettled: true,
          ),
        ],
        totalReceivable: 1458,
        totalReceived: 1458,
        totalRemaining: 0,
        totalRatio: 1,
      );

      final rollup = rollupExternalWorkReceivable([
        _item(
          _imported(
            id: 'linked',
            batchId: 'batch-linked',
            amountFen: 90000,
            linkedProjectId: 'project:settled',
          ),
        ),
      ]);

      final augmented = augmentComputedWithExternalWork(computed, rollup);
      final project = augmented.projects.single;

      // 隔离红线：外协关联不改我方结清状态与财务数字。
      expect(project.isSettled, isTrue);
      expect(project.isSettledForDisplay, isTrue);
      expect(project.hasLinkedExternalWork, isTrue);
      expect(project.receivable, 1458);
      expect(project.remaining, 0);
      expect(project.ratio, 1);
      expect(augmented.totalReceivable, 1458);
      expect(augmented.totalRemaining, 0);
    });

    test('linked external work keeps display-only settlement intact', () {
      final computed = _computed(
        [
          _project(
            id: 'project:active-paid',
            displayName: '李洋 · 天眉乐',
            receivable: 1458,
            received: 1458,
            remaining: 0,
            ratio: 1,
          ),
        ],
        totalReceivable: 1458,
        totalReceived: 1458,
        totalRemaining: 0,
        totalRatio: 1,
      );

      expect(computed.projects.single.isSettled, isFalse);
      expect(computed.projects.single.isSettledForDisplay, isTrue);

      final rollup = rollupExternalWorkReceivable([
        _item(
          _imported(
            id: 'linked',
            batchId: 'batch-linked',
            amountFen: 90000,
            linkedProjectId: 'project:active-paid',
          ),
        ),
      ]);

      final augmented = augmentComputedWithExternalWork(computed, rollup);
      final project = augmented.projects.single;

      // 隔离红线：外协金额不影响我方"已收齐"展示口径。
      expect(project.isSettled, isFalse);
      expect(project.isSettledForDisplay, isTrue);
      expect(project.hasLinkedExternalWork, isTrue);
      expect(project.receivable, 1458);
      expect(project.remaining, 0);
      expect(project.ratio, 1);
    });

    test('one batch is never counted into multiple projects', () {
      final computed = _computed(
        [
          _project(id: 'project:a', receivable: 1000),
          _project(id: 'project:b', receivable: 1000),
        ],
        totalReceivable: 2000,
        totalRemaining: 2000,
      );

      final rollup = rollupExternalWorkReceivable([
        _item(
          _imported(
            id: 'a',
            batchId: 'b1',
            amountFen: 50000,
            linkedProjectId: 'project:a',
          ),
        ),
      ]);

      final augmented = augmentComputedWithExternalWork(computed, rollup);
      final projectA = augmented.projects.firstWhere(
        (p) => p.effectiveProjectId == 'project:a',
      );
      final projectB = augmented.projects.firstWhere(
        (p) => p.effectiveProjectId == 'project:b',
      );

      // 隔离红线下两个项目应收都保持原值;徽标只落在关联项目上。
      expect(projectA.receivable, 1000);
      expect(projectA.hasLinkedExternalWork, isTrue);
      expect(projectB.receivable, 1000);
      expect(projectB.hasLinkedExternalWork, isFalse);
    });

    test('merged project picks up batches linked to its member ids', () {
      final merged = AccountProjectVM(
        projectId: 'merge:1',
        projectKey: 'merge:1',
        displayName: '李杰 · 合并2项目',
        kind: AccountProjectKind.merged,
        memberProjectIds: const ['project:m1', 'project:m2'],
        minYmd: 20260101,
        deviceIds: const [],
        hoursByDevice: const {},
        rentIncomeTotal: 0,
        minRate: null,
        isMultiDevice: false,
        isMultiMode: false,
        receivable: 2000,
        received: 0,
        remaining: 2000,
        ratio: 0,
        payments: const [],
      );
      final computed = _computed(
        [merged],
        totalReceivable: 2000,
        totalRemaining: 2000,
      );

      final rollup = rollupExternalWorkReceivable([
        _item(
          _imported(
            id: 'a',
            batchId: 'b1',
            amountFen: 40000,
            linkedProjectId: 'project:m2',
          ),
        ),
      ]);

      final augmented = augmentComputedWithExternalWork(computed, rollup);
      final mergedAugmented = augmented.projects.single;

      // 合并卡同样只标记,不混金额。
      expect(mergedAugmented.receivable, 2000);
      expect(mergedAugmented.externalWorkHours, 1.0);
      expect(mergedAugmented.displayName, '李杰 · 合并2项目');
      expect(mergedAugmented.hasLinkedExternalWork, isTrue);
    });

    test('empty rollup returns the computed result unchanged', () {
      final computed = _computed(
        [_project(id: 'project:a', receivable: 1000)],
        totalReceivable: 1000,
        totalRemaining: 1000,
      );

      final augmented = augmentComputedWithExternalWork(
        computed,
        const ExternalWorkReceivableRollup.empty(),
      );

      expect(identical(augmented, computed), isTrue);
    });
  });

  group('calculateNetCashReceived', () {
    test(
      'subtracts actual expenses and paid external work without clamping',
      () {
        final net = calculateNetCashReceived(
          receivedCash: 1000,
          fuelExpense: 300,
          maintenanceExpense: 200,
          paidExternalWorkFen: 40000,
        );

        expect(net, 100);
      },
    );

    test('does not treat unpaid external payable as paid cash out', () {
      final rollup = rollupExternalWorkReceivable([
        _item(_imported(id: 'external', batchId: 'b1', amountFen: 90000)),
      ]);

      final net = calculateNetCashReceived(
        receivedCash: 500,
        fuelExpense: 0,
        maintenanceExpense: 0,
        paidExternalWorkFen: rollup.totalPaidExternalWorkFen,
      );

      expect(rollup.totalPaidExternalWorkFen, 0);
      expect(net, 500);
    });

    test('allows negative net cash received', () {
      final net = calculateNetCashReceived(
        receivedCash: 100,
        fuelExpense: 150,
        maintenanceExpense: 200,
        paidExternalWorkFen: 0,
      );

      expect(net, -250);
    });
  });
}

AccountComputed _computed(
  List<AccountProjectVM> projects, {
  required double totalReceivable,
  double totalReceived = 0,
  required double totalRemaining,
  double? totalRatio,
}) {
  return AccountComputed(
    projects: projects,
    totalReceivable: totalReceivable,
    totalReceived: totalReceived,
    totalRemaining: totalRemaining,
    totalRatio: totalRatio ?? (totalReceivable <= 0 ? null : 0),
    deviceReceivables: const [],
  );
}

AccountProjectVM _project({
  required String id,
  String? displayName,
  required double receivable,
  double received = 0,
  double? remaining,
  double? ratio,
  bool isSettled = false,
}) {
  return AccountProjectVM(
    projectId: id,
    projectKey: id,
    displayName: displayName ?? id,
    isSettled: isSettled,
    minYmd: 20260101,
    deviceIds: const [],
    hoursByDevice: const {},
    rentIncomeTotal: 0,
    minRate: null,
    isMultiDevice: false,
    isMultiMode: false,
    receivable: receivable,
    received: received,
    remaining: remaining ?? receivable,
    ratio: ratio ?? 0,
    payments: const [],
  );
}

TimingExternalWorkRecordItem _item(
  ExternalWorkRecord record, {
  ExternalImportBatchStatus batchStatus = ExternalImportBatchStatus.active,
}) {
  return TimingExternalWorkRecordItem(
    record: record,
    batch: _batch(id: record.importBatchId, status: batchStatus),
  );
}

ExternalImportBatch _batch({
  required String id,
  ExternalImportBatchStatus status = ExternalImportBatchStatus.active,
}) {
  return ExternalImportBatch(
    id: id,
    sourceShareId: 'share-$id',
    sourceDisplayName: '王师傅',
    recordCount: 1,
    totalHoursMilli: 1500,
    totalAmountFen: 45000,
    siteSummary: '一号工地',
    importedAt: '2026-05-18T00:00:00.000Z',
    status: status,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

ExternalWorkRecord _record({
  required String id,
  required String batchId,
  required int sourceUnitPriceFen,
  int? localUnitPriceFen,
}) {
  return ExternalWorkRecord.create(
    id: id,
    importBatchId: batchId,
    sourceShareId: 'share-$batchId',
    sourceRecordUuid: 'source-$id',
    sourceInstallationUuid: 'install-1',
    originFingerprint: 'fingerprint-$id',
    collaboratorName: '王师傅',
    contactSnapshot: '甲方',
    siteSnapshot: '一号工地',
    workDate: 20260518,
    hoursMilli: 1500,
    sourceUnitPriceFen: sourceUnitPriceFen,
    localUnitPriceFen: localUnitPriceFen,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

ExternalWorkRecord _imported({
  required String id,
  required String batchId,
  required int amountFen,
  int projectReceivedFen = 0,
  String? linkedProjectId,
  ExternalWorkRecordStatus status = ExternalWorkRecordStatus.active,
}) {
  return ExternalWorkRecord.imported(
    id: id,
    importBatchId: batchId,
    sourceShareId: 'share-$batchId',
    sourceRecordUuid: 'source-$id',
    sourceInstallationUuid: 'install-1',
    originFingerprint: 'fingerprint-$id',
    collaboratorName: '王师傅',
    contactSnapshot: '甲方',
    siteSnapshot: '一号工地',
    workDate: 20260518,
    hoursMilli: 1000,
    amountFen: amountFen,
    projectReceivedFen: projectReceivedFen,
    linkedProjectId: linkedProjectId,
    status: status,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}
