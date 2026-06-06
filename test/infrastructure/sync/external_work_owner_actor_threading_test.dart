import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/repositories/external_import_repository.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_importer.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_parser.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_validator.dart';
import 'package:asset_ledger/infrastructure/local/account/project_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/account/project_write_off_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/timing/external_work_sync_enqueuer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.25-Hardening-followup: runtime coverage of the persisted-owner actor
/// across every external-work cluster entry point.
///
/// Targets:
/// - [ProjectExternalWorkImporter.importParsed] (N external_work creates
///   inside one transaction group).
/// - [SqfliteExternalWorkRecordRepository.linkBatchToProjectWithSettlementReset]
///   (cross-entity cluster: external_work updates + project_write_off deletes
///    + project status update).
///
/// Each test confirms:
/// - every outbox payload carries `actor.id` equal to the injected owner id;
/// - the `actor` object always includes the `session_id` key (null or value);
/// - `entity_sync_meta.updated_by` mirrors the same id on every row;
/// - one cluster shares one `transaction_group_id` and a dense
///   `local_sequence`;
/// - the business `record` stays free of `actor` / `payload_schema_version`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  ActorContext owner({String id = 'owner-extwk-1', String? sessionId}) =>
      ActorContext(
        actorType: OperationActorType.owner,
        actorId: id,
        sessionId: sessionId,
      );

  group('ProjectExternalWorkImporter.importParsed', () {
    test(
      'N external_work create rows in one cluster all carry the injected '
      'owner actor; meta.updated_by mirrors; record stays untouched',
      () async {
        final db = await _openCurrentInMemoryDb();
        final injected = owner(id: 'owner-import-1', sessionId: 'session-im');
        final importer = ProjectExternalWorkImporter(
          actorProvider: () => injected,
        );

        final parsed = _parsed(lines: [
          _line(),
          _line(
            exportLineUuid: 'line-2',
            originFingerprint: 'fingerprint-2',
            sourceUnitPriceFen: 40000,
          ),
          _line(
            exportLineUuid: 'line-3',
            originFingerprint: 'fingerprint-3',
            sourceUnitPriceFen: 50000,
          ),
        ]);

        await importer.importParsed(
          parsed,
          importedAt: '2026-05-18T00:00:00.000Z',
        );

        final rows = await db.query(
          'sync_outbox',
          orderBy: 'local_sequence ASC',
        );
        expect(rows, hasLength(3));

        // All rows are external_work_record creates inside one group.
        for (final row in rows) {
          expect(row['entity_type'], ExternalWorkSyncEnqueuer.entityType);
          expect(row['operation'], 'create');
        }
        final groupIds = rows.map((r) => r['transaction_group_id']).toSet();
        expect(groupIds, hasLength(1));
        expect(groupIds.single as String?, startsWith('txn-'));
        expect(
          rows.map((r) => r['local_sequence']).toList(),
          <int>[1, 2, 3],
        );

        // Every payload carries the same injected actor; record is plain.
        for (final row in rows) {
          final payload = (jsonDecode(row['payload_json'] as String) as Map)
              .cast<String, Object?>();
          expect(payload['payload_schema_version'], 1);
          final actor = payload['actor'] as Map<String, Object?>;
          expect(actor['type'], 'owner');
          expect(actor['id'], 'owner-import-1');
          expect(actor['session_id'], 'session-im');
          final record = payload['record'] as Map<String, Object?>;
          expect(record.containsKey('actor'), isFalse);
          expect(record.containsKey('payload_schema_version'), isFalse);
        }

        final meta = await db.query('entity_sync_meta');
        expect(meta, hasLength(3));
        expect(
          meta.map((r) => r['updated_by']).toSet(),
          {'owner-import-1'},
          reason: 'every meta row must mirror payload.actor.id',
        );
      },
    );

    test('legacy/test fallback: no provider → null id on every payload row',
        () async {
      final db = await _openCurrentInMemoryDb();
      const importer = ProjectExternalWorkImporter();
      await importer.importParsed(
        _parsed(lines: [_line(), _line(exportLineUuid: 'line-2', originFingerprint: 'fp-2')]),
        importedAt: '2026-05-18T00:00:00.000Z',
      );

      final rows = await db.query('sync_outbox');
      expect(rows, hasLength(2));
      for (final row in rows) {
        final payload = (jsonDecode(row['payload_json'] as String) as Map)
            .cast<String, Object?>();
        final actor = payload['actor'] as Map<String, Object?>;
        expect(actor['type'], 'owner');
        expect(actor['id'], isNull,
            reason: 'no provider → documented owner-app fallback null id');
        expect(actor.containsKey('session_id'), isTrue);
      }
      final meta = await db.query('entity_sync_meta');
      expect(meta.map((r) => r['updated_by']).toSet(), {null});
    });
  });

  group('SqfliteExternalWorkRecordRepository.'
      'linkBatchToProjectWithSettlementReset', () {
    test(
      'cross-entity cluster (ext-work updates + write-off deletes + project '
      'update) all carry the same injected actor; group/sequence dense; '
      'meta.updated_by mirrors',
      () async {
        final db = await _openCurrentInMemoryDb();
        final importRepo = SqfliteExternalImportRepository();
        final injected = owner(id: 'owner-reset-1');
        final recordRepo = SqfliteExternalWorkRecordRepository(
          actorProvider: () => injected,
        );

        // Seed a settled project with two write-offs.
        await db.insert(
          'projects',
          _project(
            id: 'project:a',
            status: ProjectStatus.settled,
            settledAt: '2026-05-19T00:00:00.000Z',
            settledSnapshot: '{"remaining":0}',
          ).toMap(),
        );
        for (final w in [
          _writeOff('project:a', id: 'writeoff-a-1'),
          _writeOff(
            'project:a',
            id: 'writeoff-a-2',
            amount: 50.25,
            note: 'tail',
            writeOffDate: '2026-05-20',
          ),
        ]) {
          await db.insert('project_write_offs', w.toMap());
        }
        await importRepo.insertBatch(_batch());
        await recordRepo.insertRecords([
          _record(id: 'external-record-a', sourceRecordUuid: 'source-a'),
          _record(id: 'external-record-b', sourceRecordUuid: 'source-b'),
        ]);

        final linked = await recordRepo.linkBatchToProjectWithSettlementReset(
          importBatchId: 'batch-1',
          projectId: 'project:a',
          updatedAt: '2026-05-20T00:00:00.000Z',
        );
        expect(linked, 2);

        // 2 external_work updates + 2 write-off deletes + 1 project update = 5.
        final rows = await db.query(
          'sync_outbox',
          orderBy: 'local_sequence ASC',
        );
        expect(rows, hasLength(5));

        // Single shared group, dense 1..5.
        final groupIds = rows.map((r) => r['transaction_group_id']).toSet();
        expect(groupIds, hasLength(1));
        expect(groupIds.single as String?, startsWith('txn-'));
        expect(
          rows.map((r) => r['local_sequence']).toList(),
          <int>[1, 2, 3, 4, 5],
        );

        // Causal cluster: external_work updates → write-off deletes → project
        // status update.
        expect(rows[0]['entity_type'], ExternalWorkSyncEnqueuer.entityType);
        expect(rows[0]['operation'], 'update');
        expect(rows[1]['entity_type'], ExternalWorkSyncEnqueuer.entityType);
        expect(rows[1]['operation'], 'update');
        expect(rows[2]['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
        expect(rows[2]['operation'], 'delete');
        expect(rows[3]['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
        expect(rows[3]['operation'], 'delete');
        expect(rows[4]['entity_type'], ProjectSyncEnqueuer.entityType);
        expect(rows[4]['operation'], 'update');

        // Every payload carries the same injected actor; record is plain.
        final actorIds = <String?>{};
        for (final row in rows) {
          final payload = (jsonDecode(row['payload_json'] as String) as Map)
              .cast<String, Object?>();
          expect(payload['payload_schema_version'], 1);
          final actor = payload['actor'] as Map<String, Object?>;
          expect(actor['type'], 'owner');
          expect(actor.containsKey('session_id'), isTrue);
          expect(actor['session_id'], isNull);
          actorIds.add(actor['id'] as String?);
          final record = payload['record'] as Map<String, Object?>;
          expect(record.containsKey('actor'), isFalse);
          expect(record.containsKey('payload_schema_version'), isFalse);
        }
        expect(
          actorIds,
          {'owner-reset-1'},
          reason: 'all rows in the cross-entity cluster must share one actor',
        );

        final meta = await db.query('entity_sync_meta');
        expect(meta.length, greaterThanOrEqualTo(5));
        expect(
          meta.map((r) => r['updated_by']).toSet(),
          {'owner-reset-1'},
        );
      },
    );

    test(
      'deleteByBatchId: every per-row delete in the cluster carries the same '
      'injected actor',
      () async {
        final db = await _openCurrentInMemoryDb();
        final importRepo = SqfliteExternalImportRepository();
        final injected = owner(id: 'owner-batch-del-1');
        final recordRepo = SqfliteExternalWorkRecordRepository(
          actorProvider: () => injected,
        );

        await importRepo.insertBatch(_batch());
        await recordRepo.insertRecords([
          _record(id: 'external-record-a', sourceRecordUuid: 'source-a'),
          _record(id: 'external-record-b', sourceRecordUuid: 'source-b'),
          _record(id: 'external-record-c', sourceRecordUuid: 'source-c'),
        ]);

        final deleted = await recordRepo.deleteByBatchId('batch-1');
        expect(deleted, 3);

        final rows = await db.query(
          'sync_outbox',
          orderBy: 'local_sequence ASC',
        );
        expect(rows, hasLength(3));
        // All deletes in one shared group with sequence 1..3.
        final groupIds = rows.map((r) => r['transaction_group_id']).toSet();
        expect(groupIds, hasLength(1));
        expect(
          rows.map((r) => r['local_sequence']).toList(),
          <int>[1, 2, 3],
        );

        for (final row in rows) {
          expect(row['entity_type'], ExternalWorkSyncEnqueuer.entityType);
          expect(row['operation'], 'delete');
          final payload = (jsonDecode(row['payload_json'] as String) as Map)
              .cast<String, Object?>();
          final actor = payload['actor'] as Map<String, Object?>;
          expect(actor['type'], 'owner');
          expect(actor['id'], 'owner-batch-del-1');
          expect(actor.containsKey('session_id'), isTrue);
        }
        final meta = await db.query('entity_sync_meta');
        expect(meta.length, greaterThanOrEqualTo(3));
        expect(
          meta.map((r) => r['updated_by']).toSet(),
          {'owner-batch-del-1'},
        );
      },
    );
  });
}

// ---------- helpers (kept self-contained; mirror jztshare fixtures) -------

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
    'producer': {
      'app_name': 'FleetLedger',
      'app_version': '1.0.1',
      'platform': 'ios',
    },
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
  int sourceUnitPriceFen = 38000,
}) {
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
    'source_unit_price_fen': sourceUnitPriceFen,
    'amount_fen': ExternalWorkRecord.calculateAmountFen(
      hoursMilli: hoursMilli,
      unitPriceFen: sourceUnitPriceFen,
    ),
    'note': '现场记录',
  };
}

ExternalWorkRecord _record({
  String id = 'external-record-1',
  String importBatchId = 'batch-1',
  String sourceShareId = 'share-1',
  String sourceRecordUuid = 'source-record-1',
}) {
  return ExternalWorkRecord.create(
    id: id,
    importBatchId: importBatchId,
    sourceShareId: sourceShareId,
    sourceRecordUuid: sourceRecordUuid,
    sourceInstallationUuid: 'install-1',
    originFingerprint: 'fingerprint-$sourceRecordUuid',
    collaboratorName: '王师傅',
    contactSnapshot: '甲方',
    siteSnapshot: '一号工地',
    equipmentBrand: '三一',
    equipmentModel: '75',
    equipmentType: 'excavator',
    workDate: 20260518,
    hoursMilli: 1500,
    sourceUnitPriceFen: 30000,
    projectReceivedFen: 0,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

Project _project({
  String id = 'project:linked',
  ProjectStatus status = ProjectStatus.active,
  String? settledAt,
  String? settledSnapshot,
}) {
  return Project(
    id: id,
    contact: '甲方',
    site: '一号工地',
    status: status,
    settledAt: settledAt,
    settledSnapshot: settledSnapshot,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

ProjectWriteOff _writeOff(
  String projectId, {
  String? id,
  double amount = 100,
  String? note,
  String writeOffDate = '2026-05-19',
}) {
  return ProjectWriteOff(
    id: id ?? 'writeoff-$projectId',
    projectId: projectId,
    amount: amount,
    reason: ProjectWriteOffReason.settlement.dbValue,
    note: note,
    writeOffDate: writeOffDate,
    createdAt: '2026-05-19T00:00:00.000Z',
    updatedAt: '2026-05-19T00:00:00.000Z',
  );
}

ExternalImportBatch _batch({String id = 'batch-1'}) {
  return ExternalImportBatch(
    id: id,
    sourceShareId: 'share-1',
    sourceDisplayName: '王师傅',
    recordCount: 1,
    totalHoursMilli: 1500,
    totalAmountFen: 45000,
    siteSummary: '一号工地',
    importedAt: '2026-05-18T00:00:00.000Z',
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}
