import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/operation_audit_log.dart';

/// 阶段 D Step 3：本地 operation audit log repository。
///
/// **append-only 不变量**：刻意不暴露 update / delete / clearAllForRestore。
/// duplicate id 在 SQLite 层由 PRIMARY KEY + [ConflictAlgorithm.abort] 阻断，
/// 不允许 silent replace。`*WithExecutor` 变体用于与业务写操作同事务，
/// 让 audit 与业务一起 commit / rollback。
///
/// 本类**不**接任何业务 use case / outbox / sync / UI。
abstract class OperationAuditLogRepository {
  Future<void> insert(OperationAuditLog log);

  /// 事务内插入：rollback 时审计随之回滚，保证"操作发生过"与业务状态一致。
  Future<void> insertWithExecutor(
    DatabaseExecutor executor,
    OperationAuditLog log,
  );

  Future<OperationAuditLog?> findById(String id);

  Future<List<OperationAuditLog>> listByOperationId(String operationId);

  Future<List<OperationAuditLog>> listRecent({int limit = 50});
}

class SqfliteOperationAuditLogRepository
    implements OperationAuditLogRepository {
  static const String table = 'operation_audit_logs';

  @override
  Future<void> insert(OperationAuditLog log) async {
    final db = await AppDatabase.database;
    await insertWithExecutor(db, log);
  }

  @override
  Future<void> insertWithExecutor(
    DatabaseExecutor executor,
    OperationAuditLog log,
  ) async {
    _validate(log);
    await executor.insert(
      table,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<OperationAuditLog?> findById(String id) async {
    final normalizedId = _requireNonEmpty(id, 'id');
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [normalizedId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OperationAuditLog.fromMap(rows.single);
  }

  @override
  Future<List<OperationAuditLog>> listByOperationId(String operationId) async {
    final normalizedOperationId = _requireNonEmpty(operationId, 'operationId');
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      where: 'operation_id = ?',
      whereArgs: [normalizedOperationId],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(OperationAuditLog.fromMap).toList(growable: false);
  }

  @override
  Future<List<OperationAuditLog>> listRecent({int limit = 50}) async {
    if (limit <= 0) return const [];
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(OperationAuditLog.fromMap).toList(growable: false);
  }

  static void _validate(OperationAuditLog log) {
    _requireNonEmpty(log.id, 'id');
    _requireNonEmpty(log.operationId, 'operationId');
  }

  static String _requireNonEmpty(String value, String name) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, name, '$name 不能为空');
    }
    return trimmed;
  }
}
