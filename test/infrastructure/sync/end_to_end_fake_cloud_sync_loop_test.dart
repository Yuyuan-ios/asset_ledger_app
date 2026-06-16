import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/local/account/local_account_payment_write_use_case.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
import 'package:asset_ledger/infrastructure/sync/sync_conflict_repository.dart';
import 'package:asset_ledger/infrastructure/sync/sync_live_readiness_gate.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/fake_cloud_api_client.dart';
import '../../test_setup.dart';

/// R5.28：把"入队半段 + 排空半段"第一次组合成端到端闭环。
///
/// 用**真实生产写路径**（LocalAccountPaymentWriteUseCase.create）产生 outbox +
/// entity_sync_meta(pendingUpload)，再经 SyncManager.pushPending(live) 打到一个
/// 功能性假云（FakeCloudApiClient），证明:云收到 POST /sync/outbox payload →
/// ack → outbox 删行 → meta pendingUpload→synced；幂等；retryable failure 不误标
/// synced 且行保留待重试；fake-cloud conflict 不覆盖本地权威账。
///
/// 仅测试层组合（不接真 HTTP / 不 pull / 不接生产 App composition root / 不改默认
/// readiness gate）；脊柱用 StaticSyncLiveReadinessGate.readyForTest() 显式放行
/// live push（不是静默 fallback）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  final fixedNow = DateTime.utc(2026, 6, 1, 12, 0, 0);

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

  // 除 apiClient 与 readinessGate 外，全部使用真实本地仓（outbox / meta / state）。
  SyncManager managerWith(FakeCloudApiClient client, {String? localDeviceId}) {
    return SyncManager(
      outboxRepository: LocalSyncOutboxRepository(now: () => fixedNow),
      apiClient: client,
      syncStateRepository: const LocalSyncStateRepository(),
      metaRepository: const LocalEntitySyncMetaRepository(),
      liveReadinessGate: const StaticSyncLiveReadinessGate.readyForTest(),
      localDeviceId: localDeviceId,
      now: () => fixedNow,
    );
  }

  // 真实业务写入：同事务 insert account_payment + 入队 outbox + 写 meta。
  Future<int> createRealPayment() {
    final useCase = LocalAccountPaymentWriteUseCase(
      paymentRepository: SqfliteAccountPaymentRepository(),
    );
    return useCase.create(
      AccountPayment(
        projectId: 'project:a',
        projectKey: ProjectKey.buildKey(contact: '甲方', site: '工地'),
        ymd: 20260601,
        amount: 500, // -> amount_fen 50000
        createdAt: '2026-06-01T00:00:00.000Z',
      ),
    );
  }

  test(
    'real payment write -> live push -> fake-cloud ack: outbox cleared, meta '
    'pendingUpload->synced, idempotent',
    () async {
      final db = await AppDatabase.database;

      // --- 入队半段：由真实业务写入产生（不手工预填 outbox）。
      final id = await createRealPayment();
      expect(await db.query('account_payments'), hasLength(1));

      final outboxBefore = await db.query('sync_outbox');
      expect(outboxBefore, hasLength(1));
      expect(outboxBefore.single['entity_type'], 'account_payment');
      expect(outboxBefore.single['entity_id'], id.toString());
      expect(outboxBefore.single['operation'], 'create');
      expect(outboxBefore.single['status'], SyncOutboxStatus.pending.name);
      final payloadHash = outboxBefore.single['payload_hash'] as String;

      final metaBefore = (await db.query('entity_sync_meta')).single;
      expect(metaBefore['entity_type'], 'account_payment');
      expect(metaBefore['local_id'], id.toString());
      expect(metaBefore['sync_status'], SyncStatus.pendingUpload.name);

      // --- 排空半段：SyncManager live push 到假云。
      final client = FakeCloudApiClient();
      final result = await managerWith(
        client,
      ).pushPending(mode: SyncPushMode.live);

      expect(result.pushed, 1);
      expect(result.failed, 0);

      // 假云恰好收到 1 个 POST /sync/outbox，payload 逐字段正确。
      expect(client.receivedRequests, hasLength(1));
      final req = client.receivedRequests.single;
      expect(req.method, 'POST');
      expect(req.path, '/sync/outbox');
      expect(req.headers['x-payload-hash'], payloadHash);
      final body = jsonDecode(req.bodyJson!) as Map<String, Object?>;
      expect(body['entity_type'], 'account_payment');
      expect(body['operation'], 'create');
      final record = body['record'] as Map<String, Object?>;
      expect(record['amount_fen'], 50000);

      // ack：outbox 删行、meta pendingUpload->synced + last_synced_at。
      expect(await db.query('sync_outbox'), isEmpty);
      final metaAfter = (await db.query('entity_sync_meta')).single;
      expect(metaAfter['sync_status'], SyncStatus.synced.name);
      expect(metaAfter['last_synced_at'], isNotNull);

      // 幂等：再推无新请求、状态不变。
      final client2 = FakeCloudApiClient();
      final result2 = await managerWith(
        client2,
      ).pushPending(mode: SyncPushMode.live);
      expect(result2.pushed, 0);
      expect(client2.receivedRequests, isEmpty);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(
        (await db.query('entity_sync_meta')).single['sync_status'],
        SyncStatus.synced.name,
      );
    },
  );

  test(
    'retryable failure keeps outbox row + meta pendingUpload (not synced); after '
    'backoff window it pushes and acks',
    () async {
      final db = await AppDatabase.database;
      await createRealPayment();

      // 失败：5xx + retryable error。
      final failClient = FakeCloudApiClient()
        ..respondDefault(fakeCloudFailure(statusCode: 503, retryable: true));
      final failResult = await managerWith(
        failClient,
      ).pushPending(mode: SyncPushMode.live);

      expect(failResult.failed, 1);
      expect(failResult.pushed, 0);
      expect(failClient.receivedRequests, hasLength(1));

      // 行保留、写 last_error / next_retry_at、status 仍 pending。
      final failedRow = (await db.query('sync_outbox')).single;
      expect(failedRow['status'], SyncOutboxStatus.pending.name);
      expect(failedRow['last_error'].toString(), contains('unavailable'));
      expect(failedRow['next_retry_at'], isNotNull);

      // meta 不能被误标 synced。
      expect(
        (await db.query('entity_sync_meta')).single['sync_status'],
        SyncStatus.pendingUpload.name,
      );

      // 退避到期（清 next_retry_at）后再推成功 → ack、synced。
      await db.update('sync_outbox', {'next_retry_at': null});
      final okClient = FakeCloudApiClient();
      final okResult = await managerWith(
        okClient,
      ).pushPending(mode: SyncPushMode.live);

      expect(okResult.pushed, 1);
      expect(okClient.receivedRequests, hasLength(1));
      expect(await db.query('sync_outbox'), isEmpty);
      expect(
        (await db.query('entity_sync_meta')).single['sync_status'],
        SyncStatus.synced.name,
      );
    },
  );

  test('fake-cloud conflict keeps outbox pending and does not overwrite local '
      'authority', () async {
    final db = await AppDatabase.database;
    final id = await createRealPayment();

    final conflictClient = FakeCloudApiClient()
      ..respondDefault(
        fakeCloudConflict(message: 'remote version has different payload'),
      );
    final result = await managerWith(
      conflictClient,
    ).pushPending(mode: SyncPushMode.live);

    expect(result.failed, 1);
    expect(result.pushed, 0);
    expect(conflictClient.receivedRequests, hasLength(1));

    final outboxAfter = (await db.query('sync_outbox')).single;
    expect(outboxAfter['entity_type'], 'account_payment');
    expect(outboxAfter['entity_id'], id.toString());
    expect(outboxAfter['status'], SyncOutboxStatus.pending.name);
    expect(outboxAfter['last_error'].toString(), contains('conflict'));
    expect(outboxAfter['next_retry_at'], isNotNull);

    final metaAfter = (await db.query('entity_sync_meta')).single;
    expect(metaAfter['sync_status'], SyncStatus.pendingUpload.name);
    expect(metaAfter['last_synced_at'], isNull);

    final localPayment = (await db.query('account_payments')).single;
    expect(localPayment['id'], id);
    expect(localPayment['amount_fen'], 50000);
    expect(localPayment.containsKey('amount'), isFalse);
    expect(localPayment['project_id'], 'project:a');
  });

  test(
    'pullPending applies remote timing create/update/delete directly without '
    'outbox backflow and is idempotent',
    () async {
      final db = await AppDatabase.database;
      final deviceId = await _seedDevice(db);
      await _seedProject(db, projectId: 'project:alpha');

      final client = FakeCloudApiClient()
        ..enqueueResponse(
          _pullResponse([
            _remoteTimingChange(
              serverSeq: 1,
              entityId: 101,
              baseVersion: 0,
              newVersion: 1,
              payload: _remoteTimingPayload(
                id: 101,
                deviceId: deviceId,
                incomeFen: 10000,
              ),
            ),
          ], nextCursor: 1),
        )
        ..enqueueResponse(
          _pullResponse([
            _remoteTimingChange(
              serverSeq: 1,
              entityId: 101,
              baseVersion: 0,
              newVersion: 1,
              payload: _remoteTimingPayload(
                id: 101,
                deviceId: deviceId,
                incomeFen: 10000,
              ),
            ),
          ], nextCursor: 1),
        )
        ..enqueueResponse(
          _pullResponse([
            _remoteTimingChange(
              serverSeq: 2,
              entityId: 101,
              baseVersion: 1,
              newVersion: 2,
              payload: _remoteTimingPayload(
                id: 101,
                deviceId: deviceId,
                incomeFen: 20000,
              ),
            ),
          ], nextCursor: 2),
        )
        ..enqueueResponse(
          _pullResponse([
            _remoteTimingChange(
              serverSeq: 3,
              entityId: 101,
              baseVersion: 2,
              newVersion: 3,
              payload: _remoteTimingPayload(
                id: 101,
                deviceId: deviceId,
                incomeFen: 20000,
              ),
              deleted: true,
            ),
          ], nextCursor: 3),
        );

      final createResult = await managerWith(client).pullPending(limit: 10);
      expect(createResult.applied, 1);
      expect(createResult.conflicts, isEmpty);
      expect(client.receivedRequests.single.method, 'GET');
      expect(
        client.receivedRequests.single.path,
        '/sync/changes?since=0&limit=10',
      );
      expect(await db.query('sync_outbox'), isEmpty);
      expect((await db.query('timing_records')).single['income_fen'], 10000);
      var meta = (await db.query('entity_sync_meta')).single;
      expect(meta['sync_status'], SyncStatus.synced.name);
      expect(meta['version'], 1);

      final duplicateResult = await managerWith(client).pullPending(limit: 10);
      expect(duplicateResult.applied, 0);
      expect(duplicateResult.skippedDuplicate, 1);
      expect(await db.query('sync_outbox'), isEmpty);
      expect((await db.query('timing_records')).single['income_fen'], 10000);

      final updateResult = await managerWith(client).pullPending(limit: 10);
      expect(updateResult.applied, 1);
      expect(await db.query('sync_outbox'), isEmpty);
      expect((await db.query('timing_records')).single['income_fen'], 20000);
      meta = (await db.query('entity_sync_meta')).single;
      expect(meta['version'], 2);
      expect(meta['payload_hash'], isNotNull);

      final deleteResult = await managerWith(client).pullPending(limit: 10);
      expect(deleteResult.applied, 1);
      expect(await db.query('timing_records'), isEmpty);
      expect(await db.query('sync_outbox'), isEmpty);
      meta = (await db.query('entity_sync_meta')).single;
      expect(meta['sync_status'], SyncStatus.synced.name);
      expect(meta['version'], 3);
      expect(meta['deleted_at'], isNotNull);
      expect(await const LocalSyncStateRepository().readPullCursor(), 3);
    },
  );

  test('pullPending keeps dirty local timing authority on conflict and leaves '
      'outbox pending', () async {
    final db = await AppDatabase.database;
    final deviceId = await _seedDevice(db);
    await _seedProject(db, projectId: 'project:alpha');
    await db.insert(
      'timing_records',
      _remoteTimingRecord(id: 201, deviceId: deviceId, incomeFen: 10000),
    );
    await db.insert('sync_outbox', {
      'id': 'dirty-201',
      'entity_type': 'timing_record',
      'entity_id': '201',
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
        localId: '201',
        syncStatus: SyncStatus.pendingUpdate,
        version: 1,
        source: 'owner_app',
        payloadHash: 'local-hash',
      ),
    );

    final remoteConflictResponse = _pullResponse([
      _remoteTimingChange(
        serverSeq: 4,
        entityId: 201,
        baseVersion: 1,
        newVersion: 2,
        payload: _remoteTimingPayload(
          id: 201,
          deviceId: deviceId,
          incomeFen: 30000,
        ),
      ),
    ], nextCursor: 4);
    final client = FakeCloudApiClient()
      ..enqueueResponse(remoteConflictResponse)
      ..enqueueResponse(remoteConflictResponse);

    final result = await managerWith(client).pullPending(limit: 10);

    expect(result.applied, 0);
    expect(result.conflicts, hasLength(1));
    expect(result.conflicts.single.reason, 'remote_newer_local_dirty');
    expect(await const LocalSyncStateRepository().readPullCursor(), 4);
    expect((await db.query('timing_records')).single['income_fen'], 10000);
    expect(
      (await db.query('entity_sync_meta')).single['sync_status'],
      SyncStatus.pendingUpdate.name,
    );
    final outboxAfter = (await db.query('sync_outbox')).single;
    expect(outboxAfter['status'], SyncOutboxStatus.pending.name);
    expect(outboxAfter['payload_hash'], 'local-hash');

    final conflicts = await const LocalSyncConflictRepository().listPending();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.entityType, 'timing_record');
    expect(conflicts.single.entityId, '201');
    expect(conflicts.single.remoteServerSeq, 4);
    expect(conflicts.single.remoteBaseVersion, 1);
    expect(conflicts.single.remoteNewVersion, 2);
    expect(conflicts.single.conflictReason, 'remote_newer_local_dirty');

    await const LocalSyncStateRepository().writePullCursor(3, now: fixedNow);
    final duplicateResult = await managerWith(client).pullPending(limit: 10);
    expect(duplicateResult.conflicts, hasLength(1));
    expect(
      await const LocalSyncConflictRepository().listPending(),
      hasLength(1),
    );
  });

  test('pullPending skips changes that originated from this device', () async {
    final db = await AppDatabase.database;
    final deviceId = await _seedDevice(db);
    await _seedProject(db, projectId: 'project:alpha');

    final client = FakeCloudApiClient()
      ..enqueueResponse(
        _pullResponse([
          _remoteTimingChange(
            serverSeq: 5,
            entityId: 301,
            baseVersion: 0,
            newVersion: 1,
            payload: _remoteTimingPayload(
              id: 301,
              deviceId: deviceId,
              incomeFen: 10000,
            ),
            originDeviceId: 'this-device',
          ),
        ], nextCursor: 5),
      );

    final result = await managerWith(
      client,
      localDeviceId: 'this-device',
    ).pullPending(limit: 10);

    expect(result.applied, 0);
    expect(result.skippedOwn, 1);
    expect(await db.query('timing_records'), isEmpty);
    expect(await db.query('sync_outbox'), isEmpty);
    expect(await const LocalSyncStateRepository().readPullCursor(), 5);
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

Future<void> _seedProject(Database db, {required String projectId}) {
  return db.insert('projects', {
    'id': projectId,
    'contact': '甲方',
    'site': projectId.split(':').last,
    'status': 'active',
    'created_at': '2026-06-01T00:00:00.000Z',
    'updated_at': '2026-06-01T00:00:00.000Z',
    'legacy_project_key': '甲方||${projectId.split(':').last}',
  });
}

Map<String, Object?> _remoteTimingPayload({
  required int id,
  required int deviceId,
  required int incomeFen,
}) {
  return {
    'payload_schema_version': 1,
    'entity_type': 'timing_record',
    'entity_id': id.toString(),
    'operation': 'update',
    'record': _remoteTimingRecord(
      id: id,
      deviceId: deviceId,
      incomeFen: incomeFen,
    ),
  };
}

Map<String, Object?> _remoteTimingRecord({
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
    'contact': '甲方',
    'site': 'alpha',
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

Map<String, Object?> _remoteTimingChange({
  required int serverSeq,
  required int entityId,
  required int baseVersion,
  required int newVersion,
  required Map<String, Object?> payload,
  bool deleted = false,
  String? originDeviceId,
}) {
  final payloadJson = jsonEncode(payload);
  return {
    'server_seq': serverSeq,
    'entity_type': 'timing_record',
    'entity_id': entityId.toString(),
    'base_version': baseVersion,
    'new_version': newVersion,
    'payload_json': payloadJson,
    'payload_hash': sha256.convert(utf8.encode(payloadJson)).toString(),
    'deleted': deleted,
    'origin_device_id': originDeviceId,
  };
}

ApiResponse _pullResponse(
  List<Map<String, Object?>> changes, {
  required int nextCursor,
}) {
  return ApiResponse(
    statusCode: 200,
    bodyJson: jsonEncode({'changes': changes, 'next_cursor': nextCursor}),
  );
}
