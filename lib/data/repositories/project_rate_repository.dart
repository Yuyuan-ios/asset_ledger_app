import '../db/database.dart';
import '../models/project_device_rate.dart';

abstract class ProjectRateRepository {
  Future<List<ProjectDeviceRate>> listAll();

  Future<int> upsert(ProjectDeviceRate rate);

  Future<int> delete(String projectKey, int deviceId);

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
    final db = await AppDatabase.database;

    // sqflite 不统一支持 INSERT OR REPLACE 的 helper，我们直接 rawInsert
    return db.rawInsert(
      '''
      INSERT OR REPLACE INTO $table (project_key, device_id, rate)
      VALUES (?, ?, ?)
    ''',
      [r.projectKey, r.deviceId, r.rate],
    );
  }

  @override
  Future<int> delete(String projectKey, int deviceId) async {
    final db = await AppDatabase.database;
    return db.delete(
      table,
      where: 'project_key = ? AND device_id = ?',
      whereArgs: [projectKey, deviceId],
    );
  }

  @override
  Future<int> deleteByProjectKey(String projectKey) async {
    final db = await AppDatabase.database;
    return db.delete(table, where: 'project_key = ?', whereArgs: [projectKey]);
  }
}
