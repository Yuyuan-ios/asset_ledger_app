import 'package:asset_ledger/data/db/database.dart';
import 'package:asset_ledger/data/db/db_schema.dart';
import 'package:asset_ledger/infrastructure/sync/outbox_id_generator.dart';
import 'package:asset_ledger/infrastructure/sync/sync_repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_setup.dart';

/// R5.5 — sync_outbox id 生成器硬化：批量安全、事务安全、可注入确定性序列。
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

  group('SecureRandomOutboxIdGenerator（生产默认）', () {
    test('生成非空、outbox- 前缀，且 100 次无重复', () {
      final generator = SecureRandomOutboxIdGenerator();
      final ids = <String>{};
      for (var i = 0; i < 100; i += 1) {
        final id = generator.generate();
        expect(id, isNotEmpty);
        expect(id, startsWith('outbox-'));
        ids.add(id);
      }
      // 不依赖真实时间精度，纯随机 → 100 次全唯一。
      expect(ids, hasLength(100));
    });
  });

  group('SequenceOutboxIdGenerator（测试确定性）', () {
    test('返回 outbox-test-1 / -2 / -3 …', () {
      final generator = SequenceOutboxIdGenerator();
      expect(generator.generate(), 'outbox-test-1');
      expect(generator.generate(), 'outbox-test-2');
      expect(generator.generate(), 'outbox-test-3');
    });
  });

  group('LocalSyncOutboxRepository 接入 id 生成器', () {
    test('连续 enqueue 多条使用注入的确定性序列', () async {
      final repo = LocalSyncOutboxRepository(
        idGenerator: SequenceOutboxIdGenerator(),
      );
      for (var i = 0; i < 3; i += 1) {
        await repo.enqueue(
          entityType: 'account_payment',
          entityId: 'p$i',
          operation: 'create',
          payload: {'i': i},
        );
      }
      final pending = await repo.listPending();
      expect(
        pending.map((entry) => entry.id).toList(),
        ['outbox-test-1', 'outbox-test-2', 'outbox-test-3'],
      );
    });

    test('同一 transaction 内连续 enqueue 多条：全部成功、id 互异、无主键碰撞', () async {
      final db = await AppDatabase.database;
      // 固定时间戳：证明即便同微秒，id 也不靠时间戳避免碰撞。
      final repo = LocalSyncOutboxRepository(
        now: () => DateTime.utc(2026, 6, 1, 12),
        idGenerator: SecureRandomOutboxIdGenerator(),
      );

      await AppDatabase.inTransaction((txn) async {
        for (var i = 0; i < 5; i += 1) {
          await repo.enqueueWithExecutor(
            txn,
            entityType: 'account_payment',
            entityId: 'p$i',
            operation: 'create',
            payload: {'i': i},
          );
        }
      });

      final rows = await db.query('sync_outbox');
      expect(rows, hasLength(5));
      final ids = rows.map((row) => row['id'] as String).toSet();
      expect(ids, hasLength(5), reason: '5 条 id 必须互不相同（无主键碰撞）');
      // created_at 全部相同（同微秒），证明唯一性不来自时间戳。
      final createdAts = rows.map((row) => row['created_at']).toSet();
      expect(createdAts, hasLength(1));
    });

    test('默认（不注入）也批量安全：同事务 4 条 id 互异', () async {
      final db = await AppDatabase.database;
      const repo = LocalSyncOutboxRepository(); // 走静态默认随机生成器
      await AppDatabase.inTransaction((txn) async {
        for (var i = 0; i < 4; i += 1) {
          await repo.enqueueWithExecutor(
            txn,
            entityType: 'timing_record',
            entityId: 't$i',
            operation: 'create',
            payload: {'i': i},
          );
        }
      });
      final rows = await db.query('sync_outbox');
      expect(rows, hasLength(4));
      expect(
        rows.map((row) => row['id'] as String).toSet(),
        hasLength(4),
      );
      for (final row in rows) {
        expect(row['id'] as String, startsWith('outbox-'));
      }
    });
  });
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
