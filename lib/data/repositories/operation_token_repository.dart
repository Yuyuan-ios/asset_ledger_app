import 'package:sqflite/sqflite.dart';

import '../../core/operations/operation_actor_type.dart';
import '../../core/operations/operation_confirmation_token.dart';
import '../db/database.dart';
import '../models/operation_token_record.dart';

/// 阶段 D Step 47：operation_tokens repository。
///
/// 状态机不变量在 SQL 层强制：
/// - **无 delete**：终态（consumed/cancelled/expired）保留，不物理删除。
/// - **无 replace**：insert 用 [ConflictAlgorithm.abort]，重复 id 抛错，不静默覆盖。
/// - 状态迁移用**带守卫的条件 UPDATE**（`WHERE ... status='issued' ...`）+ 受影响
///   行数判定，杜绝二次消费 / 过期消费 / 跨状态迁移。token_json 随状态整体重写，
///   与列保持一致。
///
/// 本类不接 PreviewService / ConfirmAdapter / Command / MCP / UI / outbox / audit。
abstract class OperationTokenRepository {
  Future<void> insert(OperationTokenRecord record);
  Future<void> insertWithExecutor(
    DatabaseExecutor executor,
    OperationTokenRecord record,
  );

  Future<OperationTokenRecord?> findById(String id);
  Future<OperationTokenRecord?> findByIdWithExecutor(
    DatabaseExecutor executor,
    String id,
  );

  Future<List<OperationTokenRecord>> listByOperationId(String operationId);

  /// 仅返回 issued 且未过期、且 actor/session 匹配的票。
  Future<List<OperationTokenRecord>> listActiveByActorSession({
    required OperationActorType actorType,
    String? actorId,
    String? sessionId,
    required DateTime now,
    int limit = 50,
  });

  /// 原子认领消费：仅当票仍 issued 且未过期时成功，置为 consumed。
  Future<bool> claimForConsume({required String id, required DateTime now});

  /// 事务内认领消费（与业务写入 + audit 同事务，rollback 时一起回滚）。
  Future<bool> claimForConsumeWithExecutor(
    DatabaseExecutor executor, {
    required String id,
    required DateTime now,
  });

  /// 仅 issued -> cancelled。
  Future<bool> markCancelled({
    required String id,
    required DateTime cancelledAt,
    String? reason,
  });

  /// 把所有 issued 且 expires_at <= now 的票落为 expired，返回受影响行数。
  Future<int> markExpiredBefore(DateTime now);
}

class SqfliteOperationTokenRepository implements OperationTokenRepository {
  static const String table = 'operation_tokens';

  @override
  Future<void> insert(OperationTokenRecord record) async {
    final db = await AppDatabase.database;
    await insertWithExecutor(db, record);
  }

  @override
  Future<void> insertWithExecutor(
    DatabaseExecutor executor,
    OperationTokenRecord record,
  ) async {
    _requireNonEmpty(record.id, 'id');
    _requireNonEmpty(record.operationId, 'operationId');
    await executor.insert(
      table,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<OperationTokenRecord?> findById(String id) async {
    final db = await AppDatabase.database;
    return findByIdWithExecutor(db, id);
  }

  @override
  Future<OperationTokenRecord?> findByIdWithExecutor(
    DatabaseExecutor executor,
    String id,
  ) async {
    final normalizedId = _requireNonEmpty(id, 'id');
    final rows = await executor.query(
      table,
      where: 'id = ?',
      whereArgs: [normalizedId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OperationTokenRecord.fromMap(rows.single);
  }

  @override
  Future<List<OperationTokenRecord>> listByOperationId(
    String operationId,
  ) async {
    final normalized = _requireNonEmpty(operationId, 'operationId');
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      where: 'operation_id = ?',
      whereArgs: [normalized],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(OperationTokenRecord.fromMap).toList(growable: false);
  }

  @override
  Future<List<OperationTokenRecord>> listActiveByActorSession({
    required OperationActorType actorType,
    String? actorId,
    String? sessionId,
    required DateTime now,
    int limit = 50,
  }) async {
    if (limit <= 0) return const [];
    final db = await AppDatabase.database;
    final where = StringBuffer(
      "status = 'issued' AND expires_at > ? AND actor_type = ?",
    );
    final args = <Object?>[now.toUtc().toIso8601String(), actorType.wireName];

    if (actorId == null) {
      where.write(' AND actor_id IS NULL');
    } else {
      where.write(' AND actor_id = ?');
      args.add(actorId);
    }
    if (sessionId == null) {
      where.write(' AND session_id IS NULL');
    } else {
      where.write(' AND session_id = ?');
      args.add(sessionId);
    }

    final rows = await db.query(
      table,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(OperationTokenRecord.fromMap).toList(growable: false);
  }

  @override
  Future<bool> claimForConsume({
    required String id,
    required DateTime now,
  }) async {
    final db = await AppDatabase.database;
    return db.transaction((txn) => _claim(txn, id: id, now: now));
  }

  @override
  Future<bool> claimForConsumeWithExecutor(
    DatabaseExecutor executor, {
    required String id,
    required DateTime now,
  }) {
    return _claim(executor, id: id, now: now);
  }

  /// 守卫式认领：读出当前票 → 仅当 issued 且未过期 → 以
  /// `WHERE status='issued' AND expires_at > now` 的条件 UPDATE 置为 consumed。
  /// 受影响行数 != 1 视为认领失败（已被消费 / 过期 / 取消）。
  Future<bool> _claim(
    DatabaseExecutor executor, {
    required String id,
    required DateTime now,
  }) async {
    final normalizedId = _requireNonEmpty(id, 'id');
    final existing = await findByIdWithExecutor(executor, normalizedId);
    if (existing == null) return false;
    if (existing.status != OperationConfirmationTokenStatus.issued) {
      return false;
    }
    if (!existing.expiresAt.isAfter(now)) return false;

    final consumed = existing.asConsumed(now);
    final affected = await executor.update(
      table,
      consumed.toMap(),
      where: "id = ? AND status = 'issued' AND expires_at > ?",
      whereArgs: [normalizedId, now.toUtc().toIso8601String()],
    );
    return affected == 1;
  }

  @override
  Future<bool> markCancelled({
    required String id,
    required DateTime cancelledAt,
    String? reason,
  }) async {
    final normalizedId = _requireNonEmpty(id, 'id');
    final db = await AppDatabase.database;
    return db.transaction((txn) async {
      final existing = await findByIdWithExecutor(txn, normalizedId);
      if (existing == null) return false;
      if (existing.status != OperationConfirmationTokenStatus.issued) {
        return false;
      }
      final cancelled = existing.asCancelled(cancelledAt, reason: reason);
      final affected = await txn.update(
        table,
        cancelled.toMap(),
        where: "id = ? AND status = 'issued'",
        whereArgs: [normalizedId],
      );
      return affected == 1;
    });
  }

  @override
  Future<int> markExpiredBefore(DateTime now) async {
    final db = await AppDatabase.database;
    final cutoff = now.toUtc().toIso8601String();
    return db.transaction((txn) async {
      final rows = await txn.query(
        table,
        where: "status = 'issued' AND expires_at <= ?",
        whereArgs: [cutoff],
      );
      var expiredCount = 0;
      for (final row in rows) {
        final record = OperationTokenRecord.fromMap(row);
        final expired = record.asExpired();
        final affected = await txn.update(
          table,
          expired.toMap(),
          where: "id = ? AND status = 'issued'",
          whereArgs: [record.id],
        );
        expiredCount += affected;
      }
      return expiredCount;
    });
  }

  static String _requireNonEmpty(String value, String name) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, name, '$name must not be empty');
    }
    return trimmed;
  }
}
