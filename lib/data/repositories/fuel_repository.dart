import '../db/database.dart';
import '../models/fuel_log.dart';

// =====================================================================
// ============================== 燃油记录仓库 ==============================
// =====================================================================

class FuelRepo {
  static const String _table = 'fuel_logs';

  // -------------------------------------------------------------------
  // 1. 列出所有记录（按日期降序，id降序）
  // -------------------------------------------------------------------
  static Future<List<FuelLog>> listAll() async {
    final db = await AppDatabase.database;
    final rows = await db.query(_table, orderBy: 'date DESC, id DESC');
    return rows.map(FuelLog.fromMap).toList();
  }

  // -------------------------------------------------------------------
  // 2. 插入
  // -------------------------------------------------------------------
  static Future<int> insert(FuelLog log) async {
    final db = await AppDatabase.database;
    return await db.insert(_table, log.toMap());
  }

  // -------------------------------------------------------------------
  // 3. 更新
  // -------------------------------------------------------------------
  static Future<int> update(FuelLog log) async {
    final db = await AppDatabase.database;
    return await db.update(
      _table,
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  // -------------------------------------------------------------------
  // 4. 删除单条
  // -------------------------------------------------------------------
  static Future<int> deleteById(int id) async {
    final db = await AppDatabase.database;
    return await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------------------
  // 5. 级联删除：删除某设备的所有加油记录
  // (当用户彻底删除设备时使用——虽然后续一般只停用不删除)
  // -------------------------------------------------------------------
  static Future<int> deleteByDeviceId(int deviceId) async {
    final db = await AppDatabase.database;
    return await db.delete(
      _table,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }
}
