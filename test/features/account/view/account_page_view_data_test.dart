import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/features/account/model/account_view_model.dart';
import 'package:asset_ledger/features/account/view/account_page_view_data.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account overview hides inactive device distribution entries only', () {
    final visible = visibleAccountOverviewDeviceReceivables(
      deviceReceivables: const [
        AccountDeviceReceivable(deviceId: 1, name: 'SANY 1#', amount: 2600),
        AccountDeviceReceivable(deviceId: 2, name: 'HITACHI 1#', amount: 54724),
        AccountDeviceReceivable(deviceId: 99, name: '设备#99', amount: 800),
      ],
      devices: [
        Device(
          id: 1,
          name: 'SANY 1#',
          brand: 'SANY',
          defaultUnitPrice: 100,
          baseMeterHours: 0,
          isActive: false,
        ),
        Device(
          id: 2,
          name: 'HITACHI 1#',
          brand: 'HITACHI',
          defaultUnitPrice: 120,
          baseMeterHours: 0,
        ),
      ],
    );

    expect(visible.map((item) => item.deviceId).toList(), [2, 99]);
    expect(visible.map((item) => item.name).toList(), ['HITACHI 1#', '设备#99']);
  });

  test(
    'buildAccountExternalWorkProjects keeps linked batches and skips inactive',
    () {
      final unlinkedBatch = _batch(
        id: 'batch-unlinked',
        sourceDisplayName: '余远',
        siteSummary: '鲜滩+尚义',
      );
      final linkedBatch = _batch(id: 'batch-linked', sourceDisplayName: '王强');
      final archivedBatch = _batch(
        id: 'batch-archived',
        sourceDisplayName: '李敏',
        status: ExternalImportBatchStatus.archived,
      );

      final projects = buildAccountExternalWorkProjects([
        _item(
          batch: unlinkedBatch,
          record: _record(
            id: 'record-a',
            batchId: unlinkedBatch.id,
            site: '鲜滩',
            workDate: 20260503,
            amountFen: 61800,
            sourceUnitPriceFen: 18000,
          ),
        ),
        _item(
          batch: unlinkedBatch,
          record: _record(
            id: 'record-b',
            batchId: unlinkedBatch.id,
            site: '尚义',
            workDate: 20260501,
            amountFen: 1200000,
            sourceUnitPriceFen: 20000,
          ),
        ),
        _item(
          batch: linkedBatch,
          record: _record(
            id: 'record-c',
            batchId: linkedBatch.id,
            site: '西河',
            workDate: 20260504,
            amountFen: 90000,
            linkedProjectId: 'project:linked',
          ),
        ),
        _item(
          batch: linkedBatch,
          record: _record(
            id: 'record-d',
            batchId: linkedBatch.id,
            site: '西河',
            workDate: 20260505,
            amountFen: 80000,
          ),
        ),
        _item(
          batch: archivedBatch,
          record: _record(
            id: 'record-e',
            batchId: archivedBatch.id,
            site: '北坡',
            workDate: 20260506,
            amountFen: 70000,
          ),
        ),
      ]);

      // 已关联包（batch-linked）仍保留，归档包（batch-archived）被排除。
      expect(projects, hasLength(2));

      final unlinked = projects.firstWhere(
        (project) => project.importBatchId == 'batch-unlinked',
      );
      expect(unlinked.displayName, '余远 · 鲜滩、尚义');
      expect(unlinked.minYmd, 20260501);
      expect(unlinked.payableFen, 1261800);
      expect(unlinked.payable, 12618);
      expect(unlinked.recordCount, 2);
      expect(unlinked.sourceUnitPriceText, '¥180/h, ¥200/h');
      expect(unlinked.linked, isFalse);
      expect(unlinked.linkedProjectId, isNull);

      final linked = projects.firstWhere(
        (project) => project.importBatchId == 'batch-linked',
      );
      expect(linked.linked, isTrue);
      expect(linked.linkedProjectId, 'project:linked');
      expect(linked.payableFen, 170000);

      expect(
        projects.any((project) => project.importBatchId == 'batch-archived'),
        isFalse,
      );
    },
  );
}

TimingExternalWorkRecordItem _item({
  required ExternalImportBatch batch,
  required ExternalWorkRecord record,
}) {
  return TimingExternalWorkRecordItem(record: record, batch: batch);
}

ExternalImportBatch _batch({
  required String id,
  required String sourceDisplayName,
  String siteSummary = '',
  ExternalImportBatchStatus status = ExternalImportBatchStatus.active,
}) {
  return ExternalImportBatch(
    id: id,
    sourceShareId: 'share-$id',
    sourceDisplayName: sourceDisplayName,
    recordCount: 1,
    totalHoursMilli: 1000,
    totalAmountFen: 10000,
    siteSummary: siteSummary,
    importedAt: '2026-05-24T00:00:00.000',
    status: status,
    createdAt: '2026-05-24T00:00:00.000',
    updatedAt: '2026-05-24T00:00:00.000',
  );
}

ExternalWorkRecord _record({
  required String id,
  required String batchId,
  required String site,
  required int workDate,
  required int amountFen,
  int? sourceUnitPriceFen,
  String? linkedProjectId,
}) {
  return ExternalWorkRecord.imported(
    id: id,
    importBatchId: batchId,
    sourceShareId: 'share-$batchId',
    sourceRecordUuid: 'source-$id',
    sourceInstallationUuid: 'installation-$id',
    originFingerprint: 'fingerprint-$id',
    collaboratorName: '余远',
    contactSnapshot: '余远',
    siteSnapshot: site,
    workDate: workDate,
    hoursMilli: 1000,
    sourceUnitPriceFen: sourceUnitPriceFen,
    amountFen: amountFen,
    linkedProjectId: linkedProjectId,
    createdAt: '2026-05-24T00:00:00.000',
    updatedAt: '2026-05-24T00:00:00.000',
  );
}
