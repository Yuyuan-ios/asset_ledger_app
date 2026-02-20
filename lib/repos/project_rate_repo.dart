import '../db/db.dart';
import '../models/project_device_rate.dart';

// =====================================================================
// ============================== ProjectRateRepo ==============================
// =====================================================================
//
// 纯 CRUD：不写业务口径
// =====================================================================

class ProjectRateRepo {
  const ProjectRateRepo._();

  static const String table = 'project_device_rates';

  static Future<List<ProjectDeviceRate>> listAll() async {
    final db = await AppDatabase.database;
    final rows = await db.query(table);
    return rows.map((e) => ProjectDeviceRate.fromMap(e)).toList();
  }

  static Future<int> upsert(ProjectDeviceRate r) async {
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

  static Future<int> delete(String projectKey, int deviceId) async {
    final db = await AppDatabase.database;
    return db.delete(
      table,
      where: 'project_key = ? AND device_id = ?',
      whereArgs: [projectKey, deviceId],
    );
  }

  static Future<int> deleteByProjectKey(String projectKey) async {
    final db = await AppDatabase.database;
    return db.delete(table, where: 'project_key = ?', whereArgs: [projectKey]);
  }
}
