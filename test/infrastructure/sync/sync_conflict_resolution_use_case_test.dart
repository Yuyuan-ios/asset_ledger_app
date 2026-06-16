import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
import 'package:asset_ledger/infrastructure/sync/sync_conflict_repository.dart';
import 'package:asset_ledger/infrastructure/sync/sync_conflict_resolution_use_case.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  final fixedNow = DateTime.utc(2026, 6, 16, 10);

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

  test(
    'useRemote applies remote timing payload and resolves conflict',
    () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db);
      await db.insert(
        'timing_records',
        _timingRow(id: 401, deviceId: deviceId, incomeFen: 10000),
      );
      await db.insert('sync_outbox', {
        'id': 'local-dirty-401',
        'entity_type': 'timing_record',
        'entity_id': '401',
        'operation': 'update',
        'payload_json': '{"local":true}',
        'payload_hash': 'local-hash',
        'status': SyncOutboxStatus.pending.name,
        'retry_count': 0,
        'created_at': fixedNow.toUtc().toIso8601String(),
        'updated_at': fixedNow.toUtc().toIso8601String(),
      });
      await const LocalEntitySyncMetaRepository().upsert(
        const EntitySyncMeta(
          entityType: 'timing_record',
          localId: '401',
          syncStatus: SyncStatus.pendingUpdate,
          version: 1,
          source: 'owner_app',
          payloadHash: 'local-hash',
        ),
      );
      final conflict = _conflict(
        entityId: 401,
        deviceId: deviceId,
        remoteNewVersion: 2,
        remoteIncomeFen: 30000,
      );
      await const LocalSyncConflictRepository().insertIfAbsent(conflict);

      await SyncConflictResolutionUseCase(
        now: () => fixedNow,
      ).useRemote(conflict);

      expect((await db.query('timing_records')).single['income_fen'], 30000);
      expect(await db.query('sync_outbox'), isEmpty);
      final meta = (await db.query('entity_sync_meta')).single;
      expect(meta['sync_status'], SyncStatus.synced.name);
      expect(meta['version'], 2);
      expect(meta['payload_hash'], conflict.remotePayloadHash);
      final resolved = (await db.query('sync_conflicts')).single;
      expect(resolved['status'], SyncConflictStatus.resolved.name);
      expect(resolved['resolution'], SyncConflictResolution.remote.name);
    },
  );

  test('useLocal rebases meta version and enqueues local update', () async {
    final db = await AppDatabase.database;
    final deviceId = await _seedDevice(db);
    await _seedProject(db);
    await db.insert(
      'timing_records',
      _timingRow(id: 402, deviceId: deviceId, incomeFen: 10000),
    );
    await const LocalEntitySyncMetaRepository().upsert(
      const EntitySyncMeta(
        entityType: 'timing_record',
        localId: '402',
        syncStatus: SyncStatus.pendingUpdate,
        version: 1,
        source: 'owner_app',
        payloadHash: 'local-hash',
      ),
    );
    final conflict = _conflict(
      entityId: 402,
      deviceId: deviceId,
      remoteNewVersion: 5,
      remoteIncomeFen: 30000,
    );
    await const LocalSyncConflictRepository().insertIfAbsent(conflict);

    await SyncConflictResolutionUseCase(now: () => fixedNow).useLocal(conflict);

    expect((await db.query('timing_records')).single['income_fen'], 10000);
    final meta = (await db.query('entity_sync_meta')).single;
    expect(meta['sync_status'], SyncStatus.pendingUpdate.name);
    expect(meta['version'], 5);
    expect(meta['payload_hash'], isNot('local-hash'));
    final outbox = (await db.query('sync_outbox')).single;
    expect(outbox['entity_type'], 'timing_record');
    expect(outbox['entity_id'], '402');
    expect(outbox['operation'], 'update');
    expect(outbox['status'], SyncOutboxStatus.pending.name);
    final payload =
        jsonDecode(outbox['payload_json'] as String) as Map<String, Object?>;
    final record = payload['record'] as Map<String, Object?>;
    expect(record['income_fen'], 10000);
    final resolved = (await db.query('sync_conflicts')).single;
    expect(resolved['status'], SyncConflictStatus.resolved.name);
    expect(resolved['resolution'], SyncConflictResolution.local.name);
  });
}

Future<int> _seedDevice(Database db) {
  return db.insert('devices', {
    'name': 'Device',
    'brand': 'brand',
    'default_unit_price_fen': 10000,
    'base_meter_hours': 0.0,
    'is_active': 1,
    'equipment_type': 'excavator',
  });
}

Future<void> _seedProject(Database db) {
  return db.insert('projects', {
    'id': 'project:alpha',
    'contact': 'Alpha',
    'site': 'Site',
    'status': 'active',
    'created_at': '2026-06-01T00:00:00.000Z',
    'updated_at': '2026-06-01T00:00:00.000Z',
    'legacy_project_key': 'Alpha||Site',
  });
}

Map<String, Object?> _timingRow({
  required int id,
  required int deviceId,
  required int incomeFen,
}) {
  return {
    'id': id,
    'project_id': 'project:alpha',
    'device_id': deviceId,
    'start_date': 20260601,
    'allocation_cutoff_date': null,
    'display_end_date': null,
    'contact': 'Alpha',
    'site': 'Site',
    'type': 'hours',
    'start_meter': 0.0,
    'end_meter': 1.0,
    'hours': 1.0,
    'income_fen': incomeFen,
    'unit': 'HOUR',
    'quantity_scaled': 1000,
    'exclude_from_fuel_eff': 0,
    'is_breaking': 0,
  };
}

SyncConflict _conflict({
  required int entityId,
  required int deviceId,
  required int remoteNewVersion,
  required int remoteIncomeFen,
}) {
  final payloadJson = jsonEncode({
    'payload_schema_version': 1,
    'entity_type': 'timing_record',
    'entity_id': entityId.toString(),
    'operation': 'update',
    'record': _timingRow(
      id: entityId,
      deviceId: deviceId,
      incomeFen: remoteIncomeFen,
    ),
  });
  return SyncConflict(
    id: 'timing_record:$entityId:9',
    entityType: 'timing_record',
    entityId: entityId.toString(),
    remoteServerSeq: 9,
    remoteBaseVersion: remoteNewVersion - 1,
    remoteNewVersion: remoteNewVersion,
    remotePayloadJson: payloadJson,
    remotePayloadHash: sha256.convert(utf8.encode(payloadJson)).toString(),
    remoteDeleted: false,
    conflictReason: 'remote_newer_local_dirty',
    detectedAt: '2026-06-16T09:00:00.000Z',
    status: SyncConflictStatus.pending,
  );
}
