import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:asset_ledger/infrastructure/sync/sync_manager.dart';
import 'package:asset_ledger/infrastructure/sync/sync_live_readiness_gate.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_state_repository.dart';
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

  test('pushPending throws SyncPushBlockedException when push gate is set; '
      'does not list pending rows or call CloudApiClient', () async {
    const outbox = LocalSyncOutboxRepository();
    await outbox.enqueue(
      entityType: 'timing_record',
      entityId: 'gated-1',
      operation: 'create',
      payload: const {'amount_fen': 1},
    );

    // 1) 显式打开 push gate（模拟刚 restore 完成）。
    const gateRepo = LocalSyncStateRepository();
    await AppDatabase.inTransaction<void>(
      (txn) => gateRepo.markPushGateRestorePendingWithExecutor(txn),
    );

    final spyClient = _SpyCloudApiClient();
    final manager = SyncManager(
      outboxRepository: outbox,
      apiClient: spyClient,
      syncStateRepository: gateRepo,
      liveReadinessGate: const StaticSyncLiveReadinessGate.readyForTest(),
    );

    // 2) pushPending 必须立即抛 SyncPushBlockedException，且不读取 pending、
    //    不调用 CloudApiClient、不动 pending row。
    await expectLater(
      manager.pushPending(),
      throwsA(
        isA<SyncPushBlockedException>().having(
          (e) => e.reason,
          'reason',
          SyncStateRepository.gateRestorePending,
        ),
      ),
    );
    expect(
      spyClient.sendCallCount,
      0,
      reason: 'CloudApiClient must not be called when gated',
    );

    // 3) pending row 仍在；没有被 mark synced / delete / retry bump。
    final db = await AppDatabase.database;
    final after = await db.query('sync_outbox');
    expect(after.length, 1);
    expect(after.single['status'], 'pending');
    expect(after.single['retry_count'], 0);

    // 4) 清除 gate 之后，pushPending 不再被 gate 阻断（行为细节本轮不验证）。
    await AppDatabase.inTransaction<void>(
      (txn) => gateRepo.clearPushGateWithExecutor(txn),
    );
    expect(await gateRepo.isPushGated(), isFalse);

    // 再调一次：不应抛 SyncPushBlockedException；CloudApiClient 至少被调用一次
    // （此处用 _SpyCloudApiClient：返回 204 → isSuccess=true → ack 删除），
    // 关键断言是「不再被 gate 拦截」。
    final result = await manager.pushPending();
    expect(result, isA<SyncPushResult>());
    expect(result.pushed, 1, reason: '204 from spy is success → row acked');
    expect(
      spyClient.sendCallCount,
      greaterThanOrEqualTo(1),
      reason: 'after clearing gate the push path must reach CloudApiClient',
    );
  });

  test('isPushGated returns false on a fresh database', () async {
    const gateRepo = LocalSyncStateRepository();
    expect(await gateRepo.isPushGated(), isFalse);
    expect(await gateRepo.readPushGate(), isNull);
  });

  test(
    'mark/clear push gate round-trip through the repository helper',
    () async {
      const gateRepo = LocalSyncStateRepository();
      await AppDatabase.inTransaction<void>(
        (txn) => gateRepo.markPushGateRestorePendingWithExecutor(txn),
      );
      expect(
        await gateRepo.readPushGate(),
        SyncStateRepository.gateRestorePending,
      );
      await gateRepo.clearPushGate();
      expect(await gateRepo.readPushGate(), isNull);
    },
  );
}

class _SpyCloudApiClient implements CloudApiClient {
  int sendCallCount = 0;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    sendCallCount += 1;
    return const ApiResponse(statusCode: 204);
  }
}
