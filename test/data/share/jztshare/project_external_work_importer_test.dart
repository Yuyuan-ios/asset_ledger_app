import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/repositories/external_import_repository.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_import_preview.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_import_result.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_importer.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_parser.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('ProjectExternalWorkImporter', () {
    const importer = ProjectExternalWorkImporter();

    test(
      'builds an import preview with summaries and duplicate status',
      () async {
        await _openCurrentInMemoryDb();
        final parsed = _parsed(
          lines: [
            _line(siteSnapshot: '一号工地', hoursMilli: 1000, unitPriceFen: 30000),
            _line(
              exportLineUuid: 'line-2',
              originFingerprint: 'fingerprint-2',
              siteSnapshot: '二号工地',
              hoursMilli: 500,
              unitPriceFen: 40000,
            ),
          ],
        );

        final preview = await importer.buildPreview(parsed);

        expect(preview.shareId, 'share-1');
        expect(preview.senderName, '王师傅');
        expect(preview.sourceInstallationUuid, 'install-1');
        expect(preview.recordCount, 2);
        expect(preview.totalHoursMilli, 1500);
        expect(
          preview.totalAmountFen,
          _amountFen(hoursMilli: 1000, unitPriceFen: 30000) +
              _amountFen(hoursMilli: 500, unitPriceFen: 40000),
        );
        expect(preview.siteSummary, '一号工地、二号工地');
        expect(preview.duplicateSummary.hasBlockingDuplicates, isFalse);
        expect(preview.lines.map((line) => line.duplicateStatus).toSet(), {
          ExternalWorkDuplicateStatus.none,
        });
      },
    );

    test('imports batch and records without touching core tables', () async {
      final db = await _openCurrentInMemoryDb();
      final parsed = _parsed(
        lines: [
          _line(sourceUnitPriceFen: 30000),
          _line(
            exportLineUuid: 'line-2',
            originFingerprint: 'fingerprint-2',
            sourceUnitPriceFen: 38000,
          ),
        ],
      );

      final result = await importer.importParsed(
        parsed,
        importedAt: '2026-05-18T00:00:00.000Z',
      );

      expect(result.status, ProjectExternalWorkImportStatus.imported);
      expect(result.insertedRecordCount, 2);
      final batches = await db.query('external_import_batches');
      expect(batches, hasLength(1));
      expect(batches.single['source_share_id'], 'share-1');
      expect(batches.single['record_count'], 2);

      final records = await db.query(
        'external_work_records',
        orderBy: 'source_record_uuid ASC',
      );
      expect(records, hasLength(2));
      expect(records.first['linked_project_id'], isNull);
      expect(records.first['local_unit_price_fen'], 30000);
      expect(records.first['source_unit_price_fen'], 30000);
      expect(records.first['amount_fen'], _amountFen(unitPriceFen: 30000));
      expect(await db.query('timing_records'), isEmpty);
      expect(await db.query('account_payments'), isEmpty);
      expect(await db.query('projects'), isEmpty);
      expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);
    });

    test('rejects duplicate share_id without inserting new rows', () async {
      final db = await _openCurrentInMemoryDb();
      final parsed = _parsed();

      await importer.importParsed(
        parsed,
        importedAt: '2026-05-18T00:00:00.000Z',
      );
      final result = await importer.importParsed(
        parsed,
        importedAt: '2026-05-18T01:00:00.000Z',
      );

      expect(result.status, ProjectExternalWorkImportStatus.rejectedDuplicate);
      expect(result.insertedRecordCount, 0);
      expect(result.preview.duplicateSummary.sameShareAlreadyImported, isTrue);
      expect(
        result.preview.lines.single.duplicateStatus,
        ExternalWorkDuplicateStatus.sameShareAlreadyImported,
      );
      expect(await db.query('external_import_batches'), hasLength(1));
      expect(await db.query('external_work_records'), hasLength(1));
    });

    test('rejects duplicate source share and record UUID', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedExistingRecord(
        batchId: 'legacy-batch',
        batchSourceShareId: 'legacy-share',
        recordId: 'legacy-record',
        sourceShareId: 'share-1',
        sourceRecordUuid: 'line-1',
        originFingerprint: 'legacy-fingerprint',
      );

      final result = await importer.importParsed(_parsed());

      expect(result.status, ProjectExternalWorkImportStatus.rejectedDuplicate);
      expect(result.preview.duplicateSummary.sameShareAlreadyImported, isFalse);
      expect(result.preview.duplicateSummary.sameSourceRecordCount, 1);
      expect(
        result.preview.lines.single.duplicateStatus,
        ExternalWorkDuplicateStatus.sameSourceRecordAlreadyImported,
      );
      expect(await db.query('external_import_batches'), hasLength(1));
      expect(await db.query('external_work_records'), hasLength(1));
    });

    test('marks origin fingerprint duplicates as suspicious only', () async {
      final db = await _openCurrentInMemoryDb();
      await _seedExistingRecord(
        batchId: 'legacy-batch',
        batchSourceShareId: 'legacy-share',
        recordId: 'legacy-record',
        sourceShareId: 'legacy-share',
        sourceRecordUuid: 'legacy-line',
        originFingerprint: 'fingerprint-1',
      );

      final preview = await importer.buildPreview(_parsed());
      expect(preview.duplicateSummary.sameOriginFingerprintCount, 1);
      expect(preview.duplicateSummary.hasBlockingDuplicates, isFalse);
      expect(preview.duplicateSummary.hasSuspiciousDuplicates, isTrue);
      expect(
        preview.lines.single.duplicateStatus,
        ExternalWorkDuplicateStatus.sameOriginFingerprintAlreadyImported,
      );

      final result = await importer.importParsed(
        _parsed(),
        importedAt: '2026-05-18T00:00:00.000Z',
      );

      expect(result.status, ProjectExternalWorkImportStatus.imported);
      expect(await db.query('external_work_records'), hasLength(2));
    });

    test('rolls back batch and records when one record insert fails', () async {
      final db = await _openCurrentInMemoryDb();
      final parsed = _parsed(
        lines: [
          _line(exportLineUuid: 'line-1', originFingerprint: 'fingerprint-1'),
          _line(exportLineUuid: 'line-1', originFingerprint: 'fingerprint-2'),
        ],
      );

      await expectLater(
        importer.importParsed(parsed, importedAt: '2026-05-18T00:00:00.000Z'),
        throwsA(isA<DatabaseException>()),
      );

      expect(await db.query('external_import_batches'), isEmpty);
      expect(await db.query('external_work_records'), isEmpty);
      expect(await db.rawQuery('PRAGMA foreign_key_check;'), isEmpty);
    });

    test('keeps ignored archived and voided external work rows', () async {
      await _openCurrentInMemoryDb();
      final recordRepo = SqfliteExternalWorkRecordRepository();
      await importer.importParsed(
        _parsed(
          lines: [
            _line(exportLineUuid: 'line-ignored'),
            _line(
              exportLineUuid: 'line-archived',
              originFingerprint: 'fingerprint-archived',
            ),
            _line(
              exportLineUuid: 'line-voided',
              originFingerprint: 'fingerprint-voided',
            ),
          ],
        ),
        importedAt: '2026-05-18T00:00:00.000Z',
      );

      await recordRepo.updateLocalFields(
        recordId: 'external:share-1:line-ignored',
        status: ExternalWorkRecordStatus.ignored,
        updatedAt: '2026-05-18T01:00:00.000Z',
      );
      await recordRepo.updateLocalFields(
        recordId: 'external:share-1:line-archived',
        status: ExternalWorkRecordStatus.archived,
        updatedAt: '2026-05-18T01:00:00.000Z',
      );
      await recordRepo.updateLocalFields(
        recordId: 'external:share-1:line-voided',
        status: ExternalWorkRecordStatus.voided,
        updatedAt: '2026-05-18T01:00:00.000Z',
      );

      final records = await recordRepo.listByBatchId('share-1');
      expect(records, hasLength(3));
      expect(records.map((record) => record.status).toSet(), {
        ExternalWorkRecordStatus.ignored,
        ExternalWorkRecordStatus.archived,
        ExternalWorkRecordStatus.voided,
      });
    });

    test(
      'rejects external line amounts that do not match AmountPolicy',
      () async {
        await _openCurrentInMemoryDb();
        final parsed = _parsed(
          lines: [
            _line(
              sourceUnitPriceFen: 38000,
              amountFen: _amountFen(unitPriceFen: 38000) + 1,
            ),
          ],
        );

        expect(
          () => importer.buildPreview(parsed),
          throwsA(
            isA<ProjectExternalWorkImportException>().having(
              (error) => error.code,
              'code',
              ProjectExternalWorkImportErrorCodes.amountMismatch,
            ),
          ),
        );
      },
    );
  });
}

ParsedProjectExternalWorkShare _parsed({
  String shareId = 'share-1',
  List<Map<String, Object?>>? lines,
}) {
  return const JztShareEnvelopeParser().parseProjectExternalWorkShare(
    _encodedEnvelope(shareId: shareId, lines: lines),
  );
}

String _encodedEnvelope({
  required String shareId,
  List<Map<String, Object?>>? lines,
}) {
  final payload = <String, Object?>{
    'share_id': shareId,
    'sender_name': '王师傅',
    'source_installation_uuid': 'install-1',
    'export_lines': lines ?? [_line()],
  };
  final envelope = <String, Object?>{
    'magic': JztShareEnvelope.magicValue,
    'format_version': JztShareEnvelope.supportedFormatVersion,
    'package_type': JztShareEnvelope.projectExternalWorkShareType,
    'producer': {'app_name': '机账通', 'app_version': '1.0.1', 'platform': 'ios'},
    'created_at': '2026-05-18T00:00:00.000Z',
    'share_id': shareId,
    'integrity': {
      'payload_encoding': JztShareEnvelope.jsonPayloadEncoding,
      'payload_sha256': JztShareEnvelopeValidator.payloadSha256(payload),
    },
    'payload': payload,
  };
  return jsonEncode(envelope);
}

Map<String, Object?> _line({
  String exportLineUuid = 'line-1',
  String originFingerprint = 'fingerprint-1',
  String siteSnapshot = '一号工地',
  int hoursMilli = 1500,
  int? sourceUnitPriceFen,
  int? unitPriceFen,
  int? amountFen,
}) {
  final effectiveUnitPriceFen = sourceUnitPriceFen ?? unitPriceFen ?? 38000;
  return {
    'export_line_uuid': exportLineUuid,
    'origin_fingerprint': originFingerprint,
    'contact_snapshot': '甲方',
    'site_snapshot': siteSnapshot,
    'equipment_brand': '三一',
    'equipment_model': '75',
    'equipment_type': 'excavator',
    'work_date': 20260518,
    'hours_milli': hoursMilli,
    'source_unit_price_fen': effectiveUnitPriceFen,
    'amount_fen':
        amountFen ??
        _amountFen(hoursMilli: hoursMilli, unitPriceFen: effectiveUnitPriceFen),
    'note': '现场记录',
  };
}

int _amountFen({int hoursMilli = 1500, required int unitPriceFen}) {
  return ExternalWorkRecord.calculateAmountFen(
    hoursMilli: hoursMilli,
    unitPriceFen: unitPriceFen,
  );
}

Future<void> _seedExistingRecord({
  required String batchId,
  required String batchSourceShareId,
  required String recordId,
  required String sourceShareId,
  required String sourceRecordUuid,
  required String originFingerprint,
}) async {
  const now = '2026-05-18T00:00:00.000Z';
  await SqfliteExternalImportRepository().insertBatch(
    ExternalImportBatch(
      id: batchId,
      sourceShareId: batchSourceShareId,
      sourceDisplayName: '既有导入',
      recordCount: 1,
      totalHoursMilli: 1500,
      totalAmountFen: _amountFen(unitPriceFen: 38000),
      siteSummary: '一号工地',
      importedAt: now,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await SqfliteExternalWorkRecordRepository().insertRecord(
    ExternalWorkRecord.create(
      id: recordId,
      importBatchId: batchId,
      sourceShareId: sourceShareId,
      sourceRecordUuid: sourceRecordUuid,
      sourceInstallationUuid: 'existing-install',
      originFingerprint: originFingerprint,
      collaboratorName: '既有师傅',
      contactSnapshot: '甲方',
      siteSnapshot: '一号工地',
      workDate: 20260518,
      hoursMilli: 1500,
      sourceUnitPriceFen: 38000,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<Database> _openCurrentInMemoryDb() {
  AppDatabase.debugInitDbOverride = () {
    return openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase.schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) async {
        await DbSchema.create(db);
      },
    );
  };
  return AppDatabase.database;
}
