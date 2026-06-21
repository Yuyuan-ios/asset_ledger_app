import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/maintenance_record.dart';

abstract class MaintenanceRepository {
  Future<List<MaintenanceRecord>> listAll();

  Future<int> insert(MaintenanceRecord record);

  Future<void> update(MaintenanceRecord record);

  Future<void> deleteById(int id);

  Future<int> deleteByDeviceId(int deviceId);
}

class SqfliteMaintenanceRepository implements MaintenanceRepository {
  static const _table = 'maintenance_records';

  // --------------------------------------------------
  // 查询：全部（默认按日期 DESC）
  // --------------------------------------------------
  @override
  Future<List<MaintenanceRecord>> listAll() async {
    final db = await AppDatabase.database;

    final rows = await db.query(_table, orderBy: 'ymd DESC, id DESC');

    return rows.map(MaintenanceRecord.fromMap).toList();
  }

  // --------------------------------------------------
  // 新增
  // --------------------------------------------------
  @override
  Future<int> insert(MaintenanceRecord record) async {
    final db = await AppDatabase.database;
    return insertWithExecutor(db, record);
  }

  Future<int> insertWithExecutor(
    DatabaseExecutor executor,
    MaintenanceRecord record,
  ) {
    return executor.insert(_table, record.toMap()..remove('id'));
  }

  // --------------------------------------------------
  // 更新
  // --------------------------------------------------
  @override
  Future<void> update(MaintenanceRecord record) async {
    final db = await AppDatabase.database;
    await updateWithExecutor(db, record);
  }

  Future<int> updateWithExecutor(
    DatabaseExecutor executor,
    MaintenanceRecord record,
  ) {
    return executor.update(
      _table,
      record.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // --------------------------------------------------
  // 删除
  // --------------------------------------------------
  @override
  Future<void> deleteById(int id) async {
    final db = await AppDatabase.database;
    await deleteByIdWithExecutor(db, id);
  }

  Future<int> deleteByIdWithExecutor(DatabaseExecutor executor, int id) {
    return executor.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

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

  Future<MaintenanceRecord?> findByIdWithExecutor(
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
    return MaintenanceRecord.fromMap(rows.single);
  }

  Future<List<MaintenanceRecord>> listByDeviceIdWithExecutor(
    DatabaseExecutor executor,
    int deviceId,
  ) async {
    final rows = await executor.query(
      _table,
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'ymd DESC, id DESC',
    );
    return rows.map(MaintenanceRecord.fromMap).toList(growable: false);
  }
}
