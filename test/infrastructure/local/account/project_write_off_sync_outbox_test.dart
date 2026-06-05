import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/project_write_off_repository.dart';
import 'package:asset_ledger/infrastructure/local/account/project_write_off_sync_enqueuer.dart';
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
      final repository = SqfliteProjectWriteOffRepository();
      final enqueuer = ProjectWriteOffSyncEnqueuer();
      final writeOff = _writeOff();
      await _seedProject(db);

      await AppDatabase.inTransaction<void>((txn) async {
        await repository.insertWithExecutor(txn, writeOff);
        await enqueuer.enqueueCreate(txn, writeOff);
      });

      expect(
        await db.query(SqfliteProjectWriteOffRepository.table),
        hasLength(1),
      );

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      final outbox = outboxRows.single;
      expect(outbox['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
      expect(outbox['entity_id'], writeOff.id);
      expect(outbox['operation'], 'create');
      expect(outbox['status'], SyncOutboxStatus.pending.name);
      final payload =
          jsonDecode(outbox['payload_json'] as String) as Map<String, Object?>;
      expect(payload['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
      expect(payload['entity_id'], writeOff.id);
      expect(payload['operation'], 'create');
      expect(payload['record'], writeOff.toMap());
      final record = payload['record'] as Map<String, Object?>;
      expect(record['id'], writeOff.id);
      expect(record['project_id'], 'project:1');
      expect(record['amount'], 125.5);
      expect(record['amount_fen'], 12550);
      expect(record['reason'], ProjectWriteOffReason.settlement.dbValue);
      expect(record['write_off_date'], '2026-06-01');
      expect(record['created_at'], '2026-06-01T00:00:00.000Z');
      expect(record['updated_at'], '2026-06-01T00:00:00.000Z');

      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(1));
      final meta = metaRows.single;
      expect(meta['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
      expect(meta['local_id'], writeOff.id);
      expect(meta['sync_status'], SyncStatus.pendingUpload.name);
      expect(meta['source'], ProjectWriteOffSyncEnqueuer.ownerAppSource);
      expect(meta['version'], 0);
      expect(meta['payload_hash'], outbox['payload_hash']);
    },
  );

  test(
    'delete enqueue uses pre-delete snapshot and writes pendingDelete meta',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteProjectWriteOffRepository();
      final enqueuer = ProjectWriteOffSyncEnqueuer();
      final writeOff = _writeOff();
      await _seedProject(db);
      await repository.insert(writeOff);

      await AppDatabase.inTransaction<void>((txn) async {
        final snapshot = await repository.findByIdWithExecutor(
          txn,
          writeOff.id,
        );
        expect(snapshot, isNotNull);
        final deleted = await repository.deleteByIdWithExecutor(
          txn,
          writeOff.id,
        );
        expect(deleted, 1);
        await enqueuer.enqueueDelete(txn, snapshot!);
      });

      expect(await db.query(SqfliteProjectWriteOffRepository.table), isEmpty);

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      final outbox = outboxRows.single;
      expect(outbox['entity_type'], ProjectWriteOffSyncEnqueuer.entityType);
      expect(outbox['entity_id'], writeOff.id);
      expect(outbox['operation'], 'delete');
      final payload =
          jsonDecode(outbox['payload_json'] as String) as Map<String, Object?>;
      expect(payload['operation'], 'delete');
      expect(payload['record'], writeOff.toMap());

      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(1));
      expect(metaRows.single['sync_status'], SyncStatus.pendingDelete.name);
      expect(metaRows.single['payload_hash'], outbox['payload_hash']);
    },
  );

  test('id missing throws StateError and leaves no outbox or meta', () async {
    final db = await AppDatabase.database;
    final enqueuer = ProjectWriteOffSyncEnqueuer();
    final writeOff = _writeOff(id: ' ');

    await expectLater(
      AppDatabase.inTransaction<void>(
        (txn) => enqueuer.enqueueCreate(txn, writeOff),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ProjectWriteOff sync enqueue id missing'),
        ),
      ),
    );
    await expectLater(
      AppDatabase.inTransaction<void>(
        (txn) => enqueuer.enqueueDelete(txn, writeOff),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ProjectWriteOff sync enqueue id missing'),
        ),
      ),
    );

    expect(await db.query('sync_outbox'), isEmpty);
    expect(await db.query('entity_sync_meta'), isEmpty);
  });

  test(
    'outbox write failure rolls back write-off insert and leaves no meta',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteProjectWriteOffRepository();
      final enqueuer = ProjectWriteOffSyncEnqueuer(
        syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
      );
      final writeOff = _writeOff();
      await _seedProject(db);

      await expectLater(
        AppDatabase.inTransaction<void>((txn) async {
          await repository.insertWithExecutor(txn, writeOff);
          await enqueuer.enqueueCreate(txn, writeOff);
        }),
        throwsA(isA<StateError>()),
      );

      expect(await db.query(SqfliteProjectWriteOffRepository.table), isEmpty);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    },
  );

  test(
    'meta write failure rolls back write-off insert and outbox row',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteProjectWriteOffRepository();
      final enqueuer = ProjectWriteOffSyncEnqueuer(
        entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(),
      );
      final writeOff = _writeOff();
      await _seedProject(db);

      await expectLater(
        AppDatabase.inTransaction<void>((txn) async {
          await repository.insertWithExecutor(txn, writeOff);
          await enqueuer.enqueueCreate(txn, writeOff);
        }),
        throwsA(isA<StateError>()),
      );

      expect(await db.query(SqfliteProjectWriteOffRepository.table), isEmpty);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    },
  );

  test('same transaction multiple create outbox ids are unique', () async {
    final db = await AppDatabase.database;
    final repository = SqfliteProjectWriteOffRepository();
    final enqueuer = ProjectWriteOffSyncEnqueuer(
      syncOutboxRepository: LocalSyncOutboxRepository(
        idGenerator: SequenceOutboxIdGenerator(prefix: 'write-off-outbox-'),
      ),
    );
    final first = _writeOff(id: 'write-off-1');
    final second = _writeOff(
      id: 'write-off-2',
      amount: 80,
      writeOffDate: '2026-06-02',
      createdAt: '2026-06-02T00:00:00.000Z',
      updatedAt: '2026-06-02T00:00:00.000Z',
    );
    await _seedProject(db);

    await AppDatabase.inTransaction<void>((txn) async {
      for (final writeOff in [first, second]) {
        await repository.insertWithExecutor(txn, writeOff);
        await enqueuer.enqueueCreate(txn, writeOff);
      }
    });

    final outbox = await db.query('sync_outbox', orderBy: 'id ASC');
    expect(outbox, hasLength(2));
    expect(outbox.map((row) => row['id']).toSet(), hasLength(2));
    expect(outbox.map((row) => row['id']).toList(), [
      'write-off-outbox-1',
      'write-off-outbox-2',
    ]);
    expect(outbox.map((row) => row['entity_id']).toSet(), {
      first.id,
      second.id,
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
      final repository = SqfliteProjectWriteOffRepository();
      final first = _writeOff(id: 'write-off-1');
      final second = _writeOff(
        id: 'write-off-2',
        amount: 80,
        writeOffDate: '2026-06-02',
        createdAt: '2026-06-02T00:00:00.000Z',
        updatedAt: '2026-06-02T00:00:00.000Z',
      );
      await _seedProject(db);

      await AppDatabase.inTransaction<void>((txn) async {
        await repository.insertWithExecutor(txn, first);
        await repository.insertWithExecutor(txn, second);

        final found = await repository.findByIdWithExecutor(txn, first.id);
        expect(found?.toMap(), first.toMap());

        final projectRows = await repository.listByProjectIdWithExecutor(
          txn,
          'project:1',
        );
        expect(projectRows.map((row) => row.id), [second.id, first.id]);

        expect(await repository.deleteByIdWithExecutor(txn, first.id), 1);
        expect(await repository.findByIdWithExecutor(txn, first.id), isNull);
        expect(await repository.deleteByIdWithExecutor(txn, 'missing'), 0);

        expect(await txn.query('sync_outbox'), isEmpty);
        expect(await txn.query('entity_sync_meta'), isEmpty);
      });

      final remaining = await db.query(SqfliteProjectWriteOffRepository.table);
      expect(remaining, hasLength(1));
      expect(remaining.single['id'], second.id);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    },
  );
}

ProjectWriteOff _writeOff({
  String id = 'write-off-1',
  String projectId = 'project:1',
  double amount = 125.5,
  String? reason,
  String? note = 'settlement adjustment',
  String writeOffDate = '2026-06-01',
  String createdAt = '2026-06-01T00:00:00.000Z',
  String updatedAt = '2026-06-01T00:00:00.000Z',
}) {
  return ProjectWriteOff(
    id: id,
    projectId: projectId,
    amount: amount,
    reason: reason ?? ProjectWriteOffReason.settlement.dbValue,
    note: note,
    writeOffDate: writeOffDate,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

Future<void> _seedProject(
  DatabaseExecutor executor, {
  String id = 'project:1',
}) {
  return executor.insert(
    SqfliteProjectRepository.table,
    Project(
      id: id,
      contact: 'client',
      site: 'site',
      createdAt: '2026-06-01T00:00:00.000Z',
      updatedAt: '2026-06-01T00:00:00.000Z',
    ).toMap(),
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
