import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/features/account/view/account_page_view_data.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'buildAccountExternalWorkProjects groups fully unlinked active batches',
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

      expect(projects, hasLength(1));
      expect(projects.single.importBatchId, 'batch-unlinked');
      expect(projects.single.displayName, '余远+鲜滩+尚义');
      expect(projects.single.minYmd, 20260501);
      expect(projects.single.payableFen, 1261800);
      expect(projects.single.payable, 12618);
      expect(projects.single.recordCount, 2);
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
    amountFen: amountFen,
    linkedProjectId: linkedProjectId,
    createdAt: '2026-05-24T00:00:00.000',
    updatedAt: '2026-05-24T00:00:00.000',
  );
}
