import 'dart:convert';

import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/repositories/account_payment_repository.dart';
import 'package:asset_ledger/features/account/use_cases/delete_merged_payment_batch_use_case.dart';
import 'package:asset_ledger/infrastructure/local/account/local_account_payment_write_use_case.dart';
import 'package:asset_ledger/infrastructure/sync/sync_outbox_entry.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:asset_ledger/infrastructure/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../../test_setup.dart';

/// R5.6 — 合并批次收款多行写入同事务入队 sync_outbox + entity_sync_meta。
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

  group('createBatch', () {
    test('插入 N 条 + N 条 create/pendingUpload，payload 携带 merge 字段', () async {
      final db = await AppDatabase.database;
      final rows = _batchRows(batchId: 'merge-1', amounts: const [300, 200]);

      final saved = await _useCase().createBatch(rows);

      expect(saved, hasLength(2));
      expect(saved.every((p) => p.id != null), isTrue);
      expect(await db.query('account_payments'), hasLength(2));

      final outbox = await db.query('sync_outbox', orderBy: 'id ASC');
      expect(outbox, hasLength(2));
      expect(outbox.every((r) => r['operation'] == 'create'), isTrue);
      expect(outbox.every((r) => r['status'] == SyncOutboxStatus.pending.name),
          isTrue);
      // outbox id 互异（R5.5 批量安全）。
      expect(outbox.map((r) => r['id']).toSet(), hasLength(2));
      final payload0 =
          jsonDecode(outbox.first['payload_json'] as String)
              as Map<String, Object?>;
      final record0 = payload0['record'] as Map<String, Object?>;
      expect(record0['merge_batch_id'], 'merge-1');
      expect(record0['amount_fen'], anyOf(30000, 20000));

      final meta = await db.query('entity_sync_meta');
      expect(meta, hasLength(2));
      expect(
        meta.every((r) => r['sync_status'] == SyncStatus.pendingUpload.name),
        isTrue,
      );
      // 每条 meta.payload_hash 对应一条 outbox.payload_hash。
      final outboxHashes = outbox.map((r) => r['payload_hash']).toSet();
      final metaHashes = meta.map((r) => r['payload_hash']).toSet();
      expect(metaHashes, outboxHashes);
    });

    test('outbox 写失败 → 整批回滚，account_payments/outbox/meta 全空', () async {
      final db = await AppDatabase.database;
      final useCase = LocalAccountPaymentWriteUseCase(
        paymentRepository: SqfliteAccountPaymentRepository(),
        syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
      );

      await expectLater(
        useCase.createBatch(_batchRows(batchId: 'merge-1', amounts: const [300, 200])),
        throwsA(isA<StateError>()),
      );

      expect(await db.query('account_payments'), isEmpty);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });
  });

  group('deleteBatch', () {
    test('删除 N 条 + N 条 delete/pendingDelete（用快照）', () async {
      final db = await AppDatabase.database;
      await _useCase().createBatch(
        _batchRows(batchId: 'merge-1', amounts: const [300, 200]),
      );
      // 清掉 create 阶段产生的 outbox/meta，隔离 delete 断言。
      await db.delete('sync_outbox');
      await db.delete('entity_sync_meta');

      final deleted = await _useCase().deleteBatch('merge-1');

      expect(deleted, 2);
      expect(await db.query('account_payments'), isEmpty);

      final outbox = await db.query('sync_outbox');
      expect(outbox, hasLength(2));
      expect(outbox.every((r) => r['operation'] == 'delete'), isTrue);
      final payload =
          jsonDecode(outbox.first['payload_json'] as String)
              as Map<String, Object?>;
      final record = payload['record'] as Map<String, Object?>;
      expect(record['merge_batch_id'], 'merge-1');
      expect(record['project_id'], isNotNull);

      final meta = await db.query('entity_sync_meta');
      expect(
        meta.every((r) => r['sync_status'] == SyncStatus.pendingDelete.name),
        isTrue,
      );
    });

    test('空批次 → 幂等 0，不入队', () async {
      final db = await AppDatabase.database;
      final deleted = await _useCase().deleteBatch('nope');
      expect(deleted, 0);
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });

    test('outbox 写失败 → 删除整体回滚，原行仍在', () async {
      final db = await AppDatabase.database;
      await _useCase().createBatch(
        _batchRows(batchId: 'merge-1', amounts: const [300, 200]),
      );
      await db.delete('sync_outbox');
      await db.delete('entity_sync_meta');

      final failing = LocalAccountPaymentWriteUseCase(
        paymentRepository: SqfliteAccountPaymentRepository(),
        syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
      );
      await expectLater(
        failing.deleteBatch('merge-1'),
        throwsA(isA<StateError>()),
      );

      expect(await db.query('account_payments'), hasLength(2));
      expect(await db.query('sync_outbox'), isEmpty);
      expect(await db.query('entity_sync_meta'), isEmpty);
    });
  });

  group('features 路由：DeleteMergedPaymentBatchUseCase 经 writeUseCase 入队', () {
    test('注入 writeUseCase 时，删除批次写 delete outbox', () async {
      final db = await AppDatabase.database;
      final writeUseCase = _useCase();
      await writeUseCase.createBatch(
        _batchRows(batchId: 'merge-1', amounts: const [300, 200]),
      );
      await db.delete('sync_outbox');
      await db.delete('entity_sync_meta');

      final deleted = await DeleteMergedPaymentBatchUseCase(
        repository: SqfliteAccountPaymentRepository(),
        writeUseCase: writeUseCase,
      ).execute(mergeBatchId: 'merge-1');

      expect(deleted, 2);
      final outbox = await db.query('sync_outbox');
      expect(outbox, hasLength(2));
      expect(outbox.every((r) => r['operation'] == 'delete'), isTrue);
    });
  });

  group('replaceBatch（delete old + insert new 语义）', () {
    test('旧 N 条 delete/pendingDelete + 新 M 条 create/pendingUpload', () async {
      final db = await AppDatabase.database;
      await _useCase().createBatch(
        _batchRows(batchId: 'merge-1', amounts: const [300, 200]),
      );
      await db.delete('sync_outbox');
      await db.delete('entity_sync_meta');

      final saved = await _useCase().replaceBatch(
        batchId: 'merge-1',
        newRows: _batchRows(
          batchId: 'merge-1',
          amounts: const [250, 250],
          total: 500,
        ),
      );

      expect(saved, hasLength(2));
      // 旧 2 条删除、新 2 条插入 → 表里仍 2 条。
      expect(await db.query('account_payments'), hasLength(2));

      final outbox = await db.query('sync_outbox');
      final ops = outbox.map((r) => r['operation']).toList();
      expect(ops.where((o) => o == 'delete').length, 2);
      expect(ops.where((o) => o == 'create').length, 2);
      expect(outbox, hasLength(4));
      // 4 条 outbox id 互异（同事务批量安全）。
      expect(outbox.map((r) => r['id']).toSet(), hasLength(4));
    });

    test('outbox 写失败 → 替换整体回滚，旧行保持原状', () async {
      final db = await AppDatabase.database;
      await _useCase().createBatch(
        _batchRows(batchId: 'merge-1', amounts: const [300, 200]),
      );
      final before = await db.query('account_payments', orderBy: 'id ASC');
      await db.delete('sync_outbox');
      await db.delete('entity_sync_meta');

      final failing = LocalAccountPaymentWriteUseCase(
        paymentRepository: SqfliteAccountPaymentRepository(),
        syncOutboxRepository: const _ThrowingSyncOutboxRepository(),
      );
      await expectLater(
        failing.replaceBatch(
          batchId: 'merge-1',
          newRows: _batchRows(
            batchId: 'merge-1',
            amounts: const [250, 250],
            total: 500,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final after = await db.query('account_payments', orderBy: 'id ASC');
      expect(after, hasLength(2));
      expect(after.map((r) => r['amount_fen']).toList(),
          before.map((r) => r['amount_fen']).toList());
      expect(await db.query('sync_outbox'), isEmpty);
    });
  });
}

LocalAccountPaymentWriteUseCase _useCase() {
  return LocalAccountPaymentWriteUseCase(
    paymentRepository: SqfliteAccountPaymentRepository(),
  );
}

/// 构造一个合并批次的分摊行（合法：同批次、同总额、source=merge_allocation）。
List<AccountPayment> _batchRows({
  required String batchId,
  required List<int> amounts,
  int? total,
}) {
  final batchTotal = (total ?? amounts.fold<int>(0, (s, a) => s + a)).toDouble();
  return [
    for (var i = 0; i < amounts.length; i += 1)
      AccountPayment(
        projectId: 'project:$i',
        projectKey: ProjectKey.buildKey(contact: '甲方', site: '工地$i'),
        ymd: 20260601,
        amount: amounts[i].toDouble(),
        sourceType: AccountPayment.sourceTypeMergeAllocation,
        mergeGroupId: 1,
        mergeBatchId: batchId,
        mergeBatchTotalAmount: batchTotal,
        createdAt: '2026-06-01T00:00:00.000Z',
      ),
  ];
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
