import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  setUp(() async {
    await AppDatabase.resetForTest();
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
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test('creates sync tables and stores outbox entries', () async {
    final db = await AppDatabase.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).toSet();

    expect(
      names,
      containsAll([
        'sync_outbox',
        'sync_state',
        'entity_sync_meta',
        'sync_conflicts',
        'work_records',
      ]),
    );

    final outbox = LocalSyncOutboxRepository(
      now: () => DateTime.utc(2026, 5, 18),
    );
    final entry = await outbox.enqueue(
      entityType: 'work_record',
      entityId: 'local-1',
      operation: 'upsert',
      payload: const {'local_id': 'local-1', 'amount_fen': 120000},
    );

    expect(entry.payloadHash, hasLength(64));
    expect((await outbox.listPending()).single.entityId, 'local-1');
  });

  test('upserts entity sync metadata', () async {
    const repository = LocalEntitySyncMetaRepository();
    await repository.upsert(
      const EntitySyncMeta(
        entityType: 'work_record',
        localId: 'local-1',
        serverId: 'server-1',
        syncStatus: SyncStatus.pendingUpload,
        version: 1,
        source: 'mini_program',
        payloadHash: 'hash',
      ),
    );

    final saved = await repository.find(
      entityType: 'work_record',
      localId: 'local-1',
    );

    expect(saved?.serverId, 'server-1');
    expect(saved?.syncStatus, SyncStatus.pendingUpload);
  });

  test(
    'executor-aware sync writes roll back with the surrounding transaction',
    () async {
      final db = await AppDatabase.database;
      final outbox = LocalSyncOutboxRepository(
        now: () => DateTime.utc(2026, 5, 18, 12),
      );
      const metaRepository = LocalEntitySyncMetaRepository();

      await expectLater(
        AppDatabase.inTransaction((txn) async {
          final entry = await outbox.enqueueWithExecutor(
            txn,
            entityType: 'timing_record',
            entityId: '1',
            operation: 'create',
            payload: const {'id': 1},
          );
          await metaRepository.upsertWithExecutor(
            txn,
            EntitySyncMeta(
              entityType: 'timing_record',
              localId: '1',
              syncStatus: SyncStatus.pendingUpload,
              version: 0,
              source: 'owner_app',
              payloadHash: entry.payloadHash,
            ),
          );
          throw StateError('rollback-sync-writes');
        }),
        throwsA(isA<StateError>()),
      );

      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    },
  );
}
