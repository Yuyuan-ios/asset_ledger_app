import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/project.dart';
import '../models/project_device_rate.dart';
import '../models/project_id.dart';
import '../models/project_key.dart';
import 'project_repository.dart';

abstract class ProjectRateRepository {
  Future<List<ProjectDeviceRate>> listAll();

  Future<int> upsert(ProjectDeviceRate rate);

  Future<int> delete(
    String projectKey,
    int deviceId, {
    String? projectId,
    bool isBreaking = false,
  });

  Future<int> deleteByProjectKey(String projectKey);
}

// =====================================================================
// ============================== ProjectRateRepo ==============================
// =====================================================================
//
// 纯 CRUD：不写业务口径
// =====================================================================

class SqfliteProjectRateRepository implements ProjectRateRepository {
  static const String table = 'project_device_rates';

  @override
  Future<List<ProjectDeviceRate>> listAll() async {
    final db = await AppDatabase.database;
    final rows = await db.query(table);
    return rows.map((e) => ProjectDeviceRate.fromMap(e)).toList();
  }

  @override
  Future<int> upsert(ProjectDeviceRate r) async {
    return AppDatabase.inTransaction((txn) async {
      await _ensureProjectWithExecutor(txn, r);
      return txn.rawInsert(
        '''
        INSERT OR REPLACE INTO $table (
          project_id, project_key, device_id, is_breaking, rate_fen
        )
        VALUES (?, ?, ?, ?, ?)
      ''',
        [
          r.effectiveProjectId,
          r.projectKey,
          r.deviceId,
          r.isBreaking ? 1 : 0,
          r.rateFen,
        ],
      );
    });
  }

  @override
  Future<int> delete(
    String projectKey,
    int deviceId, {
    String? projectId,
    bool isBreaking = false,
  }) async {
    final db = await AppDatabase.database;
    final targetProjectId = projectId?.trim().isNotEmpty == true
        ? projectId!.trim()
        : ProjectId.legacyFromKey(projectKey);
    return db.delete(
      table,
      where: 'project_id = ? AND device_id = ? AND is_breaking = ?',
      whereArgs: [targetProjectId, deviceId, isBreaking ? 1 : 0],
    );
  }

  @override
  Future<int> deleteByProjectKey(String projectKey) async {
    final db = await AppDatabase.database;
    return db.delete(
      table,
      where: 'project_id = ?',
      whereArgs: [ProjectId.legacyFromKey(projectKey)],
    );
  }

  static Future<void> _ensureProjectWithExecutor(
    DatabaseExecutor executor,
    ProjectDeviceRate rate,
  ) {
    final parsed = ProjectKey.fromKey(rate.projectKey);
    final timestamp = DateTime.now().toUtc().toIso8601String();
    return SqfliteProjectRepository.upsertWithExecutor(
      executor,
      Project(
        id: rate.effectiveProjectId,
        contact: parsed.contact.trim(),
        site: parsed.site.trim(),
        createdAt: timestamp,
        updatedAt: timestamp,
        legacyProjectKey: rate.projectKey,
      ),
    );
  }
}
