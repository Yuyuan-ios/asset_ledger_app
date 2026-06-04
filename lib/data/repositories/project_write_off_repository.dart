import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/project_write_off.dart';

abstract class ProjectWriteOffRepository {
  Future<void> insert(ProjectWriteOff item);

  Future<int> update(ProjectWriteOff item);

  Future<int> deleteById(String id);

  Future<List<ProjectWriteOff>> listByProjectId(String projectId);

  Future<List<ProjectWriteOff>> listAll();

  Future<double> sumByProjectId(String projectId);

  Future<Map<String, double>> sumByProjectIds(Iterable<String> projectIds);

  Future<int> clearAllForRestore();
}

class SqfliteProjectWriteOffRepository implements ProjectWriteOffRepository {
  static const String table = 'project_write_offs';

  @override
  Future<void> insert(ProjectWriteOff item) async {
    final db = await AppDatabase.database;
    await insertWithExecutor(db, item);
  }

  Future<void> insertWithExecutor(
    DatabaseExecutor executor,
    ProjectWriteOff item,
  ) async {
    _validate(item);
    await executor.insert(
      table,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<int> update(ProjectWriteOff item) async {
    _validate(item);
    final db = await AppDatabase.database;
    return db.update(
      table,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<int> deleteById(String id) async {
    final db = await AppDatabase.database;
    return deleteByIdWithExecutor(db, id);
  }

  @override
  Future<List<ProjectWriteOff>> listByProjectId(String projectId) async {
    final db = await AppDatabase.database;
    return listByProjectIdWithExecutor(db, projectId);
  }

  Future<ProjectWriteOff?> findByIdWithExecutor(
    DatabaseExecutor executor,
    String id,
  ) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(id, 'id', '核销记录 ID 不能为空');
    }
    final rows = await executor.query(
      table,
      where: 'id = ?',
      whereArgs: [normalizedId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProjectWriteOff.fromMap(rows.single);
  }

  Future<List<ProjectWriteOff>> listByProjectIdWithExecutor(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', '项目 ID 不能为空');
    }
    final rows = await executor.query(
      table,
      where: 'project_id = ?',
      whereArgs: [normalizedProjectId],
      orderBy: 'write_off_date DESC, created_at DESC, id DESC',
    );
    return rows.map(ProjectWriteOff.fromMap).toList(growable: false);
  }

  Future<int> deleteByIdWithExecutor(
    DatabaseExecutor executor,
    String id,
  ) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(id, 'id', '核销记录 ID 不能为空');
    }
    return executor.delete(table, where: 'id = ?', whereArgs: [normalizedId]);
  }

  @override
  Future<List<ProjectWriteOff>> listAll() async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      table,
      orderBy: 'write_off_date DESC, created_at DESC, id DESC',
    );
    return rows.map(ProjectWriteOff.fromMap).toList(growable: false);
  }

  @override
  Future<double> sumByProjectId(String projectId) async {
    final totalFen = await sumFenByProjectId(projectId);
    return totalFen / 100.0;
  }

  @override
  Future<Map<String, double>> sumByProjectIds(
    Iterable<String> projectIds,
  ) async {
    final fenSums = await sumFenByProjectIds(projectIds);
    return {
      for (final entry in fenSums.entries) entry.key: entry.value / 100.0,
    };
  }

  /// 权威 fen 汇总：SUM(amount_fen)。REAL amount 不再参与汇总判断。
  Future<int> sumFenByProjectId(String projectId) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', '项目 ID 不能为空');
    }
    final db = await AppDatabase.database;
    return sumFenByProjectIdWithExecutor(db, normalizedProjectId);
  }

  /// 事务内权威 fen 汇总。被 LocalProjectSettlementRepository 等事务化路径调用。
  Future<int> sumFenByProjectIdWithExecutor(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) return 0;
    final rows = await executor.rawQuery(
      'SELECT COALESCE(SUM(amount_fen), 0) AS total '
      'FROM $table WHERE project_id = ?',
      [normalizedProjectId],
    );
    return (rows.single['total'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, int>> sumFenByProjectIds(
    Iterable<String> projectIds,
  ) async {
    final normalizedProjectIds = projectIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedProjectIds.isEmpty) return const {};

    final placeholders = List.filled(
      normalizedProjectIds.length,
      '?',
    ).join(',');
    final db = await AppDatabase.database;
    final rows = await db.rawQuery(
      'SELECT project_id, COALESCE(SUM(amount_fen), 0) AS total '
      'FROM $table WHERE project_id IN ($placeholders) GROUP BY project_id',
      normalizedProjectIds,
    );
    final sums = {for (final projectId in normalizedProjectIds) projectId: 0};
    for (final row in rows) {
      final projectId = row['project_id'] as String?;
      if (projectId == null) continue;
      sums[projectId] = (row['total'] as num?)?.toInt() ?? 0;
    }
    return sums;
  }

  @override
  Future<int> clearAllForRestore() async {
    final db = await AppDatabase.database;
    return db.delete(table);
  }

  // 删除影响协调器使用的具体读/写辅助（不纳入抽象接口）。
  Future<int> countByProjectId(String projectId) async {
    final db = await AppDatabase.database;
    return countByProjectIdWithExecutor(db, projectId);
  }

  Future<int> countByProjectIdWithExecutor(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) return 0;
    final rows = await executor.rawQuery(
      'SELECT COUNT(*) AS count FROM $table WHERE project_id = ?',
      [normalizedProjectId],
    );
    return (rows.single['count'] as num?)?.toInt() ?? 0;
  }

  Future<int> deleteByProjectIdWithExecutor(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty) return 0;
    return executor.delete(
      table,
      where: 'project_id = ?',
      whereArgs: [normalizedProjectId],
    );
  }

  static void _validate(ProjectWriteOff item) {
    if (item.id.trim().isEmpty) {
      throw ArgumentError.value(item.id, 'id', '核销记录 ID 不能为空');
    }
    if (item.projectId.trim().isEmpty) {
      throw ArgumentError.value(item.projectId, 'projectId', '项目 ID 不能为空');
    }
    if (item.amount <= 0) {
      throw ArgumentError.value(item.amount, 'amount', '核销金额必须大于 0');
    }
    if (item.reason.trim().isEmpty) {
      throw ArgumentError.value(item.reason, 'reason', '核销原因不能为空');
    }
    if (item.writeOffDate.trim().isEmpty) {
      throw ArgumentError.value(item.writeOffDate, 'writeOffDate', '核销日期不能为空');
    }
    if (item.createdAt.trim().isEmpty) {
      throw ArgumentError.value(item.createdAt, 'createdAt', '创建时间不能为空');
    }
    if (item.updatedAt.trim().isEmpty) {
      throw ArgumentError.value(item.updatedAt, 'updatedAt', '更新时间不能为空');
    }
  }
}
