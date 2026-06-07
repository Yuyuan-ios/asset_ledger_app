import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/account_project_merge_repository.dart';
import 'package:asset_ledger/data/repositories/device_repository.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/data/repositories/project_repository.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';
import 'package:asset_ledger/data/repositories/timing_repository.dart';
import 'package:asset_ledger/data/services/project_resolver.dart';
import 'package:asset_ledger/infrastructure/local/account/project_settlement_impact_service.dart';
import 'package:asset_ledger/infrastructure/local/account/project_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/local/timing/local_save_timing_record_with_impact_use_case.dart';
import 'package:asset_ledger/infrastructure/sync/sync_outbox_entry.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.26-A: Project full lifecycle outbox coverage.
///
/// CREATE is driven through the real production path — a brand-new project is
/// resolved-or-created inside the timing-save transaction. DELETE is exercised
/// at the enqueuer level because there is no production project delete path
/// today (see [ProjectSyncEnqueuer] doc + the coverage invariant).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late LocalSaveTimingRecordWithImpactUseCase useCase;

  ActorContext owner({String id = 'owner-prj-1', String? sessionId}) =>
      ActorContext(
        actorType: OperationActorType.owner,
        actorId: id,
        sessionId: sessionId,
      );

  LocalSaveTimingRecordWithImpactUseCase buildUseCase({
    ActorContext Function()? actorProvider,
  }) {
    final projectRepository = SqfliteProjectRepository();
    return LocalSaveTimingRecordWithImpactUseCase(
      timingRepository: SqfliteTimingRepository(),
      timingCalculationHistoryRepository:
          SqfliteTimingCalculationHistoryRepository(),
      mergeRepository: SqfliteAccountProjectMergeRepository(),
      deviceRepository: SqfliteDeviceRepository(),
      projectRateRepository: SqfliteProjectRateRepository(),
      projectRepository: projectRepository,
      projectResolver: ProjectResolver(projectRepository: projectRepository),
      impactService:
          ProjectSettlementImpactService(projectRepository: projectRepository),
      actorProvider: actorProvider,
      now: () => DateTime.utc(2026, 5, 26, 12),
    );
  }

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
    useCase = buildUseCase(actorProvider: owner);
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  TimingRecord newProjectTiming({
    String contact = '新甲方',
    String site = '新工地',
  }) =>
      TimingRecord(
        deviceId: 0, // set by caller after seeding device
        startDate: 20260520,
        projectId: '',
        contact: contact,
        site: site,
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 1,
        hours: 1,
        income: 100,
      );

  group('create (production timing-save path)', () {
    test(
      'creating a new project while saving timing enqueues a project create '
      'outbox as the FK prerequisite (seq1), then the timing row (seq2), '
      'sharing one transaction group; meta is pendingUpload; actor + '
      'updated_by mirror; record is a clean snapshot',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);

        final result = await useCase.execute(
          editing: null,
          record: newProjectTiming().copyWith(deviceId: deviceId),
        );
        final projectId = result.savedRecord.effectiveProjectId;
        expect(projectId, isNotEmpty);

        final rows = await db.query(
          'sync_outbox',
          orderBy: 'local_sequence ASC',
        );
        expect(rows, hasLength(2));

        // Shared, dense group: project create (1) → timing create (2).
        final groupIds = rows.map((r) => r['transaction_group_id']).toSet();
        expect(groupIds, hasLength(1));
        expect(groupIds.single as String?, startsWith('txn-'));
        expect(rows.map((r) => r['local_sequence']).toList(), <int>[1, 2]);

        expect(rows[0]['entity_type'], ProjectSyncEnqueuer.entityType);
        expect(rows[0]['operation'], 'create');
        expect(rows[1]['entity_type'], 'timing_record');
        expect(rows[1]['operation'], 'create');

        // Project create payload: schema v1 + actor + clean record.
        final payload = (jsonDecode(rows[0]['payload_json'] as String) as Map)
            .cast<String, Object?>();
        expect(payload['payload_schema_version'], 1);
        expect(payload['entity_type'], 'project');
        expect(payload['entity_id'], projectId);
        expect(payload['operation'], 'create');
        final actor = payload['actor'] as Map<String, Object?>;
        expect(actor['type'], 'owner');
        expect(actor['id'], 'owner-prj-1');
        expect(actor.containsKey('session_id'), isTrue);
        expect(actor['session_id'], isNull);
        final record = payload['record'] as Map<String, Object?>;
        expect(record.containsKey('actor'), isFalse);
        expect(record.containsKey('payload_schema_version'), isFalse);
        expect(record['id'], projectId);
        expect(record['contact'], '新甲方');
        expect(record['status'], ProjectStatus.active.name);

        // entity_sync_meta: project pendingUpload, updated_by == actor.id.
        final meta = await db.query(
          'entity_sync_meta',
          where: 'entity_type = ? AND local_id = ?',
          whereArgs: ['project', projectId],
        );
        expect(meta, hasLength(1));
        expect(meta.single['sync_status'], 'pendingUpload');
        expect(meta.single['updated_by'], 'owner-prj-1');
      },
    );

    test(
      'reusing an existing active project (no create) keeps the legacy '
      'single ungrouped timing outbox — no project create row',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);
        await _seedProject(db, projectId: 'project:existing',
            contact: '老甲方', site: '老工地');

        await useCase.execute(
          editing: null,
          record: newProjectTiming(contact: '老甲方', site: '老工地')
              .copyWith(deviceId: deviceId),
        );

        final rows = await db.query('sync_outbox');
        expect(rows, hasLength(1));
        expect(rows.single['entity_type'], 'timing_record');
        expect(rows.single['transaction_group_id'], isNull);
        expect(rows.single['local_sequence'], isNull);

        // No project outbox / meta produced when the project already exists.
        final projectOutbox = await db.query(
          'sync_outbox',
          where: 'entity_type = ?',
          whereArgs: ['project'],
        );
        expect(projectOutbox, isEmpty);
      },
    );

    test(
      'sessionId on the threaded actor propagates into the project create '
      'payload',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);
        useCase = buildUseCase(
          actorProvider: () => owner(sessionId: 'sess-create'),
        );

        await useCase.execute(
          editing: null,
          record: newProjectTiming().copyWith(deviceId: deviceId),
        );

        final projectRow = (await db.query(
          'sync_outbox',
          where: 'entity_type = ?',
          whereArgs: ['project'],
        )).single;
        final actor = ((jsonDecode(projectRow['payload_json'] as String)
                as Map)['actor'] as Map)
            .cast<String, Object?>();
        expect(actor['id'], 'owner-prj-1');
        expect(actor['session_id'], 'sess-create');
      },
    );

    test(
      'no actor provider → documented owner-app fallback (owner, null id) on '
      'the project create payload + meta',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);
        useCase = buildUseCase(); // no actorProvider

        final result = await useCase.execute(
          editing: null,
          record: newProjectTiming().copyWith(deviceId: deviceId),
        );
        final projectId = result.savedRecord.effectiveProjectId;

        final projectRow = (await db.query(
          'sync_outbox',
          where: 'entity_type = ?',
          whereArgs: ['project'],
        )).single;
        final actor = ((jsonDecode(projectRow['payload_json'] as String)
                as Map)['actor'] as Map)
            .cast<String, Object?>();
        expect(actor['type'], 'owner');
        expect(actor['id'], isNull,
            reason: 'no provider → documented owner-app fallback null id');
        expect(actor.containsKey('session_id'), isTrue);

        final meta = await db.query(
          'entity_sync_meta',
          where: 'entity_type = ? AND local_id = ?',
          whereArgs: ['project', projectId],
        );
        expect(meta.single['updated_by'], isNull);
      },
    );
  });

  group('create rollback (no half-write)', () {
    test(
      'when the outbox write fails, the new project + timing + all outbox/meta '
      'roll back together (no business success with a half-written sync)',
      () async {
        final db = await AppDatabase.database;
        final deviceId = await _seedDevice(db);

        final projectRepository = SqfliteProjectRepository();
        final failing = LocalSaveTimingRecordWithImpactUseCase(
          timingRepository: SqfliteTimingRepository(),
          timingCalculationHistoryRepository:
              SqfliteTimingCalculationHistoryRepository(),
          mergeRepository: SqfliteAccountProjectMergeRepository(),
          deviceRepository: SqfliteDeviceRepository(),
          projectRateRepository: SqfliteProjectRateRepository(),
          projectRepository: projectRepository,
          projectResolver: ProjectResolver(
            projectRepository: projectRepository,
          ),
          impactService: ProjectSettlementImpactService(
            projectRepository: projectRepository,
          ),
          projectSyncEnqueuer: const ProjectSyncEnqueuer(
            syncOutboxRepository: _ThrowingSyncOutboxRepository(),
          ),
          actorProvider: owner,
          now: () => DateTime.utc(2026, 5, 26, 12),
        );

        await expectLater(
          failing.execute(
            editing: null,
            record: newProjectTiming().copyWith(deviceId: deviceId),
          ),
          throwsA(isA<StateError>()),
        );

        // Project create is enqueued FIRST, so the throwing outbox aborts the
        // whole transaction: nothing persists.
        expect(await db.query('projects'), isEmpty);
        expect(await db.query('timing_records'), isEmpty);
        expect(await db.query('sync_outbox'), isEmpty);
        expect(await db.query('entity_sync_meta'), isEmpty);
      },
    );
  });

  group('delete (enqueuer-level; no production caller today)', () {
    test(
      'enqueueDelete writes a project delete outbox + pendingDelete meta with '
      'the injected actor; ungrouped single row by default; record clean',
      () async {
        final db = await AppDatabase.database;
        final project = _project(id: 'project:gone');

        await AppDatabase.inTransaction((txn) async {
          await const ProjectSyncEnqueuer().enqueueDelete(
            txn,
            project: project,
            actor: owner(id: 'owner-del-1', sessionId: 'sess-del'),
          );
        });

        final rows = await db.query('sync_outbox');
        expect(rows, hasLength(1));
        final row = rows.single;
        expect(row['entity_type'], 'project');
        expect(row['operation'], 'delete');
        expect(row['transaction_group_id'], isNull);
        expect(row['local_sequence'], isNull);

        final payload = (jsonDecode(row['payload_json'] as String) as Map)
            .cast<String, Object?>();
        expect(payload['payload_schema_version'], 1);
        final actor = payload['actor'] as Map<String, Object?>;
        expect(actor['id'], 'owner-del-1');
        expect(actor['session_id'], 'sess-del');
        final record = payload['record'] as Map<String, Object?>;
        expect(record.containsKey('actor'), isFalse);
        expect(record['id'], 'project:gone');

        final meta = await db.query(
          'entity_sync_meta',
          where: 'entity_type = ? AND local_id = ?',
          whereArgs: ['project', 'project:gone'],
        );
        expect(meta.single['sync_status'], 'pendingDelete');
        expect(meta.single['updated_by'], 'owner-del-1');
      },
    );

    test(
      'create then delete for the same project produces a foldable '
      'create→delete pending pair (R5.23 will collapse it pre-push)',
      () async {
        final db = await AppDatabase.database;
        final project = _project(id: 'project:ephemeral');

        await AppDatabase.inTransaction((txn) async {
          await const ProjectSyncEnqueuer()
              .enqueueCreate(txn, project: project, actor: owner());
        });
        await AppDatabase.inTransaction((txn) async {
          await const ProjectSyncEnqueuer()
              .enqueueDelete(txn, project: project, actor: owner());
        });

        final ops = (await db.query('sync_outbox', orderBy: 'created_at ASC'))
            .map((r) => r['operation'])
            .toList();
        // Same entity_type+entity_id, create before delete: this is exactly the
        // shape SyncManager._foldPending collapses. We assert the shape here;
        // the fold itself is covered by the R5.23 folding tests.
        expect(ops, <String>['create', 'delete']);
        final entityIds = (await db.query('sync_outbox'))
            .map((r) => '${r['entity_type']}::${r['entity_id']}')
            .toSet();
        expect(entityIds, {'project::project:ephemeral'});
      },
    );
  });
}

// ── helpers ────────────────────────────────────────────────────────────────

Future<int> _seedDevice(Database db) async {
  return db.insert(
    'devices',
    Device(
      name: 'Device',
      brand: 'brand',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
    ).toMap(),
  );
}

Future<void> _seedProject(
  Database db, {
  required String projectId,
  required String contact,
  required String site,
}) async {
  await db.insert(
    SqfliteProjectRepository.table,
    Project(
      id: projectId,
      contact: contact,
      site: site,
      status: ProjectStatus.active,
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
      legacyProjectKey: '$contact||$site',
    ).toMap(),
  );
}

Project _project({required String id}) {
  return Project(
    id: id,
    contact: '甲方',
    site: '一号工地',
    status: ProjectStatus.active,
    createdAt: '2026-05-18T00:00:00.000Z',
    updatedAt: '2026-05-18T00:00:00.000Z',
    legacyProjectKey: '甲方||一号工地',
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
