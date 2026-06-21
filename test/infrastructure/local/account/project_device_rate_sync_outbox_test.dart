import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/repositories/project_rate_repository.dart';
import 'package:asset_ledger/features/account/state/project_rate_store.dart';
import 'package:asset_ledger/infrastructure/local/account/local_project_device_rate_write_use_case.dart';
import 'package:asset_ledger/infrastructure/local/account/project_device_rate_sync_enqueuer.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  late SqfliteProjectRateRepository repository;
  late ProjectRateStore store;

  const projectId = 'project:rate-a';
  final projectKey = ProjectKey.buildKey(contact: '甲方A', site: '工地A');

  ProjectDeviceRate rate({required int rateFen}) {
    return ProjectDeviceRate(
      projectId: projectId,
      projectKey: projectKey,
      deviceId: 7,
      isBreaking: true,
      rate: 0,
      rateFen: rateFen,
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
    repository = SqfliteProjectRateRepository();
    store = ProjectRateStore(
      repository,
      writeUseCase: LocalProjectDeviceRateWriteUseCase(
        projectRateRepository: repository,
      ),
    );
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test(
    'upsert updates row and enqueues project_device_rate update payload',
    () async {
      final db = await AppDatabase.database;
      await repository.upsert(rate(rateFen: 12000));
      await store.loadAll();

      await store.upsert(rate(rateFen: 15000));

      final businessRow = (await db.query('project_device_rates')).single;
      expect(businessRow['project_id'], projectId);
      expect(businessRow['project_key'], projectKey);
      expect(businessRow['device_id'], 7);
      expect(businessRow['is_breaking'], 1);
      expect(businessRow['rate_fen'], 15000);

      final outbox = (await db.query('sync_outbox')).single;
      final entityId = '$projectId:7:1';
      expect(outbox['entity_type'], ProjectDeviceRateSyncEnqueuer.entityType);
      expect(outbox['entity_id'], entityId);
      expect(outbox['operation'], 'update');

      final payload = _decodePayload(outbox);
      expect(payload['payload_schema_version'], 1);
      expect(payload['entity_type'], ProjectDeviceRateSyncEnqueuer.entityType);
      expect(payload['entity_id'], entityId);
      expect(payload['operation'], 'update');
      final record = (payload['record'] as Map).cast<String, Object?>();
      expect(record, {
        'project_id': projectId,
        'project_key': projectKey,
        'device_id': 7,
        'is_breaking': 1,
        'rate_fen': 15000,
      });

      final meta = (await db.query('entity_sync_meta')).single;
      expect(meta['entity_type'], ProjectDeviceRateSyncEnqueuer.entityType);
      expect(meta['local_id'], entityId);
      expect(meta['sync_status'], SyncStatus.pendingUpdate.name);
      expect(meta['version'], 0);
      expect(meta['source'], ProjectDeviceRateSyncEnqueuer.ownerAppSource);
      expect(meta['payload_hash'], outbox['payload_hash']);
    },
  );

  test(
    'delete removes row and enqueues project_device_rate delete payload',
    () async {
      final db = await AppDatabase.database;
      await repository.upsert(rate(rateFen: 16000));
      await store.loadAll();

      await store.delete(projectKey, 7, projectId: projectId, isBreaking: true);

      expect(await db.query('project_device_rates'), isEmpty);

      final outbox = (await db.query('sync_outbox')).single;
      final entityId = '$projectId:7:1';
      expect(outbox['entity_type'], ProjectDeviceRateSyncEnqueuer.entityType);
      expect(outbox['entity_id'], entityId);
      expect(outbox['operation'], 'delete');

      final payload = _decodePayload(outbox);
      expect(payload['payload_schema_version'], 1);
      expect(payload['entity_type'], ProjectDeviceRateSyncEnqueuer.entityType);
      expect(payload['entity_id'], entityId);
      expect(payload['operation'], 'delete');
      final record = (payload['record'] as Map).cast<String, Object?>();
      expect(record, {
        'project_id': projectId,
        'project_key': projectKey,
        'device_id': 7,
        'is_breaking': 1,
        'rate_fen': 16000,
      });

      final meta = (await db.query('entity_sync_meta')).single;
      expect(meta['entity_type'], ProjectDeviceRateSyncEnqueuer.entityType);
      expect(meta['local_id'], entityId);
      expect(meta['sync_status'], SyncStatus.pendingDelete.name);
      expect(meta['version'], 0);
      expect(meta['source'], ProjectDeviceRateSyncEnqueuer.ownerAppSource);
      expect(meta['payload_hash'], outbox['payload_hash']);
    },
  );
}

Map<String, Object?> _decodePayload(Map<String, Object?> row) {
  return (jsonDecode(row['payload_json'] as String) as Map)
      .cast<String, Object?>();
}
