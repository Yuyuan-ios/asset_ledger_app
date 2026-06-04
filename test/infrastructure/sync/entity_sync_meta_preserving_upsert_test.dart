import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/infrastructure/local/account/local_account_payment_write_use_case.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.4 — entity_sync_meta 保留式 upsert（repo 层硬化）。
///
/// 本地 save/delete/payment 的 pending 标记不得抹掉云端 pull 回填的
/// server_id / version。逻辑收口在 [LocalEntitySyncMetaRepository]，三条业务
/// 路径自动受益。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureTestDatabase();

  const repository = LocalEntitySyncMetaRepository();

  setUp(() async {
    await AppDatabase.resetForTest();
    await _openCurrentInMemoryDb();
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  group('repo 层合并规则', () {
    test('行不存在时按 incoming 插入', () async {
      await repository.upsert(
        _meta(syncStatus: SyncStatus.pendingUpload, payloadHash: 'h1'),
      );

      final saved = await repository.find(
        entityType: 'timing_record',
        localId: '1',
      );
      expect(saved, isNotNull);
      expect(saved!.syncStatus, SyncStatus.pendingUpload);
      expect(saved.payloadHash, 'h1');
      expect(saved.source, 'owner_app');
      expect(saved.version, 0);
      expect(saved.serverId, isNull);
    });

    test('pendingUpdate 不得抹掉已回填的 server_id / version', () async {
      await repository.upsert(
        _meta(
          serverId: 'srv-123',
          version: 7,
          syncStatus: SyncStatus.synced,
          payloadHash: 'h-old',
          lastSyncedAt: '2026-06-01T00:00:00.000Z',
        ),
      );

      await repository.upsert(
        _meta(
          serverId: null,
          version: 0,
          syncStatus: SyncStatus.pendingUpdate,
          payloadHash: 'h-new',
        ),
      );

      final saved = await repository.find(
        entityType: 'timing_record',
        localId: '1',
      );
      expect(saved!.serverId, 'srv-123'); // 保留
      expect(saved.version, 7); // 保留
      expect(saved.syncStatus, SyncStatus.pendingUpdate); // 覆盖
      expect(saved.payloadHash, 'h-new'); // 覆盖
      expect(saved.lastSyncedAt, '2026-06-01T00:00:00.000Z'); // 保留
    });

    test('pendingDelete 不得抹掉已回填的 server_id / version', () async {
      await repository.upsert(
        _meta(serverId: 'srv-123', version: 7, syncStatus: SyncStatus.synced),
      );

      await repository.upsert(
        _meta(
          serverId: null,
          version: 0,
          syncStatus: SyncStatus.pendingDelete,
          payloadHash: 'h-del',
        ),
      );

      final saved = await repository.find(
        entityType: 'timing_record',
        localId: '1',
      );
      expect(saved!.serverId, 'srv-123');
      expect(saved.version, 7);
      expect(saved.syncStatus, SyncStatus.pendingDelete);
      expect(saved.payloadHash, 'h-del');
    });

    test('incoming.version 更低时保留既有 version', () async {
      await repository.upsert(_meta(version: 7, syncStatus: SyncStatus.synced));
      await repository.upsert(
        _meta(version: 0, syncStatus: SyncStatus.pendingUpdate),
      );

      final saved = await repository.find(
        entityType: 'timing_record',
        localId: '1',
      );
      expect(saved!.version, 7);
    });

    test('incoming.version 更高时上调（云端 pull 规则）', () async {
      await repository.upsert(_meta(version: 3, syncStatus: SyncStatus.synced));
      await repository.upsert(
        _meta(version: 9, syncStatus: SyncStatus.synced, serverId: 'srv-9'),
      );

      final saved = await repository.find(
        entityType: 'timing_record',
        localId: '1',
      );
      expect(saved!.version, 9);
      expect(saved.serverId, 'srv-9');
    });

    test('source 为实体来源，本地编辑不改变 → 保留既有', () async {
      await repository.upsert(
        _meta(source: 'cloud', serverId: 'srv-1', syncStatus: SyncStatus.synced),
      );
      await repository.upsert(
        _meta(source: 'owner_app', syncStatus: SyncStatus.pendingUpdate),
      );

      final saved = await repository.find(
        entityType: 'timing_record',
        localId: '1',
      );
      expect(saved!.source, 'cloud');
    });

    test('conflict_reason / last_synced_at 不被本地 pending 清空', () async {
      await repository.upsert(
        _meta(
          serverId: 'srv-1',
          syncStatus: SyncStatus.conflict,
          conflictReason: 'version_mismatch',
          lastSyncedAt: '2026-06-02T00:00:00.000Z',
        ),
      );
      await repository.upsert(
        _meta(syncStatus: SyncStatus.pendingUpdate, payloadHash: 'h2'),
      );

      final saved = await repository.find(
        entityType: 'timing_record',
        localId: '1',
      );
      expect(saved!.conflictReason, 'version_mismatch');
      expect(saved.lastSyncedAt, '2026-06-02T00:00:00.000Z');
    });
  });

  group('端到端：AccountPayment 路径保留 server_id', () {
    test('payment update：已回填 server_id 的 meta 不被抹掉', () async {
      final id = await SqfliteAccountPaymentRepository().insert(_payment());
      // 模拟云端 pull 已回填 server_id / version。
      await repository.upsert(
        EntitySyncMeta(
          entityType: 'account_payment',
          localId: id.toString(),
          serverId: 'srv-pay-1',
          syncStatus: SyncStatus.synced,
          version: 5,
          source: 'cloud',
          payloadHash: 'h-old',
        ),
      );

      await LocalAccountPaymentWriteUseCase(
        paymentRepository: SqfliteAccountPaymentRepository(),
      ).update(_payment(amount: 800).copyWith(id: id));

      final saved = await repository.find(
        entityType: 'account_payment',
        localId: id.toString(),
      );
      expect(saved!.serverId, 'srv-pay-1'); // 保留
      expect(saved.version, 5); // 保留
      expect(saved.source, 'cloud'); // 保留
      expect(saved.syncStatus, SyncStatus.pendingUpdate); // 覆盖
    });

    test('payment delete：已回填 server_id 的 meta 不被抹掉', () async {
      final id = await SqfliteAccountPaymentRepository().insert(_payment());
      await repository.upsert(
        EntitySyncMeta(
          entityType: 'account_payment',
          localId: id.toString(),
          serverId: 'srv-pay-2',
          syncStatus: SyncStatus.synced,
          version: 5,
          source: 'cloud',
          payloadHash: 'h-old',
        ),
      );

      await LocalAccountPaymentWriteUseCase(
        paymentRepository: SqfliteAccountPaymentRepository(),
      ).deleteById(id);

      final saved = await repository.find(
        entityType: 'account_payment',
        localId: id.toString(),
      );
      expect(saved!.serverId, 'srv-pay-2'); // 保留
      expect(saved.version, 5); // 保留
      expect(saved.syncStatus, SyncStatus.pendingDelete); // 覆盖
    });
  });
}

EntitySyncMeta _meta({
  String entityType = 'timing_record',
  String localId = '1',
  String? serverId,
  SyncStatus syncStatus = SyncStatus.pendingUpload,
  int version = 0,
  String source = 'owner_app',
  String? payloadHash = 'hash-1',
  String? lastSyncedAt,
  String? conflictReason,
}) {
  return EntitySyncMeta(
    entityType: entityType,
    localId: localId,
    serverId: serverId,
    syncStatus: syncStatus,
    version: version,
    source: source,
    payloadHash: payloadHash,
    lastSyncedAt: lastSyncedAt,
    conflictReason: conflictReason,
  );
}

AccountPayment _payment({double amount = 500}) {
  return AccountPayment(
    projectId: 'project:a',
    projectKey: ProjectKey.buildKey(contact: '甲方', site: '工地'),
    ymd: 20260601,
    amount: amount,
    createdAt: '2026-06-01T00:00:00.000Z',
  );
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
