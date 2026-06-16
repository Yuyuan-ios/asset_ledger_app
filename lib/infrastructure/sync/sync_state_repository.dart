import 'package:sqflite/sqflite.dart';

import '../../data/db/database.dart';

/// sync_state 的最小读写 helper。
///
/// 设计纪律：
/// - push gate 与 pull cursor 都保持为独立 scope；不引入复杂状态机。
/// - 所有写方法都暴露 *WithExecutor 版本，使 restore reconcile 等业务事务可以把
///   "清 sync_outbox / 清 entity_sync_meta / 写 gate=restore-pending" 三个动作放在
///   同一个 [AppDatabase.inTransaction] 里整体提交或整体回滚。
/// - 非事务入口仅用于读 + 测试辅助 / 手工清除；生产 push 路径只读 [isPushGated]。
abstract class SyncStateRepository {
  /// 读取当前 push gate 状态。null 表示未设置（可以推送）。
  Future<String?> readPushGate();

  /// 等价于 `(await readPushGate()) != null`。
  Future<bool> isPushGated();

  /// 读取 Track B pull 游标(last_applied_server_seq)。没有 row 时返回 0。
  Future<int> readPullCursor();

  /// 在调用方事务内写入 pull 游标。只允许非负 server_seq。
  Future<void> writePullCursorWithExecutor(
    DatabaseExecutor executor,
    int cursor, {
    DateTime? now,
  });

  /// 非事务入口：等价于在新事务里调用 [writePullCursorWithExecutor]。
  Future<void> writePullCursor(int cursor, {DateTime? now});

  /// 在调用方事务内把 push gate 设为 [SyncStateRepository.gateRestorePending]。
  Future<void> markPushGateRestorePendingWithExecutor(
    DatabaseExecutor executor, {
    DateTime? now,
  });

  /// 在调用方事务内清除 push gate（用于 reconcile 完成或测试）。
  Future<void> clearPushGateWithExecutor(
    DatabaseExecutor executor, {
    DateTime? now,
  });

  /// 非事务入口：等价于在新事务里调用
  /// [clearPushGateWithExecutor]。供测试与手工解除使用；生产 reconcile
  /// 流程应嵌入到 reconcile 自己的事务里。
  Future<void> clearPushGate({DateTime? now});

  static const String kPushGateScope = 'push_gate';
  static const String kPullCursorScope = 'pull_cursor';
  static const String gateRestorePending = 'restore-pending';
}

class LocalSyncStateRepository implements SyncStateRepository {
  const LocalSyncStateRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  static const String _table = 'sync_state';

  @override
  Future<String?> readPushGate() async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      _table,
      columns: const ['gate_state'],
      where: 'scope = ?',
      whereArgs: const [SyncStateRepository.kPushGateScope],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.single['gate_state'];
    if (value is! String) return null;
    return value.isEmpty ? null : value;
  }

  @override
  Future<bool> isPushGated() async => (await readPushGate()) != null;

  @override
  Future<int> readPullCursor() async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      _table,
      columns: const ['pull_cursor'],
      where: 'scope = ?',
      whereArgs: const [SyncStateRepository.kPullCursorScope],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    final value = rows.single['pull_cursor'];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Future<void> writePullCursorWithExecutor(
    DatabaseExecutor executor,
    int cursor, {
    DateTime? now,
  }) async {
    if (cursor < 0) {
      throw ArgumentError.value(cursor, 'cursor', 'must be non-negative');
    }
    final ts = (now ?? _now()).toUtc().toIso8601String();
    await executor.insert(_table, {
      'scope': SyncStateRepository.kPullCursorScope,
      'pull_cursor': cursor,
      'updated_at': ts,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> writePullCursor(int cursor, {DateTime? now}) async {
    await AppDatabase.inTransaction<void>(
      (txn) => writePullCursorWithExecutor(txn, cursor, now: now),
    );
  }

  @override
  Future<void> markPushGateRestorePendingWithExecutor(
    DatabaseExecutor executor, {
    DateTime? now,
  }) async {
    final ts = (now ?? _now()).toUtc().toIso8601String();
    await executor.insert(_table, {
      'scope': SyncStateRepository.kPushGateScope,
      'gate_state': SyncStateRepository.gateRestorePending,
      'updated_at': ts,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clearPushGateWithExecutor(
    DatabaseExecutor executor, {
    DateTime? now,
  }) async {
    final ts = (now ?? _now()).toUtc().toIso8601String();
    final updated = await executor.update(
      _table,
      {'gate_state': null, 'updated_at': ts},
      where: 'scope = ?',
      whereArgs: const [SyncStateRepository.kPushGateScope],
    );
    if (updated == 0) {
      // 没有 row → 视为已经无 gate；不需要插入空状态行。
      return;
    }
  }

  @override
  Future<void> clearPushGate({DateTime? now}) async {
    await AppDatabase.inTransaction<void>(
      (txn) => clearPushGateWithExecutor(txn, now: now),
    );
  }
}
