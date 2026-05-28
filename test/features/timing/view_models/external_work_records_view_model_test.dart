import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:asset_ledger/features/timing/view_models/external_work_records_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// 阶段 C Step 7：外协记录列表展示 VM builder 单测。
///
/// 锁定从 pattern 上移过来的"分组 / 标题 fallback / 状态 / 摘要"业务判断，
/// 保证行为与原 pattern 一致。
void main() {
  group('ExternalWorkRecordsViewModelBuilder.build', () {
    test('空列表 → isEmpty', () {
      final vm = ExternalWorkRecordsViewModelBuilder.build(const []);
      expect(vm.isEmpty, isTrue);
      expect(vm.yearGroups, isEmpty);
    });

    test('同一 import batch 聚合成一个包，汇总工时 / 记录数 / 设备摘要', () {
      final items = [
        _item(
          record: _record(
            id: 'r1',
            siteSnapshot: '鲜滩',
            equipmentBrand: 'Hitachi',
            workDate: 20260323,
            hoursMilli: 50000,
          ),
        ),
        _item(
          record: _record(
            id: 'r2',
            sourceRecordUuid: 'src-2',
            siteSnapshot: '尚义',
            equipmentBrand: 'SANY',
            workDate: 20260324,
            hoursMilli: 60000,
          ),
        ),
      ];

      final vm = ExternalWorkRecordsViewModelBuilder.build(items);
      expect(vm.yearGroups, hasLength(1));
      expect(vm.yearGroups.single.year, 2026);

      final packages = vm.yearGroups.single.sourceGroups
          .expand((g) => g.packages)
          .toList();
      expect(packages, hasLength(1));

      final pkg = packages.single;
      expect(pkg.isAggregate, isTrue);
      expect(pkg.recordCount, 2);
      // 标题：分享人 · 工地（去重拼接）。
      expect(pkg.title, '余远 · 鲜滩、尚义');
      // 设备摘要：首台 + 等N台。
      expect(pkg.equipmentSummaryMain, 'Hitachi');
      expect(pkg.equipmentSummarySuffix, '等2台');
      expect(pkg.recordCountLabel, '•2条记录');
      // 总工时 = 50 + 60 = 110（FormatUtils.hours 口径）。
      expect(pkg.hoursText, '110.0 h');
      expect(pkg.hasLinkedRecord, isFalse);
      // 代表记录 = 排序后的第一条（最早工作日）。
      expect(pkg.representativeItem.record.id, 'r1');
      // 子记录按倒序展示（最新在前）。
      expect(pkg.childRows.map((r) => r.item.record.id).toList(), [
        'r2',
        'r1',
      ]);
    });

    test('标题 fallback：batch.sourceDisplayName 为空时退到 collaboratorName', () {
      final item = _item(
        batch: _batch(sourceDisplayName: '   '),
        record: _record(collaboratorName: '张三', siteSnapshot: '工地A'),
      );
      final vm = ExternalWorkRecordsViewModelBuilder.build([item]);
      final pkg = vm.yearGroups.single.sourceGroups.single.packages.single;
      expect(pkg.title, '张三 · 工地A');
    });

    test('linkedProjectId 非空 → hasLinkedRecord = true', () {
      final item = _item(
        record: _record(linkedProjectId: 'project:alpha'),
      );
      final vm = ExternalWorkRecordsViewModelBuilder.build([item]);
      final pkg = vm.yearGroups.single.sourceGroups.single.packages.single;
      expect(pkg.hasLinkedRecord, isTrue);
      expect(pkg.childRows.single.isLinked, isTrue);
    });

    test('linkedProjectId 为空 → hasLinkedRecord = false', () {
      final item = _item(record: _record(linkedProjectId: null));
      final vm = ExternalWorkRecordsViewModelBuilder.build([item]);
      final pkg = vm.yearGroups.single.sourceGroups.single.packages.single;
      expect(pkg.hasLinkedRecord, isFalse);
      expect(pkg.childRows.single.isLinked, isFalse);
    });

    test('单条记录：非聚合，无记录数标签，工时为该条工时', () {
      final item = _item(
        record: _record(hoursMilli: 30000, equipmentBrand: 'Komatsu'),
      );
      final vm = ExternalWorkRecordsViewModelBuilder.build([item]);
      final pkg = vm.yearGroups.single.sourceGroups.single.packages.single;
      expect(pkg.isAggregate, isFalse);
      expect(pkg.recordCount, 1);
      expect(pkg.recordCountLabel, isNull);
      expect(pkg.equipmentSummaryMain, 'Komatsu');
      expect(pkg.equipmentSummarySuffix, isNull);
      expect(pkg.hoursText, '30.0 h');
    });

    test('不同来源分享人 → 拆成不同 source group', () {
      final items = [
        _item(
          batch: _batch(id: 'batch-a', sourceDisplayName: '余远'),
          record: _record(id: 'r1', importBatchId: 'batch-a'),
        ),
        _item(
          batch: _batch(id: 'batch-b', sourceDisplayName: '张三'),
          record: _record(id: 'r2', importBatchId: 'batch-b'),
        ),
      ];
      final vm = ExternalWorkRecordsViewModelBuilder.build(items);
      expect(vm.yearGroups, hasLength(1));
      final sourceGroups = vm.yearGroups.single.sourceGroups;
      expect(sourceGroups, hasLength(2));
    });

    test('aggregateKeys / topLevelCount 与分组一致', () {
      final items = [
        _item(
          batch: _batch(id: 'batch-a'),
          record: _record(id: 'r1', importBatchId: 'batch-a'),
        ),
        _item(
          batch: _batch(id: 'batch-a'),
          record: _record(id: 'r2', importBatchId: 'batch-a'),
        ),
        _item(
          batch: _batch(id: 'batch-b'),
          record: _record(id: 'r3', importBatchId: 'batch-b'),
        ),
      ];
      expect(ExternalWorkRecordsViewModelBuilder.topLevelCount(items), 2);
      expect(
        ExternalWorkRecordsViewModelBuilder.aggregateKeys(items),
        {'batch-batch-a', 'batch-batch-b'},
      );
    });
  });
}

TimingExternalWorkRecordItem _item({
  ExternalImportBatch? batch,
  ExternalWorkRecord? record,
}) {
  final resolvedBatch = batch ?? _batch();
  final resolvedRecord = (record ?? _record()).copyWith(
    importBatchId: resolvedBatch.id,
  );
  return TimingExternalWorkRecordItem(
    record: resolvedRecord,
    batch: resolvedBatch,
  );
}

ExternalImportBatch _batch({
  String id = 'batch-1',
  String sourceShareId = 'share-1',
  String sourceDisplayName = '余远',
  String siteSummary = '合并2项目',
  String importedAt = '2026-03-30T08:00:00.000Z',
}) {
  return ExternalImportBatch(
    id: id,
    sourceShareId: sourceShareId,
    sourceDisplayName: sourceDisplayName,
    recordCount: 1,
    totalHoursMilli: 1000,
    totalAmountFen: 1000,
    siteSummary: siteSummary,
    importedAt: importedAt,
    createdAt: importedAt,
    updatedAt: importedAt,
  );
}

ExternalWorkRecord _record({
  String id = 'record-1',
  String importBatchId = 'batch-1',
  String sourceShareId = 'share-1',
  String sourceRecordUuid = 'source-1',
  String collaboratorName = '余远',
  String siteSnapshot = '五里山',
  String equipmentBrand = 'Hitachi',
  String? equipmentModel = 'ZX200',
  String equipmentType = '挖机',
  int workDate = 20260323,
  int hoursMilli = 1000,
  String? linkedProjectId,
}) {
  return ExternalWorkRecord(
    id: id,
    importBatchId: importBatchId,
    sourceShareId: sourceShareId,
    sourceRecordUuid: sourceRecordUuid,
    sourceInstallationUuid: 'installation-1',
    originFingerprint: 'fingerprint-$id',
    collaboratorName: collaboratorName,
    contactSnapshot: '联系人',
    siteSnapshot: siteSnapshot,
    equipmentBrand: equipmentBrand,
    equipmentModel: equipmentModel,
    equipmentType: equipmentType,
    workDate: workDate,
    hoursMilli: hoursMilli,
    sourceUnitPriceFen: 1000,
    localUnitPriceFen: null,
    amountFen: 1000,
    projectReceivedFen: 0,
    linkedProjectId: linkedProjectId,
    createdAt: '2026-03-30T08:00:00.000Z',
    updatedAt: '2026-03-30T08:00:00.000Z',
  );
}
