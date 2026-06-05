import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/infrastructure/local/account/project_sync_enqueuer.dart';
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
    'update enqueue writes row-level outbox and pendingUpdate meta',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteProjectRepository();
      final enqueuer = ProjectSyncEnqueuer();
      final project = _project();
      final updated = _settled(project);
      await repository.insert(project);

      await AppDatabase.inTransaction<void>((txn) async {
        final changed = await repository.updateWithExecutor(txn, updated);
        expect(changed, 1);
        await enqueuer.enqueueUpdate(txn, project: updated);
      });

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      final outbox = outboxRows.single;
      expect(outbox['entity_type'], ProjectSyncEnqueuer.entityType);
      expect(outbox['entity_id'], updated.id);
      expect(outbox['operation'], 'update');
      expect(outbox['status'], SyncOutboxStatus.pending.name);
      final payload =
          jsonDecode(outbox['payload_json'] as String) as Map<String, Object?>;
      expect(payload['entity_type'], ProjectSyncEnqueuer.entityType);
      expect(payload['entity_id'], updated.id);
      expect(payload['operation'], 'update');
      expect(payload['record'], updated.toMap());
      final record = payload['record'] as Map<String, Object?>;
      expect(record['id'], updated.id);
      expect(record['contact'], 'client');
      expect(record['site'], 'site');
      expect(record['status'], ProjectStatus.settled.name);
      expect(record['settled_at'], '2026-06-02T00:00:00.000Z');
      expect(record['settled_snapshot'], '{"remaining":0}');
      expect(record['created_at'], '2026-06-01T00:00:00.000Z');
      expect(record['updated_at'], '2026-06-02T00:00:00.000Z');
      expect(record['legacy_project_key'], 'client||site');

      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(1));
      final meta = metaRows.single;
      expect(meta['entity_type'], ProjectSyncEnqueuer.entityType);
      expect(meta['local_id'], updated.id);
      expect(meta['sync_status'], SyncStatus.pendingUpdate.name);
      expect(meta['source'], ProjectSyncEnqueuer.ownerAppSource);
      expect(meta['version'], 0);
      expect(meta['payload_hash'], outbox['payload_hash']);
    },
  );

  test(
    'repository executor API enqueues the final transaction snapshot',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteProjectRepository();
      final enqueuer = ProjectSyncEnqueuer();
      final project = _project();
      await repository.insert(project);

      await AppDatabase.inTransaction<void>((txn) async {
        final before = await repository.findByIdWithExecutor(txn, project.id);
        expect(before?.status, ProjectStatus.active);

        final updated = _settled(project);
        expect(await repository.updateWithExecutor(txn, updated), 1);

        final finalSnapshot = await repository.findByIdWithExecutor(
          txn,
          project.id,
        );
        expect(finalSnapshot?.toMap(), updated.toMap());
        await enqueuer.enqueueUpdate(txn, project: finalSnapshot!);
      });

      final outboxRows = await db.query('sync_outbox');
      expect(outboxRows, hasLength(1));
      final payload =
          jsonDecode(outboxRows.single['payload_json'] as String)
              as Map<String, Object?>;
      final record = payload['record'] as Map<String, Object?>;
      expect(record['status'], ProjectStatus.settled.name);
      expect(record['settled_at'], '2026-06-02T00:00:00.000Z');
      expect(record['settled_snapshot'], '{"remaining":0}');
    },
  );

  test('id missing throws StateError and leaves no outbox or meta', () async {
    final db = await AppDatabase.database;
    final enqueuer = ProjectSyncEnqueuer();
    final project = _project(id: ' ');

    await expectLater(
      AppDatabase.inTransaction<void>(
        (txn) => enqueuer.enqueueUpdate(txn, project: project),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Project sync enqueue id missing'),
        ),
      ),
    );

    expect(await db.query('sync_outbox'), isEmpty);
    expect(await db.query('entity_sync_meta'), isEmpty);
  });

  test(
    'outbox write failure rolls back project status update and leaves no meta',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteProjectRepository();
      final enqueuer = ProjectSyncEnqueuer(
        syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
      );
      final project = _project();
      final updated = _settled(project);
      await repository.insert(project);

      await expectLater(
        AppDatabase.inTransaction<void>((txn) async {
          expect(await repository.updateWithExecutor(txn, updated), 1);
          final snapshot = await repository.findByIdWithExecutor(
            txn,
            project.id,
          );
          await enqueuer.enqueueUpdate(txn, project: snapshot!);
        }),
        throwsA(isA<StateError>()),
      );

      final after = await repository.findById(project.id);
      expect(after?.status, ProjectStatus.active);
      expect(after?.settledAt, isNull);
      expect(after?.settledSnapshot, isNull);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    },
  );

  test(
    'meta write failure rolls back project status update and outbox row',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteProjectRepository();
      final enqueuer = ProjectSyncEnqueuer(
        entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(),
      );
      final project = _project();
      final updated = _settled(project);
      await repository.insert(project);

      await expectLater(
        AppDatabase.inTransaction<void>((txn) async {
          expect(await repository.updateWithExecutor(txn, updated), 1);
          final snapshot = await repository.findByIdWithExecutor(
            txn,
            project.id,
          );
          await enqueuer.enqueueUpdate(txn, project: snapshot!);
        }),
        throwsA(isA<StateError>()),
      );

      final after = await repository.findById(project.id);
      expect(after?.status, ProjectStatus.active);
      expect(after?.settledAt, isNull);
      expect(after?.settledSnapshot, isNull);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    },
  );

  test(
    'same transaction multiple project update outbox ids are unique',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteProjectRepository();
      final enqueuer = ProjectSyncEnqueuer(
        syncOutboxRepository: LocalSyncOutboxRepository(
          idGenerator: SequenceOutboxIdGenerator(prefix: 'project-outbox-'),
        ),
      );
      final first = _project(
        id: 'project:1',
        contact: 'client-a',
        site: 'site-a',
      );
      final second = _project(
        id: 'project:2',
        contact: 'client-b',
        site: 'site-b',
      );
      await repository.insert(first);
      await repository.insert(second);

      await AppDatabase.inTransaction<void>((txn) async {
        for (final project in [first, second]) {
          final updated = _settled(project);
          expect(await repository.updateWithExecutor(txn, updated), 1);
          final snapshot = await repository.findByIdWithExecutor(
            txn,
            project.id,
          );
          await enqueuer.enqueueUpdate(txn, project: snapshot!);
        }
      });

      final outbox = await db.query('sync_outbox', orderBy: 'id ASC');
      expect(outbox, hasLength(2));
      expect(outbox.map((row) => row['id']).toSet(), hasLength(2));
      expect(outbox.map((row) => row['id']).toList(), [
        'project-outbox-1',
        'project-outbox-2',
      ]);
      expect(outbox.map((row) => row['entity_id']).toSet(), {
        first.id,
        second.id,
      });

      final meta = await db.query('entity_sync_meta');
      expect(meta, hasLength(2));
      expect(
        meta.every(
          (row) => row['sync_status'] == SyncStatus.pendingUpdate.name,
        ),
        isTrue,
      );
    },
  );

  test(
    'repository executor API updates snapshots and writes no sync rows',
    () async {
      final db = await AppDatabase.database;
      final repository = SqfliteProjectRepository();
      final project = _project();
      final missing = _project(id: 'project:missing');
      await repository.insert(project);

      await AppDatabase.inTransaction<void>((txn) async {
        final found = await repository.findByIdWithExecutor(txn, project.id);
        expect(found?.toMap(), project.toMap());

        final updated = _settled(project);
        expect(await repository.updateWithExecutor(txn, updated), 1);
        expect(await repository.updateWithExecutor(txn, missing), 0);
        expect(
          await repository.findByIdWithExecutor(txn, 'project:missing'),
          isNull,
        );

        final finalSnapshot = await repository.findByIdWithExecutor(
          txn,
          project.id,
        );
        expect(finalSnapshot?.toMap(), updated.toMap());

        expect(await txn.query('sync_outbox'), isEmpty);
        expect(await txn.query('entity_sync_meta'), isEmpty);
      });

      final after = await repository.findById(project.id);
      expect(after?.status, ProjectStatus.settled);
      expect(after?.settledAt, '2026-06-02T00:00:00.000Z');
      expect(after?.settledSnapshot, '{"remaining":0}');
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    },
  );
}

Project _project({
  String id = 'project:1',
  String contact = 'client',
  String site = 'site',
  ProjectStatus status = ProjectStatus.active,
  String? settledAt,
  String? settledSnapshot,
  String createdAt = '2026-06-01T00:00:00.000Z',
  String updatedAt = '2026-06-01T00:00:00.000Z',
  String? legacyProjectKey,
}) {
  return Project(
    id: id,
    contact: contact,
    site: site,
    status: status,
    settledAt: settledAt,
    settledSnapshot: settledSnapshot,
    createdAt: createdAt,
    updatedAt: updatedAt,
    legacyProjectKey: legacyProjectKey ?? '$contact||$site',
  );
}

Project _settled(Project project) {
  return project.copyWith(
    status: ProjectStatus.settled,
    settledAt: '2026-06-02T00:00:00.000Z',
    settledSnapshot: '{"remaining":0}',
    updatedAt: '2026-06-02T00:00:00.000Z',
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
