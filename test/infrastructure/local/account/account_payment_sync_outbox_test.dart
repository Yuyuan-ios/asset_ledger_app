import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/infrastructure/local/account/local_account_payment_write_use_case.dart';
import 'package:asset_ledger/infrastructure/sync/entity_sync_meta.dart';
import 'package:asset_ledger/infrastructure/sync/sync_outbox_entry.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

/// R5.3 — 单条收款 create/update/delete 在同一事务内入队 sync_outbox +
/// entity_sync_meta。
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

  test('create：account_payments 落库 + create/pendingUpload 入队', () async {
    final db = await AppDatabase.database;
    final useCase = _useCase();

    final id = await useCase.create(_payment());

    expect(await db.query('account_payments'), hasLength(1));

    final outboxRows = await db.query('sync_outbox');
    expect(outboxRows, hasLength(1));
    expect(outboxRows.single['entity_type'], 'account_payment');
    expect(outboxRows.single['entity_id'], id.toString());
    expect(outboxRows.single['operation'], 'create');
    expect(outboxRows.single['status'], SyncOutboxStatus.pending.name);
    final payload =
        jsonDecode(outboxRows.single['payload_json'] as String)
            as Map<String, Object?>;
    expect(payload['operation'], 'create');
    final record = payload['record'] as Map<String, Object?>;
    expect(record['id'], id);
    expect(record['project_id'], 'project:a');
    expect(record['amount_fen'], 50000); // 500.00 元

    final metaRows = await db.query('entity_sync_meta');
    expect(metaRows, hasLength(1));
    expect(metaRows.single['entity_type'], 'account_payment');
    expect(metaRows.single['local_id'], id.toString());
    expect(metaRows.single['sync_status'], SyncStatus.pendingUpload.name);
    expect(metaRows.single['source'], 'owner_app');
    expect(metaRows.single['payload_hash'], outboxRows.single['payload_hash']);
  });

  test('update：account_payments 更新 + update/pendingUpdate 入队', () async {
    final db = await AppDatabase.database;
    // 用 repository 直接插入（不入队），隔离出 update 的单条 outbox。
    final id = await SqfliteAccountPaymentRepository().insert(_payment());

    await _useCase().update(_payment(amount: 800).copyWith(id: id));

    final updated = await db.query('account_payments', where: 'id = ?', whereArgs: [id]);
    expect((updated.single['amount_fen'] as num).toInt(), 80000);

    final outboxRows = await db.query('sync_outbox');
    expect(outboxRows, hasLength(1));
    expect(outboxRows.single['operation'], 'update');
    expect(outboxRows.single['entity_id'], id.toString());
    final payload =
        jsonDecode(outboxRows.single['payload_json'] as String)
            as Map<String, Object?>;
    expect(payload['operation'], 'update');
    expect((payload['record'] as Map<String, Object?>)['amount_fen'], 80000);

    final metaRows = await db.query('entity_sync_meta');
    expect(metaRows.single['sync_status'], SyncStatus.pendingUpdate.name);
    expect(metaRows.single['payload_hash'], outboxRows.single['payload_hash']);
  });

  test('delete：删除记录 + delete/pendingDelete 入队（用重读快照）', () async {
    final db = await AppDatabase.database;
    final id = await SqfliteAccountPaymentRepository().insert(_payment());

    await _useCase().deleteById(id);

    expect(await db.query('account_payments'), isEmpty);

    final outboxRows = await db.query('sync_outbox');
    expect(outboxRows, hasLength(1));
    expect(outboxRows.single['operation'], 'delete');
    expect(outboxRows.single['entity_id'], id.toString());
    final payload =
        jsonDecode(outboxRows.single['payload_json'] as String)
            as Map<String, Object?>;
    final record = payload['record'] as Map<String, Object?>;
    expect(record['id'], id);
    expect(record['project_id'], 'project:a');
    expect(record['amount_fen'], 50000);

    final metaRows = await db.query('entity_sync_meta');
    expect(metaRows.single['sync_status'], SyncStatus.pendingDelete.name);
    expect(metaRows.single['payload_hash'], outboxRows.single['payload_hash']);
  });

  test('delete 未命中：幂等空操作，不入队', () async {
    final db = await AppDatabase.database;
    await _useCase().deleteById(99999);
    expect(await db.query('sync_outbox'), isEmpty);
    expect(await db.query('entity_sync_meta'), isEmpty);
  });

  test('update 不存在记录：抛错且不入队', () async {
    final db = await AppDatabase.database;
    await expectLater(
      _useCase().update(_payment().copyWith(id: 99999)),
      throwsA(isA<StateError>()),
    );
    expect(await db.query('account_payments'), isEmpty);
    expect(await db.query('sync_outbox'), isEmpty);
    expect(await db.query('entity_sync_meta'), isEmpty);
  });

  test('outbox 写失败：create 整体回滚，不留半条', () async {
    final db = await AppDatabase.database;
    final useCase = LocalAccountPaymentWriteUseCase(
      paymentRepository: SqfliteAccountPaymentRepository(),
      syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
    );

    await expectLater(useCase.create(_payment()), throwsA(isA<StateError>()));

    expect(await db.query('account_payments'), isEmpty);
    expect(await db.query('sync_outbox'), isEmpty);
    expect(await db.query('entity_sync_meta'), isEmpty);
  });

  test('meta 写失败：create 整体回滚，outbox 不留半条', () async {
    final db = await AppDatabase.database;
    final useCase = LocalAccountPaymentWriteUseCase(
      paymentRepository: SqfliteAccountPaymentRepository(),
      entitySyncMetaRepository: const _ThrowingEntitySyncMetaRepository(),
    );

    await expectLater(useCase.create(_payment()), throwsA(isA<StateError>()));

    expect(await db.query('account_payments'), isEmpty);
    expect(await db.query('sync_outbox'), isEmpty);
    expect(await db.query('entity_sync_meta'), isEmpty);
  });
}

LocalAccountPaymentWriteUseCase _useCase() {
  return LocalAccountPaymentWriteUseCase(
    paymentRepository: SqfliteAccountPaymentRepository(),
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

class _ThrowingSyncOutboxRepository implements SyncOutboxRepository {
  const _ThrowingSyncOutboxRepository();

  @override
  Future<SyncOutboxEntry> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    throw StateError('注入的失败：sync_outbox 写入失败');
  }

  @override
  Future<SyncOutboxEntry> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    throw StateError('注入的失败：sync_outbox 写入失败');
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
    throw StateError('注入的失败：entity_sync_meta 写入失败');
  }

  @override
  Future<void> upsertWithExecutor(DatabaseExecutor executor, EntitySyncMeta meta) {
    throw StateError('注入的失败：entity_sync_meta 写入失败');
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
