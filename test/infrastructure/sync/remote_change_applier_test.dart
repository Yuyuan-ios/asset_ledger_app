import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/local/account/project_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/sync/remote_change.dart';
import 'package:asset_ledger/infrastructure/sync/remote_change_applier.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:asset_ledger/infrastructure/sync/sync_actor.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/fake_cloud_api_client.dart';
import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  final fixedNow = DateTime.utc(2026, 6, 2, 8, 0, 0);

  setUp(() async {
    await AppDatabase.resetForTest();
    await _openCurrentInMemoryDb();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('ProjectRemoteChangeApplier', () {
    const applier = ProjectRemoteChangeApplier();

    test('inserts a missing project row and writes synced meta', () async {
      final db = await AppDatabase.database;
      final change = _projectChange(
        entityId: 'project:a',
        newVersion: 2,
        payloadHash: 'hash-project-insert',
        record: _projectRecord(id: 'project:a'),
      );

      await applier.apply(change, now: fixedNow);

      final rows = await db.query('projects');
      expect(rows, [_projectRecord(id: 'project:a')]);
      _expectSyncedMeta(
        await _singleMeta(db),
        entityType: ProjectRemoteChangeApplier.entityType,
        localId: 'project:a',
        version: 2,
        payloadHash: 'hash-project-insert',
        deletedAt: null,
      );
    });

    test('updates an existing project row with the remote snapshot', () async {
      final db = await AppDatabase.database;
      await db.insert('projects', _projectRecord(id: 'project:a'));
      final updatedRecord = _projectRecord(
        id: 'project:a',
        contact: 'client-updated',
        site: 'site-updated',
        status: ProjectStatus.settled.name,
        settledAt: '2026-06-03T00:00:00.000Z',
        settledSnapshot: '{"remaining":0}',
        updatedAt: '2026-06-03T00:00:00.000Z',
      );

      await applier.apply(
        _projectChange(
          entityId: 'project:a',
          newVersion: 3,
          payloadHash: 'hash-project-update',
          record: updatedRecord,
        ),
        now: fixedNow,
      );

      final rows = await db.query('projects');
      expect(rows, [updatedRecord]);
      _expectSyncedMeta(
        await _singleMeta(db),
        entityType: ProjectRemoteChangeApplier.entityType,
        localId: 'project:a',
        version: 3,
        payloadHash: 'hash-project-update',
        deletedAt: null,
      );
    });

    test(
      'deletes a tombstoned project row and records deleted synced meta',
      () async {
        final db = await AppDatabase.database;
        await db.insert('projects', _projectRecord(id: 'project:a'));

        await applier.apply(
          _projectChange(
            entityId: 'project:a',
            newVersion: 4,
            payloadHash: 'hash-project-delete',
            deleted: true,
            record: _projectRecord(id: 'project:a'),
          ),
          now: fixedNow,
        );

        expect(await db.query('projects'), isEmpty);
        _expectSyncedMeta(
          await _singleMeta(db),
          entityType: ProjectRemoteChangeApplier.entityType,
          localId: 'project:a',
          version: 4,
          payloadHash: 'hash-project-delete',
          deletedAt: fixedNow.toIso8601String(),
        );
      },
    );

    test('replaying the same payload hash remains idempotent', () async {
      final db = await AppDatabase.database;
      final change = _projectChange(
        entityId: 'project:a',
        newVersion: 5,
        payloadHash: 'hash-project-replay',
        record: _projectRecord(id: 'project:a'),
      );

      await applier.apply(change, now: fixedNow);
      await applier.apply(change, now: fixedNow);

      final rows = await db.query('projects');
      expect(rows, hasLength(1));
      expect(rows.single, _projectRecord(id: 'project:a'));
      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(1));
      _expectSyncedMeta(
        metaRows.single,
        entityType: ProjectRemoteChangeApplier.entityType,
        localId: 'project:a',
        version: 5,
        payloadHash: 'hash-project-replay',
        deletedAt: null,
      );
    });

    test('accepts ProjectSyncEnqueuer payload contract round-trip', () async {
      final db = await AppDatabase.database;
      final project = Project(
        id: 'project:roundtrip',
        contact: 'client',
        site: 'site',
        status: ProjectStatus.settled,
        settledAt: '2026-06-03T00:00:00.000Z',
        settledSnapshot: '{"remaining":0}',
        createdAt: '2026-06-01T00:00:00.000Z',
        updatedAt: '2026-06-03T00:00:00.000Z',
        legacyProjectKey: 'client||site',
      );

      await AppDatabase.inTransaction<void>((txn) {
        return const ProjectSyncEnqueuer().enqueueUpdate(txn, project: project);
      });
      final outbox = (await db.query('sync_outbox')).single;
      await db.delete('entity_sync_meta');

      await applier.apply(
        RemoteChange(
          serverSeq: 10,
          entityType: outbox['entity_type'] as String,
          entityId: outbox['entity_id'] as String,
          baseVersion: 0,
          newVersion: 1,
          payloadJson: outbox['payload_json'] as String,
          payloadHash: outbox['payload_hash'] as String,
          deleted: false,
        ),
        now: fixedNow,
      );

      expect(await db.query('projects'), [project.toMap()]);
      _expectSyncedMeta(
        await _singleMeta(db),
        entityType: ProjectSyncEnqueuer.entityType,
        localId: project.id,
        version: 1,
        payloadHash: outbox['payload_hash'] as String,
        deletedAt: null,
      );
    });
  });

  group('ProjectDeviceRateRemoteChangeApplier', () {
    const applier = ProjectDeviceRateRemoteChangeApplier();
    const projectId = 'project:rate';

    test(
      'inserts a missing project-device-rate row and writes synced meta',
      () async {
        final db = await AppDatabase.database;
        await _insertProject(db, id: projectId);
        final record = _projectDeviceRateRecord(projectId: projectId);
        final entityId = _rateEntityId(projectId, 7, 1);

        await applier.apply(
          _change(
            entityType: ProjectDeviceRateRemoteChangeApplier.entityType,
            entityId: entityId,
            newVersion: 2,
            payloadHash: 'hash-rate-insert',
            record: record,
          ),
          now: fixedNow,
        );

        expect(await db.query('project_device_rates'), [record]);
        _expectSyncedMeta(
          await _singleMeta(db),
          entityType: ProjectDeviceRateRemoteChangeApplier.entityType,
          localId: entityId,
          version: 2,
          payloadHash: 'hash-rate-insert',
          deletedAt: null,
        );
      },
    );

    test('updates an existing project-device-rate row', () async {
      final db = await AppDatabase.database;
      await _insertProject(db, id: projectId);
      await db.insert(
        'project_device_rates',
        _projectDeviceRateRecord(projectId: projectId, rateFen: 10000),
      );
      final updatedRecord = _projectDeviceRateRecord(
        projectId: projectId,
        rateFen: 13500,
      );
      final entityId = _rateEntityId(projectId, 7, 1);

      await applier.apply(
        _change(
          entityType: ProjectDeviceRateRemoteChangeApplier.entityType,
          entityId: entityId,
          newVersion: 3,
          payloadHash: 'hash-rate-update',
          record: updatedRecord,
        ),
        now: fixedNow,
      );

      expect(await db.query('project_device_rates'), [updatedRecord]);
      _expectSyncedMeta(
        await _singleMeta(db),
        entityType: ProjectDeviceRateRemoteChangeApplier.entityType,
        localId: entityId,
        version: 3,
        payloadHash: 'hash-rate-update',
        deletedAt: null,
      );
    });

    test('deletes a tombstoned project-device-rate row', () async {
      final db = await AppDatabase.database;
      await _insertProject(db, id: projectId);
      final record = _projectDeviceRateRecord(projectId: projectId);
      await db.insert('project_device_rates', record);
      final entityId = _rateEntityId(projectId, 7, 1);

      await applier.apply(
        _change(
          entityType: ProjectDeviceRateRemoteChangeApplier.entityType,
          entityId: entityId,
          newVersion: 4,
          payloadHash: 'hash-rate-delete',
          deleted: true,
          record: record,
        ),
        now: fixedNow,
      );

      expect(await db.query('project_device_rates'), isEmpty);
      _expectSyncedMeta(
        await _singleMeta(db),
        entityType: ProjectDeviceRateRemoteChangeApplier.entityType,
        localId: entityId,
        version: 4,
        payloadHash: 'hash-rate-delete',
        deletedAt: fixedNow.toIso8601String(),
      );
    });

    test('replaying the same payload hash remains idempotent', () async {
      final db = await AppDatabase.database;
      await _insertProject(db, id: projectId);
      final record = _projectDeviceRateRecord(projectId: projectId);
      final entityId = _rateEntityId(projectId, 7, 1);
      final change = _change(
        entityType: ProjectDeviceRateRemoteChangeApplier.entityType,
        entityId: entityId,
        newVersion: 5,
        payloadHash: 'hash-rate-replay',
        record: record,
      );

      await applier.apply(change, now: fixedNow);
      await applier.apply(change, now: fixedNow);

      final rows = await db.query('project_device_rates');
      expect(rows, hasLength(1));
      expect(rows.single, record);
      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(1));
      _expectSyncedMeta(
        metaRows.single,
        entityType: ProjectDeviceRateRemoteChangeApplier.entityType,
        localId: entityId,
        version: 5,
        payloadHash: 'hash-rate-replay',
        deletedAt: null,
      );
    });
  });

  group('FuelLogRemoteChangeApplier', () {
    const applier = FuelLogRemoteChangeApplier();

    test('inserts a missing fuel log row and writes synced meta', () async {
      final db = await AppDatabase.database;
      final record = _fuelLogRecord(id: 21);

      await applier.apply(
        _change(
          entityType: FuelLogRemoteChangeApplier.entityType,
          entityId: '21',
          newVersion: 2,
          payloadHash: 'hash-fuel-insert',
          record: record,
        ),
        now: fixedNow,
      );

      expect(await db.query('fuel_logs'), [record]);
      _expectSyncedMeta(
        await _singleMeta(db),
        entityType: FuelLogRemoteChangeApplier.entityType,
        localId: '21',
        version: 2,
        payloadHash: 'hash-fuel-insert',
        deletedAt: null,
      );
    });

    test('updates an existing fuel log row', () async {
      final db = await AppDatabase.database;
      await db.insert('fuel_logs', _fuelLogRecord(id: 21, costFen: 10000));
      final updatedRecord = _fuelLogRecord(
        id: 21,
        supplier: 'supplier-updated',
        liters: 82.5,
        costFen: 13500,
      );

      await applier.apply(
        _change(
          entityType: FuelLogRemoteChangeApplier.entityType,
          entityId: '21',
          newVersion: 3,
          payloadHash: 'hash-fuel-update',
          record: updatedRecord,
        ),
        now: fixedNow,
      );

      expect(await db.query('fuel_logs'), [updatedRecord]);
      _expectSyncedMeta(
        await _singleMeta(db),
        entityType: FuelLogRemoteChangeApplier.entityType,
        localId: '21',
        version: 3,
        payloadHash: 'hash-fuel-update',
        deletedAt: null,
      );
    });

    test('deletes a tombstoned fuel log row', () async {
      final db = await AppDatabase.database;
      final record = _fuelLogRecord(id: 21);
      await db.insert('fuel_logs', record);

      await applier.apply(
        _change(
          entityType: FuelLogRemoteChangeApplier.entityType,
          entityId: '21',
          newVersion: 4,
          payloadHash: 'hash-fuel-delete',
          deleted: true,
          record: record,
        ),
        now: fixedNow,
      );

      expect(await db.query('fuel_logs'), isEmpty);
      _expectSyncedMeta(
        await _singleMeta(db),
        entityType: FuelLogRemoteChangeApplier.entityType,
        localId: '21',
        version: 4,
        payloadHash: 'hash-fuel-delete',
        deletedAt: fixedNow.toIso8601String(),
      );
    });

    test('replaying the same payload hash remains idempotent', () async {
      final db = await AppDatabase.database;
      final record = _fuelLogRecord(id: 21);
      final change = _change(
        entityType: FuelLogRemoteChangeApplier.entityType,
        entityId: '21',
        newVersion: 5,
        payloadHash: 'hash-fuel-replay',
        record: record,
      );

      await applier.apply(change, now: fixedNow);
      await applier.apply(change, now: fixedNow);

      final rows = await db.query('fuel_logs');
      expect(rows, hasLength(1));
      expect(rows.single, record);
      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(1));
      _expectSyncedMeta(
        metaRows.single,
        entityType: FuelLogRemoteChangeApplier.entityType,
        localId: '21',
        version: 5,
        payloadHash: 'hash-fuel-replay',
        deletedAt: null,
      );
    });
  });

  group('MaintenanceRecordRemoteChangeApplier', () {
    const applier = MaintenanceRecordRemoteChangeApplier();

    test('inserts a missing maintenance row and writes synced meta', () async {
      final db = await AppDatabase.database;
      final record = _maintenanceRecord(id: 31, deviceId: null);

      await applier.apply(
        _change(
          entityType: MaintenanceRecordRemoteChangeApplier.entityType,
          entityId: '31',
          newVersion: 2,
          payloadHash: 'hash-maintenance-insert',
          record: record,
        ),
        now: fixedNow,
      );

      expect(await db.query('maintenance_records'), [record]);
      _expectSyncedMeta(
        await _singleMeta(db),
        entityType: MaintenanceRecordRemoteChangeApplier.entityType,
        localId: '31',
        version: 2,
        payloadHash: 'hash-maintenance-insert',
        deletedAt: null,
      );
    });

    test('updates an existing maintenance row', () async {
      final db = await AppDatabase.database;
      await db.insert(
        'maintenance_records',
        _maintenanceRecord(id: 31, amountFen: 10000),
      );
      final updatedRecord = _maintenanceRecord(
        id: 31,
        deviceId: 8,
        item: 'item-updated',
        amountFen: 13500,
        note: 'note-updated',
      );

      await applier.apply(
        _change(
          entityType: MaintenanceRecordRemoteChangeApplier.entityType,
          entityId: '31',
          newVersion: 3,
          payloadHash: 'hash-maintenance-update',
          record: updatedRecord,
        ),
        now: fixedNow,
      );

      expect(await db.query('maintenance_records'), [updatedRecord]);
      _expectSyncedMeta(
        await _singleMeta(db),
        entityType: MaintenanceRecordRemoteChangeApplier.entityType,
        localId: '31',
        version: 3,
        payloadHash: 'hash-maintenance-update',
        deletedAt: null,
      );
    });

    test('deletes a tombstoned maintenance row', () async {
      final db = await AppDatabase.database;
      final record = _maintenanceRecord(id: 31);
      await db.insert('maintenance_records', record);

      await applier.apply(
        _change(
          entityType: MaintenanceRecordRemoteChangeApplier.entityType,
          entityId: '31',
          newVersion: 4,
          payloadHash: 'hash-maintenance-delete',
          deleted: true,
          record: record,
        ),
        now: fixedNow,
      );

      expect(await db.query('maintenance_records'), isEmpty);
      _expectSyncedMeta(
        await _singleMeta(db),
        entityType: MaintenanceRecordRemoteChangeApplier.entityType,
        localId: '31',
        version: 4,
        payloadHash: 'hash-maintenance-delete',
        deletedAt: fixedNow.toIso8601String(),
      );
    });

    test('replaying the same payload hash remains idempotent', () async {
      final db = await AppDatabase.database;
      final record = _maintenanceRecord(id: 31);
      final change = _change(
        entityType: MaintenanceRecordRemoteChangeApplier.entityType,
        entityId: '31',
        newVersion: 5,
        payloadHash: 'hash-maintenance-replay',
        record: record,
      );

      await applier.apply(change, now: fixedNow);
      await applier.apply(change, now: fixedNow);

      final rows = await db.query('maintenance_records');
      expect(rows, hasLength(1));
      expect(rows.single, record);
      final metaRows = await db.query('entity_sync_meta');
      expect(metaRows, hasLength(1));
      _expectSyncedMeta(
        metaRows.single,
        entityType: MaintenanceRecordRemoteChangeApplier.entityType,
        localId: '31',
        version: 5,
        payloadHash: 'hash-maintenance-replay',
        deletedAt: null,
      );
    });
  });

  group('SyncManager pull registry', () {
    test(
      'dispatches registered mirror entities and skips unknown ones',
      () async {
        final db = await AppDatabase.database;
        const projectId = 'project:registry';
        final projectChange = _projectChange(
          entityId: projectId,
          newVersion: 1,
          payloadHash: 'hash-registry-project',
          record: _projectRecord(id: projectId),
        );
        final rateChange = _change(
          entityType: ProjectDeviceRateRemoteChangeApplier.entityType,
          entityId: _rateEntityId(projectId, 7, 0),
          newVersion: 1,
          payloadHash: 'hash-registry-rate',
          record: _projectDeviceRateRecord(projectId: projectId, isBreaking: 0),
        );
        final fuelChange = _change(
          entityType: FuelLogRemoteChangeApplier.entityType,
          entityId: '41',
          newVersion: 1,
          payloadHash: 'hash-registry-fuel',
          record: _fuelLogRecord(id: 41),
        );
        final maintenanceChange = _change(
          entityType: MaintenanceRecordRemoteChangeApplier.entityType,
          entityId: '51',
          newVersion: 1,
          payloadHash: 'hash-registry-maintenance',
          record: _maintenanceRecord(id: 51, deviceId: null),
        );
        final unknownChange = _change(
          entityType: 'unsupported_entity',
          entityId: 'unknown:1',
          newVersion: 1,
          payloadHash: 'hash-registry-unknown',
          record: const {'id': 'unknown:1'},
        );
        final changes = [
          projectChange,
          rateChange,
          fuelChange,
          maintenanceChange,
          unknownChange,
        ];
        final client = FakeCloudApiClient()
          ..respondDefault(
            ApiResponse(
              statusCode: 200,
              bodyJson: jsonEncode({
                'changes': [
                  for (var i = 0; i < changes.length; i += 1)
                    _changeJson(changes[i], serverSeq: i + 1),
                ],
                'next_cursor': changes.length,
              }),
            ),
          );

        final result = await SyncManager(
          outboxRepository: const LocalSyncOutboxRepository(),
          apiClient: client,
          syncStateRepository: const LocalSyncStateRepository(),
          metaRepository: const LocalEntitySyncMetaRepository(),
          pullMetaRepository: const LocalEntitySyncMetaRepository(),
          now: () => fixedNow,
        ).pullPending(limit: 10);

        expect(result.applied, 4);
        expect(result.skippedUnsupported, 1);
        expect(result.nextCursor, 5);
        expect(await db.query('projects'), [_projectRecord(id: projectId)]);
        expect(await db.query('project_device_rates'), [
          _projectDeviceRateRecord(projectId: projectId, isBreaking: 0),
        ]);
        expect(await db.query('fuel_logs'), [_fuelLogRecord(id: 41)]);
        expect(await db.query('maintenance_records'), [
          _maintenanceRecord(id: 51, deviceId: null),
        ]);
        expect(await db.query('entity_sync_meta'), hasLength(4));
      },
    );
  });
}

RemoteChange _projectChange({
  required String entityId,
  required int newVersion,
  required String payloadHash,
  required Map<String, Object?> record,
  bool deleted = false,
}) {
  return RemoteChange(
    serverSeq: newVersion,
    entityType: ProjectRemoteChangeApplier.entityType,
    entityId: entityId,
    baseVersion: newVersion - 1,
    newVersion: newVersion,
    payloadJson: jsonEncode({
      'payload_schema_version': kSyncPayloadSchemaVersion,
      'entity_type': ProjectRemoteChangeApplier.entityType,
      'entity_id': entityId,
      'operation': deleted ? 'delete' : 'update',
      'record': record,
    }),
    payloadHash: payloadHash,
    deleted: deleted,
  );
}

RemoteChange _change({
  required String entityType,
  required String entityId,
  required int newVersion,
  required String payloadHash,
  required Map<String, Object?> record,
  bool deleted = false,
}) {
  return RemoteChange(
    serverSeq: newVersion,
    entityType: entityType,
    entityId: entityId,
    baseVersion: newVersion - 1,
    newVersion: newVersion,
    payloadJson: jsonEncode({
      'payload_schema_version': kSyncPayloadSchemaVersion,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': deleted ? 'delete' : 'update',
      'record': record,
    }),
    payloadHash: payloadHash,
    deleted: deleted,
  );
}

Map<String, Object?> _changeJson(
  RemoteChange change, {
  required int serverSeq,
}) {
  return {
    'server_seq': serverSeq,
    'entity_type': change.entityType,
    'entity_id': change.entityId,
    'base_version': change.baseVersion,
    'new_version': change.newVersion,
    'payload_json': change.payloadJson,
    'payload_hash': change.payloadHash,
    'deleted': change.deleted,
    'origin_device_id': change.originDeviceId,
  };
}

Map<String, Object?> _projectRecord({
  required String id,
  String contact = 'client',
  String site = 'site',
  String status = 'active',
  String? settledAt,
  String? settledSnapshot,
  String createdAt = '2026-06-01T00:00:00.000Z',
  String updatedAt = '2026-06-02T00:00:00.000Z',
  String? legacyProjectKey = 'client||site',
}) {
  return {
    'id': id,
    'contact': contact,
    'site': site,
    'status': status,
    'settled_at': settledAt,
    'settled_snapshot': settledSnapshot,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'legacy_project_key': legacyProjectKey,
  };
}

Map<String, Object?> _projectDeviceRateRecord({
  required String projectId,
  String projectKey = 'client||site',
  int deviceId = 7,
  int isBreaking = 1,
  int rateFen = 12000,
}) {
  return {
    'project_id': projectId,
    'project_key': projectKey,
    'device_id': deviceId,
    'is_breaking': isBreaking,
    'rate_fen': rateFen,
  };
}

Map<String, Object?> _fuelLogRecord({
  required int id,
  int deviceId = 7,
  int date = 20260602,
  String supplier = 'supplier',
  double liters = 80.5,
  int costFen = 12000,
}) {
  return {
    'id': id,
    'device_id': deviceId,
    'date': date,
    'supplier': supplier,
    'liters': liters,
    'cost_fen': costFen,
  };
}

Map<String, Object?> _maintenanceRecord({
  required int id,
  int? deviceId = 7,
  int ymd = 20260602,
  String item = 'item',
  int amountFen = 12000,
  String? note = 'note',
}) {
  return {
    'id': id,
    'device_id': deviceId,
    'ymd': ymd,
    'item': item,
    'amount_fen': amountFen,
    'note': note,
  };
}

String _rateEntityId(String projectId, int deviceId, int isBreaking) {
  return '$projectId:$deviceId:$isBreaking';
}

Future<void> _insertProject(Database db, {required String id}) {
  return db.insert('projects', _projectRecord(id: id));
}

Future<Map<String, Object?>> _singleMeta(Database db) async {
  final rows = await db.query('entity_sync_meta');
  expect(rows, hasLength(1));
  return rows.single;
}

void _expectSyncedMeta(
  Map<String, Object?> meta, {
  required String entityType,
  required String localId,
  required int version,
  required String payloadHash,
  required String? deletedAt,
}) {
  expect(meta['entity_type'], entityType);
  expect(meta['local_id'], localId);
  expect(meta['sync_status'], SyncStatus.synced.name);
  expect(meta['version'], version);
  expect(meta['source'], 'owner_app');
  expect(meta['payload_hash'], payloadHash);
  expect(meta['last_synced_at'], fixedNowIso);
  expect(meta['deleted_at'], deletedAt);
}

String get fixedNowIso => DateTime.utc(2026, 6, 2, 8, 0, 0).toIso8601String();

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
