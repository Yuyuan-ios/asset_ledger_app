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

    test('ignores inactive records and inactive batches', () {
      final items = [
        _item(_imported(id: 'a', batchId: 'b1', amountFen: 90000)),
        _item(
          _imported(
            id: 'b',
            batchId: 'b2',
            amountFen: 60000,
            status: ExternalWorkRecordStatus.voided,
          ),
        ),
        _item(
          _imported(id: 'c', batchId: 'b3', amountFen: 30000),
          batchStatus: ExternalImportBatchStatus.archived,
        ),
      ];

      final rollup = rollupExternalWorkReceivable(items);

      expect(rollup.totalReceivableFen, 90000);
    });
  });

  group('augmentComputedWithExternalWork', () {
    test('adds linked external receivable to project card and overview', () {
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

      // 一个项目关联多个 importBatch：总应收累加（¥900 + ¥600）。
      expect(projectA.receivable, 2500);
      expect(projectA.remaining, 2500);
      expect(projectA.externalWorkHours, 2.0);
      expect(projectA.displayName, '李洋 · 天眉乐');
      expect(projectA.hasLinkedExternalWork, isTrue);
      // 未关联外协包不并入项目卡片。
      expect(projectB.receivable, 500);
      expect(projectB.displayName, isNot(contains('关联')));
      expect(projectB.hasLinkedExternalWork, isFalse);
      // 总览总应收包含全部外协设备应收（含未关联包），每包只计一次。
      expect(augmented.totalReceivable, 1500 + 1800);
      expect(augmented.totalRemaining, 1500 + 1800);
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

      expect(projectA.receivable, 1500);
      expect(projectB.receivable, 1000);
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

      expect(mergedAugmented.receivable, 2400);
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
}

AccountComputed _computed(
  List<AccountProjectVM> projects, {
  required double totalReceivable,
  required double totalRemaining,
}) {
  return AccountComputed(
    projects: projects,
    totalReceivable: totalReceivable,
    totalReceived: 0,
    totalRemaining: totalRemaining,
    totalRatio: totalReceivable <= 0 ? null : 0,
    deviceReceivables: const [],
  );
}

AccountProjectVM _project({
  required String id,
  String? displayName,
  required double receivable,
}) {
  return AccountProjectVM(
    projectId: id,
    projectKey: id,
    displayName: displayName ?? id,
    minYmd: 20260101,
    deviceIds: const [],
    hoursByDevice: const {},
    rentIncomeTotal: 0,
    minRate: null,
    isMultiDevice: false,
    isMultiMode: false,
    receivable: receivable,
    received: 0,
    remaining: receivable,
    ratio: 0,
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
    linkedProjectId: linkedProjectId,
    status: status,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}
