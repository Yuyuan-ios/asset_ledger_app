import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/repositories/external_import_repository.dart';
import 'package:asset_ledger/data/repositories/external_work_record_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/infrastructure/local/timing/external_work_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
import 'package:asset_ledger/infrastructure/sync/outbox_id_generator.dart';
import 'package:asset_ledger/infrastructure/sync/sync_outbox_entry.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
    await _openCurrentInMemoryDb();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test(
    'create enqueue writes row-level outbox and pendingUpload meta',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteExternalWorkRecordRepository();
      final enqueuer = ExternalWorkSyncEnqueuer();
      final record = _record();
      await _seedImportBatch(db);

      await AppDatabase.inTransaction<void>((txn) async {
        await SqfliteExternalWorkRecordRepository.insertRecordWithExecutor(
          txn,
          record,
        );
        await enqueuer.enqueueCreate(txn, record: record);
      });

      expect(
        await db.query(SqfliteExternalWorkRecordRepository.table),
        hasLength(1),
      );

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      final outbox = outboxRows.single;
      expect(outbox['entity_type'], ExternalWorkSyncEnqueuer.entityType);
      expect(outbox['entity_id'], record.id);
      expect(outbox['operation'], 'create');
      expect(outbox['status'], SyncOutboxStatus.pending.name);

      final payload =
          jsonDecode(outbox['payload_json'] as String) as Map<String, Object?>;
      expect(payload['entity_type'], ExternalWorkSyncEnqueuer.entityType);
      expect(payload['entity_id'], record.id);
      expect(payload['operation'], 'create');
      expect(payload['record'], record.toUncheckedMap());
      final payloadRecord = payload['record'] as Map<String, Object?>;
      expect(payloadRecord['id'], record.id);
      expect(payloadRecord['import_batch_id'], record.importBatchId);
      expect(payloadRecord['source_share_id'], record.sourceShareId);
      expect(payloadRecord['source_record_uuid'], record.sourceRecordUuid);
      expect(payloadRecord['origin_fingerprint'], record.originFingerprint);
      expect(payloadRecord['work_date'], record.workDate);
      expect(payloadRecord['hours_milli'], record.hoursMilli);
      expect(payloadRecord['amount_fen'], record.amountFen);
      expect(payloadRecord['project_received_fen'], record.projectReceivedFen);
      expect(payloadRecord['linked_project_id'], record.linkedProjectId);
      expect(payloadRecord['record_kind'], record.recordKind.name);
      expect(payloadRecord['status'], record.status.name);
      expect(payloadRecord['created_at'], record.createdAt);
      expect(payloadRecord['updated_at'], record.updatedAt);

      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(1));
      final meta = metaRows.single;
      expect(meta['entity_type'], ExternalWorkSyncEnqueuer.entityType);
      expect(meta['local_id'], record.id);
      expect(meta['sync_status'], SyncStatus.pendingUpload.name);
      expect(meta['source'], ExternalWorkSyncEnqueuer.ownerAppSource);
      expect(meta['version'], 0);
      expect(meta['payload_hash'], outbox['payload_hash']);

      expect(await repository.findByIdWithExecutor(db, record.id), isNotNull);
    },
  );

  test(
    'update enqueue writes pendingUpdate with final linked snapshot',
    () async {
      final db = await AppDatabase.database;
      final enqueuer = ExternalWorkSyncEnqueuer();
      final record = _record();
      final linked = record.copyWith(
        linkedProjectId: 'project:linked',
        updatedAt: '2026-05-18T01:00:00.000Z',
      );
      await _seedImportBatch(db);
      await _seedProject(db);

      await AppDatabase.inTransaction<void>((txn) async {
        await SqfliteExternalWorkRecordRepository.insertRecordWithExecutor(
          txn,
          record,
        );
        await SqfliteExternalWorkRecordRepository().updateWithExecutor(
          txn,
          linked,
        );
        await enqueuer.enqueueUpdate(txn, record: linked);
      });

      final outbox = (await db.query('sync_outbox')).single;
      expect(outbox['entity_type'], ExternalWorkSyncEnqueuer.entityType);
      expect(outbox['entity_id'], linked.id);
      expect(outbox['operation'], 'update');
      final payload =
          jsonDecode(outbox['payload_json'] as String) as Map<String, Object?>;
      expect(payload['operation'], 'update');
      expect(payload['record'], linked.toUncheckedMap());
      expect(
        (payload['record'] as Map<String, Object?>)['linked_project_id'],
        'project:linked',
      );

      final meta = (await db.query('entity_sync_meta')).single;
      expect(meta['sync_status'], SyncStatus.pendingUpdate.name);
      expect(meta['payload_hash'], outbox['payload_hash']);
    },
  );

  test(
    'delete enqueue uses pre-delete snapshot and writes pendingDelete meta',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteExternalWorkRecordRepository();
      final enqueuer = ExternalWorkSyncEnqueuer();
      final record = _record();
      await _seedImportBatch(db);
      await repository.insertRecord(record);

      await AppDatabase.inTransaction<void>((txn) async {
        final snapshot = await repository.findByIdWithExecutor(txn, record.id);
        expect(snapshot, isNotNull);
        expect(await repository.deleteByIdWithExecutor(txn, record.id), 1);
        await enqueuer.enqueueDelete(txn, record: snapshot!);
      });

      expect(
        await db.query(SqfliteExternalWorkRecordRepository.table),
        isEmpty,
      );

      final outbox = (await db.query('sync_outbox')).single;
      expect(outbox['entity_type'], ExternalWorkSyncEnqueuer.entityType);
      expect(outbox['entity_id'], record.id);
      expect(outbox['operation'], 'delete');
      final payload =
          jsonDecode(outbox['payload_json'] as String) as Map<String, Object?>;
      expect(payload['operation'], 'delete');
      expect(payload['record'], record.toUncheckedMap());

      final meta = (await db.query('entity_sync_meta')).single;
      expect(meta['sync_status'], SyncStatus.pendingDelete.name);
      expect(meta['payload_hash'], outbox['payload_hash']);
    },
  );

  test(
    'update enqueue preserves rich imported snapshot without local unit price',
    () async {
      final db = await AppDatabase.database;
      final enqueuer = ExternalWorkSyncEnqueuer();
      final imported = ExternalWorkRecord.imported(
        id: 'external-record-rich',
        importBatchId: 'batch-rich',
        sourceShareId: 'share-rich',
        sourceRecordUuid: 'source-rich',
        sourceInstallationUuid: 'install-1',
        originFingerprint: 'fingerprint-rich',
        collaboratorName: 'worker',
        contactSnapshot: 'client',
        siteSnapshot: 'site',
        equipmentBrand: 'brand',
        equipmentModel: 'model',
        equipmentType: 'excavator',
        workDate: 20260518,
        hoursMilli: 10000,
        amountFen: 180000,
        sourceUnitPriceFen: 18000,
        localUnitPriceFen: null,
        customerUnitPriceFen: 700000,
        createdAt: '2026-05-18T00:00:00.000Z',
        updatedAt: '2026-05-18T01:00:00.000Z',
      );
      final dbReadSnapshot = ExternalWorkRecord.fromMap(imported.toMap());
      expect(dbReadSnapshot.amountOverridesPolicy, isFalse);
      expect(dbReadSnapshot.localUnitPriceFen, isNull);

      await AppDatabase.inTransaction<void>((txn) async {
        await enqueuer.enqueueUpdate(txn, record: dbReadSnapshot);
      });

      final outbox = (await db.query('sync_outbox')).single;
      final payload =
          jsonDecode(outbox['payload_json'] as String) as Map<String, Object?>;
      expect(payload['operation'], 'update');
      expect(payload['record'], dbReadSnapshot.toUncheckedMap());
      final payloadRecord = payload['record'] as Map<String, Object?>;
      expect(payloadRecord['local_unit_price_fen'], isNull);
      expect(payloadRecord['customer_unit_price_fen'], 700000);
      expect(payloadRecord['amount_fen'], 180000);

      final meta = (await db.query('entity_sync_meta')).single;
      expect(meta['sync_status'], SyncStatus.pendingUpdate.name);
      expect(meta['payload_hash'], outbox['payload_hash']);
    },
  );

  test('id missing throws StateError and leaves no outbox or meta', () async {
    final db = await AppDatabase.database;
    final enqueuer = ExternalWorkSyncEnqueuer();
    final record = _uncheckedRecord(id: ' ');

    Future<void> expectMissingId(
      Future<void> Function(DatabaseExecutor txn) action,
    ) async {
      await expectLater(
        AppDatabase.inTransaction<void>(action),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('ExternalWorkRecord sync enqueue id missing'),
          ),
        ),
      );
    }

    await expectMissingId((txn) => enqueuer.enqueueCreate(txn, record: record));
    await expectMissingId((txn) => enqueuer.enqueueUpdate(txn, record: record));
    await expectMissingId((txn) => enqueuer.enqueueDelete(txn, record: record));

    expect(await db.query('sync_outbox'), isEmpty);
    expect(await db.query('entity_sync_meta'), isEmpty);
  });

  test(
    'outbox write failure rolls back external work insert and leaves no meta',
    () async {
      final db = await AppDatabase.database;
      final record = _record();
      final enqueuer = ExternalWorkSyncEnqueuer(
        syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
      );
      await _seedImportBatch(db);

      await expectLater(
        AppDatabase.inTransaction<void>((txn) async {
          await SqfliteExternalWorkRecordRepository.insertRecordWithExecutor(
            txn,
            record,
          );
          await enqueuer.enqueueCreate(txn, record: record);
        }),
        throwsA(isA<StateError>()),
      );

      expect(
        await db.query(SqfliteExternalWorkRecordRepository.table),
        isEmpty,
      );
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    },
  );

  test(
    'meta write failure rolls back external work insert and outbox row',
    () async {
      final db = await AppDatabase.database;
      final record = _record();
      final enqueuer = ExternalWorkSyncEnqueuer(
        entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(),
      );
      await _seedImportBatch(db);

      await expectLater(
        AppDatabase.inTransaction<void>((txn) async {
          await SqfliteExternalWorkRecordRepository.insertRecordWithExecutor(
            txn,
            record,
          );
          await enqueuer.enqueueCreate(txn, record: record);
        }),
        throwsA(isA<StateError>()),
      );

      expect(
        await db.query(SqfliteExternalWorkRecordRepository.table),
        isEmpty,
      );
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    },
  );

  test('same transaction multiple create outbox ids are unique', () async {
    final db = await AppDatabase.database;
    final enqueuer = ExternalWorkSyncEnqueuer(
      syncOutboxRepository: LocalSyncOutboxRepository(
        idGenerator: SequenceOutboxIdGenerator(prefix: 'external-outbox-'),
      ),
    );
    final records = [
      _record(id: 'external-record-1', sourceRecordUuid: 'source-1'),
      _record(id: 'external-record-2', sourceRecordUuid: 'source-2'),
    ];
    await _seedImportBatch(db);

    await AppDatabase.inTransaction<void>((txn) async {
      for (final record in records) {
        await SqfliteExternalWorkRecordRepository.insertRecordWithExecutor(
          txn,
          record,
        );
        await enqueuer.enqueueCreate(txn, record: record);
      }
    });

    final outbox = await db.query('sync_outbox', orderBy: 'id ASC');
    expect(outbox, hasLength(2));
    expect(outbox.map((row) => row['id']).toSet(), hasLength(2));
    expect(outbox.map((row) => row['id']).toList(), [
      'external-outbox-1',
      'external-outbox-2',
    ]);
    expect(outbox.map((row) => row['entity_id']).toSet(), {
      'external-record-1',
      'external-record-2',
    });

    final meta = await db.query('entity_sync_meta');
    expect(meta, hasLength(2));
    expect(
      meta.every((row) => row['sync_status'] == SyncStatus.pendingUpload.name),
      isTrue,
    );
  });

  test(
    'repository executor API reads snapshots and writes no sync rows',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteExternalWorkRecordRepository();
      final first = _record(
        id: 'external-record-1',
        sourceRecordUuid: 'source-1',
      );
      final second = _record(
        id: 'external-record-2',
        sourceRecordUuid: 'source-2',
      );
      final third = _record(
        id: 'external-record-3',
        importBatchId: 'batch-2',
        sourceShareId: 'share-2',
        sourceRecordUuid: 'source-3',
      );
      await _seedImportBatch(db);
      await _seedImportBatch(db, id: 'batch-2', sourceShareId: 'share-2');
      await _seedProject(db, id: 'project:linked');
      await _seedProject(db, id: 'project:other');

      await AppDatabase.inTransaction<void>((txn) async {
        final insertedIds = await repository.insertRecordsWithExecutor(
          txn,
          records: [first, second, third],
        );
        expect(insertedIds, [first.id, second.id, third.id]);

        final found = await repository.findByIdWithExecutor(txn, first.id);
        expect(found?.toMap(), first.toMap());

        final batchRows = await repository.listByBatchIdWithExecutor(
          txn,
          'batch-1',
        );
        expect(batchRows.map((record) => record.id).toList(), [
          first.id,
          second.id,
        ]);

        final updated = first.copyWith(
          linkedProjectId: 'project:linked',
          status: ExternalWorkRecordStatus.ignored,
          updatedAt: '2026-05-18T01:00:00.000Z',
        );
        expect(await repository.updateWithExecutor(txn, updated), 1);
        expect(
          (await repository.findByIdWithExecutor(txn, first.id))?.toMap(),
          updated.toMap(),
        );

        final linkedRows = await repository.listByLinkedProjectIdWithExecutor(
          txn,
          'project:linked',
        );
        expect(linkedRows.map((record) => record.id).toList(), [first.id]);

        expect(
          await repository.linkBatchToProjectWithExecutor(
            txn,
            importBatchId: 'batch-2',
            projectId: 'project:other',
            updatedAt: '2026-05-18T02:00:00.000Z',
          ),
          1,
        );
        final relinked = await repository.listByBatchIdWithExecutor(
          txn,
          'batch-2',
        );
        expect(relinked.single.linkedProjectId, 'project:other');

        expect(
          await repository.unlinkBatchWithExecutor(
            txn,
            importBatchId: 'batch-2',
            updatedAt: '2026-05-18T03:00:00.000Z',
          ),
          1,
        );
        expect(
          (await repository.listByBatchIdWithExecutor(
            txn,
            'batch-2',
          )).single.linkedProjectId,
          isNull,
        );

        expect(await repository.deleteByIdWithExecutor(txn, second.id), 1);
        expect(await repository.findByIdWithExecutor(txn, second.id), isNull);
        expect(await repository.deleteByIdWithExecutor(txn, 'missing'), 0);
        expect(await repository.deleteByBatchIdWithExecutor(txn, 'batch-2'), 1);
        expect(await repository.deleteByBatchIdWithExecutor(txn, 'missing'), 0);

        expect(await txn.query('sync_outbox'), isEmpty);
        expect(await txn.query('entity_sync_meta'), isEmpty);
      });

      final remaining = await db.query(
        SqfliteExternalWorkRecordRepository.table,
      );
      expect(remaining.map((row) => row['id']).toList(), [first.id]);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    },
  );
}

ExternalImportBatch _batch({
  String id = 'batch-1',
  String sourceShareId = 'share-1',
}) {
  return ExternalImportBatch(
    id: id,
    sourceShareId: sourceShareId,
    sourceDisplayName: 'worker',
    recordCount: 1,
    totalHoursMilli: 1500,
    totalAmountFen: 45000,
    siteSummary: 'site',
    importedAt: '2026-05-18T00:00:00.000Z',
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

Future<void> _seedImportBatch(
  DatabaseExecutor executor, {
  String id = 'batch-1',
  String sourceShareId = 'share-1',
}) {
  return SqfliteExternalImportRepository.insertBatchWithExecutor(
    executor,
    _batch(id: id, sourceShareId: sourceShareId),
  );
}

Future<void> _seedProject(
  DatabaseExecutor executor, {
  String id = 'project:linked',
}) {
  return executor.insert(
    SqfliteProjectRepository.table,
    Project(
      id: id,
      contact: 'client',
      site: 'site',
      createdAt: '2026-05-18T00:00:00.000Z',
      updatedAt: '2026-05-18T00:00:00.000Z',
    ).toMap(),
  );
}

ExternalWorkRecord _record({
  String id = 'external-record-1',
  String importBatchId = 'batch-1',
  String sourceShareId = 'share-1',
  String sourceRecordUuid = 'source-record-1',
  int projectReceivedFen = 12000,
  String? linkedProjectId,
}) {
  return ExternalWorkRecord.create(
    id: id,
    importBatchId: importBatchId,
    sourceShareId: sourceShareId,
    sourceRecordUuid: sourceRecordUuid,
    sourceInstallationUuid: 'install-1',
    originFingerprint: 'fingerprint-$sourceRecordUuid',
    collaboratorName: 'worker',
    contactSnapshot: 'client',
    siteSnapshot: 'site',
    equipmentBrand: 'brand',
    equipmentModel: 'model',
    equipmentType: 'excavator',
    workDate: 20260518,
    hoursMilli: 1500,
    sourceUnitPriceFen: 30000,
    projectReceivedFen: projectReceivedFen,
    linkedProjectId: linkedProjectId,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

ExternalWorkRecord _uncheckedRecord({required String id}) {
  return ExternalWorkRecord(
    id: id,
    importBatchId: 'batch-1',
    sourceShareId: 'share-1',
    sourceRecordUuid: 'source-record-1',
    sourceInstallationUuid: 'install-1',
    originFingerprint: 'fingerprint-source-record-1',
    collaboratorName: 'worker',
    contactSnapshot: 'client',
    siteSnapshot: 'site',
    workDate: 20260518,
    hoursMilli: 1500,
    sourceUnitPriceFen: 30000,
    localUnitPriceFen: 30000,
    amountFen: 45000,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
  );
}

class _ThrowingSyncOutboxRepository implements SyncOutboxRepository {
  const _ThrowingSyncOutboxRepository();

  @override
  Future<SyncOutboxEntry> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    String? transactionGroupId,
    int? localSequence,
  }) {
    throw StateError('injected failure: sync_outbox write failed');
  }

  @override
  Future<SyncOutboxEntry> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    String? transactionGroupId,
    int? localSequence,
  }) {
    throw StateError('injected failure: sync_outbox write failed');
  }

  @override
  Future<List<SyncOutboxEntry>> listPending({int limit = 50}) async {
    return const [];
  }
}

class _ThrowingEntitySyncMetaRepository implements EntitySyncMetaRepository {
  const _ThrowingEntitySyncMetaRepository();

  @override
  Future<void> upsert(EntitySyncMeta meta) {
    throw StateError('injected failure: entity_sync_meta write failed');
  }

  @override
  Future<void> upsertWithExecutor(
    DatabaseExecutor executor,
    EntitySyncMeta meta,
  ) {
    throw StateError('injected failure: entity_sync_meta write failed');
  }

  @override
  Future<EntitySyncMeta?> find({
    required String entityType,
    required String localId,
  }) async {
    return null;
  }
}

Future<Database> _openCurrentInMemoryDb() {
  AppDatabase.debugInitDbOverride = () {
    return openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase.schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) => DbSchema.create(db),
    );
  };
  return AppDatabase.database;
}
