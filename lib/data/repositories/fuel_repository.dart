import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/fuel_log.dart';

abstract class FuelRepository {
  Future<List<FuelLog>> listAll();

  Future<int> insert(FuelLog log);

  Future<int> update(FuelLog log);

  Future<int> deleteById(int id);

  Future<int> deleteByDeviceId(int deviceId);
}

// =====================================================================
// ============================== 燃油记录仓库 ==============================
// =====================================================================

class SqfliteFuelRepository implements FuelRepository {
  static const String _table = 'fuel_logs';

  // -------------------------------------------------------------------
  // 1. 列出所有记录（按日期降序，id降序）
  // -------------------------------------------------------------------
  @override
  Future<List<FuelLog>> listAll() async {
    final db = await AppDatabase.database;
    final rows = await db.query(_table, orderBy: 'date DESC, id DESC');
    return rows.map(FuelLog.fromMap).toList();
  }

  // -------------------------------------------------------------------
  // 2. 插入
  // -------------------------------------------------------------------
  @override
  Future<int> insert(FuelLog log) async {
    final db = await AppDatabase.database;
    return insertWithExecutor(db, log);
  }

  Future<int> insertWithExecutor(DatabaseExecutor executor, FuelLog log) {
    return executor.insert(_table, log.toMap());
  }

  // -------------------------------------------------------------------
  // 3. 更新
  // -------------------------------------------------------------------
  @override
  Future<int> update(FuelLog log) async {
    final db = await AppDatabase.database;
    return updateWithExecutor(db, log);
  }

  Future<int> updateWithExecutor(DatabaseExecutor executor, FuelLog log) {
    return executor.update(
      _table,
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  // -------------------------------------------------------------------
  // 4. 删除单条
  // -------------------------------------------------------------------
  @override
  Future<int> deleteById(int id) async {
    final db = await AppDatabase.database;
    return deleteByIdWithExecutor(db, id);
  }

  Future<int> deleteByIdWithExecutor(DatabaseExecutor executor, int id) {
    return executor.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------------------
  // 5. 级联删除：删除某设备的所有加油记录
  // (当用户彻底删除设备时使用——虽然后续一般只停用不删除)
  // -------------------------------------------------------------------
  @override
  Future<int> deleteByDeviceId(int deviceId) async {
    final db = await AppDatabase.database;
    return deleteByDeviceIdWithExecutor(db, deviceId);
  }

  Future<int> deleteByDeviceIdWithExecutor(
    DatabaseExecutor executor,
    int deviceId,
  ) {
    return executor.delete(
      _table,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<FuelLog?> findByIdWithExecutor(
    DatabaseExecutor executor,
    int id,
  ) async {
    final rows = await executor.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FuelLog.fromMap(rows.single);
  }

  Future<List<FuelLog>> listByDeviceIdWithExecutor(
    DatabaseExecutor executor,
    int deviceId,
  ) async {
    final rows = await executor.query(
      _table,
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(FuelLog.fromMap).toList(growable: false);
  }
}
