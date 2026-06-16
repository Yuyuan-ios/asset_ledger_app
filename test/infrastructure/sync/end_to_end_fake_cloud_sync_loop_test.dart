import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/infrastructure/local/account/local_account_payment_write_use_case.dart';
import 'package:asset_ledger/infrastructure/sync/sync_live_readiness_gate.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
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
  SyncManager managerWith(FakeCloudApiClient client) {
    return SyncManager(
      outboxRepository: LocalSyncOutboxRepository(now: () => fixedNow),
      apiClient: client,
      syncStateRepository: const LocalSyncStateRepository(),
      metaRepository: const LocalEntitySyncMetaRepository(),
      liveReadinessGate: const StaticSyncLiveReadinessGate.readyForTest(),
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
}
