import 'package:asset_ledger/core/money/amount_policy.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_parse.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExternalImportBatch', () {
    test('fromMap parses status defensively', () {
      final batch = ExternalImportBatch.fromMap(_batchMap(status: 'ignored'));

      expect(batch.status, ExternalImportBatchStatus.ignored);
    });

    test('fromMap rejects invalid status without enum.byName', () {
      expect(
        () => ExternalImportBatch.fromMap(_batchMap(status: 'deleted')),
        throwsA(isA<ExternalDataParseException>()),
      );
    });
  });

  group('ExternalWorkRecord', () {
    test('create calculates amount_fen through AmountPolicy', () {
      final record = _record(hoursMilli: 1500, localUnitPriceFen: 12345);
      final expected = AmountPolicy.calculateAmount(
        hours: const WorkHours(1500),
        unitPrice: const UnitPrice(12345),
      ).fen;

      expect(record.amountFen, expected);
      expect(record.toMap()['amount_fen'], expected);
    });

    test('source and local unit prices are stored separately', () {
      final record = _record(
        sourceUnitPriceFen: 30000,
        localUnitPriceFen: 38000,
      );

      expect(record.sourceUnitPriceFen, 30000);
      expect(record.localUnitPriceFen, 38000);
      expect(record.toMap()['source_unit_price_fen'], 30000);
      expect(record.toMap()['local_unit_price_fen'], 38000);
    });

    test('project received amount is stored as a non-negative snapshot', () {
      final record = _record(projectReceivedFen: 234567);

      expect(record.projectReceivedFen, 234567);
      expect(record.toMap()['project_received_fen'], 234567);
      expect(
        ExternalWorkRecord.fromMap(record.toMap()).projectReceivedFen,
        234567,
      );
      expect(
        ExternalWorkRecord.fromMap(
          Map<String, Object?>.from(record.toMap())
            ..remove('project_received_fen'),
        ).projectReceivedFen,
        0,
      );
    });

    test('fromMap parses status defensively', () {
      final record = ExternalWorkRecord.fromMap(_recordMap(status: 'archived'));

      expect(record.status, ExternalWorkRecordStatus.archived);
    });

    test('fromMap rejects invalid status without enum.byName', () {
      expect(
        () => ExternalWorkRecord.fromMap(_recordMap(status: 'deleted')),
        throwsA(isA<ExternalDataParseException>()),
      );
    });

    test('rejects negative hours, amount, and unit prices', () {
      for (final field in [
        'hours_milli',
        'amount_fen',
        'source_unit_price_fen',
        'local_unit_price_fen',
        'project_received_fen',
      ]) {
        final map = _recordMap();
        map[field] = -1;
        expect(
          () => ExternalWorkRecord.fromMap(map),
          throwsA(isA<ExternalDataParseException>()),
          reason: field,
        );
      }
    });
  });
}

Map<String, Object?> _batchMap({String status = 'active'}) {
  return {
    'id': 'batch-1',
    'source_share_id': 'share-1',
    'source_display_name': '王师傅',
    'record_count': 1,
    'total_hours_milli': 1500,
    'total_amount_fen': 57000,
    'site_summary': '一号工地',
    'imported_at': '2026-05-18T00:00:00.000Z',
    'status': status,
    'created_at': '2026-05-18T00:00:00.000Z',
    'updated_at': '2026-05-18T00:00:00.000Z',
  };
}

ExternalWorkRecord _record({
  int hoursMilli = 1500,
  int sourceUnitPriceFen = 30000,
  int? localUnitPriceFen,
  int projectReceivedFen = 0,
}) {
  return ExternalWorkRecord.create(
    id: 'external-record-1',
    importBatchId: 'batch-1',
    sourceShareId: 'share-1',
    sourceRecordUuid: 'source-record-1',
    sourceInstallationUuid: 'install-1',
    originFingerprint: 'fingerprint-1',
    collaboratorName: '王师傅',
    contactSnapshot: '甲方',
    siteSnapshot: '一号工地',
    equipmentBrand: '三一',
    equipmentModel: '75',
    equipmentType: 'excavator',
    workDate: 20260518,
    hoursMilli: hoursMilli,
    sourceUnitPriceFen: sourceUnitPriceFen,
    localUnitPriceFen: localUnitPriceFen,
    projectReceivedFen: projectReceivedFen,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

Map<String, Object?> _recordMap({String status = 'active'}) {
  return _record().toMap()..['status'] = status;
}
