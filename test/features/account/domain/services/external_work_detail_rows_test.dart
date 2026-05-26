import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/features/account/domain/services/external_work_detail_rows.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExternalImportBatch batch({
    String id = 'batch-1',
    String sourceDisplayName = '余远',
    String siteSummary = '五里山',
    String importedAt = '2026-05-15T08:00:00.000Z',
  }) {
    return ExternalImportBatch(
      id: id,
      sourceShareId: 'share-$id',
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

  ExternalWorkRecord record({
    String id = 'r-1',
    String importBatchId = 'batch-1',
    String siteSnapshot = '五里山',
    String collaboratorName = '余远',
    String? brand = 'Hitachi',
    String? model,
    String? type,
    int hoursMilli = 7000,
    int amountFen = 12600,
    int sourceUnitPriceFen = 18000,
    String? linkedProjectId = 'project:abc',
    ExternalWorkRecordStatus status = ExternalWorkRecordStatus.active,
    String createdAt = '2026-05-15T09:00:00.000Z',
  }) {
    return ExternalWorkRecord(
      id: id,
      importBatchId: importBatchId,
      sourceShareId: 'share-1',
      sourceRecordUuid: 'src-$id',
      sourceInstallationUuid: 'inst-1',
      originFingerprint: 'fp-1',
      collaboratorName: collaboratorName,
      contactSnapshot: '张三',
      siteSnapshot: siteSnapshot,
      equipmentBrand: brand,
      equipmentModel: model,
      equipmentType: type,
      workDate: 20260501,
      hoursMilli: hoursMilli,
      sourceUnitPriceFen: sourceUnitPriceFen,
      localUnitPriceFen: sourceUnitPriceFen,
      amountFen: amountFen,
      linkedProjectId: linkedProjectId,
      status: status,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  TimingExternalWorkRecordItem item(
    ExternalWorkRecord r, {
    ExternalImportBatch? b,
  }) {
    return TimingExternalWorkRecordItem(record: r, batch: b);
  }

  test('returns empty when target id set is empty', () {
    final out = buildAccountProjectExternalWorkDetailRows(
      externalWorkItems: [item(record())],
      projectIdentityIds: const {},
    );
    expect(out, isEmpty);
  });

  test('filters by linkedProjectId and skips non-active records', () {
    final b1 = batch();
    final items = [
      item(record(id: 'r-active', linkedProjectId: 'project:abc'), b: b1),
      item(
        record(
          id: 'r-ignored',
          linkedProjectId: 'project:abc',
          status: ExternalWorkRecordStatus.ignored,
        ),
        b: b1,
      ),
      item(
        record(id: 'r-other', linkedProjectId: 'project:xyz'),
        b: b1,
      ),
      item(record(id: 'r-unlinked', linkedProjectId: null), b: b1),
    ];

    final out = buildAccountProjectExternalWorkDetailRows(
      externalWorkItems: items,
      projectIdentityIds: const {'project:abc'},
    );

    expect(out, hasLength(1));
    expect(out.first.recordCount, 1);
    expect(out.first.linkedProjectId, 'project:abc');
  });

  test('aggregates by importBatchId producing equipment summary and hours', () {
    final b1 = batch(id: 'batch-1');
    final items = [
      item(record(id: 'r1', importBatchId: 'batch-1', brand: 'Hitachi'), b: b1),
      item(
        record(
          id: 'r2',
          importBatchId: 'batch-1',
          brand: 'Hitachi',
          hoursMilli: 3000,
        ),
        b: b1,
      ),
      item(
        record(
          id: 'r3',
          importBatchId: 'batch-1',
          brand: 'Sany',
          hoursMilli: 5000,
        ),
        b: b1,
      ),
    ];

    final out = buildAccountProjectExternalWorkDetailRows(
      externalWorkItems: items,
      projectIdentityIds: const {'project:abc'},
    );

    expect(out, hasLength(1));
    final row = out.first;
    expect(row.recordCount, 3);
    expect(row.equipmentSummary, 'Hitachi等2台');
    expect(row.hours, closeTo(15.0, 1e-6));
    expect(row.sourceDisplayName, '余远');
    expect(row.siteSummary, '五里山');
  });

  test('orders batches by importedAt desc then by importBatchId', () {
    final older = batch(
      id: 'batch-old',
      importedAt: '2026-04-01T08:00:00.000Z',
    );
    final newer = batch(
      id: 'batch-new',
      importedAt: '2026-05-10T08:00:00.000Z',
    );
    final items = [
      item(record(id: 'r-old', importBatchId: 'batch-old'), b: older),
      item(record(id: 'r-new', importBatchId: 'batch-new'), b: newer),
    ];

    final out = buildAccountProjectExternalWorkDetailRows(
      externalWorkItems: items,
      projectIdentityIds: const {'project:abc'},
    );

    expect(out.map((row) => row.importBatchId).toList(), [
      'batch-new',
      'batch-old',
    ]);
  });

  test('falls back to model / type when brand is empty', () {
    final out = buildAccountProjectExternalWorkDetailRows(
      externalWorkItems: [
        item(
          record(brand: null, model: 'ZX200'),
          b: batch(),
        ),
      ],
      projectIdentityIds: const {'project:abc'},
    );

    expect(out, hasLength(1));
    expect(out.first.equipmentSummary, 'ZX200');
  });
}
