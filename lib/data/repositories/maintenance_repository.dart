import '../db/database.dart';
import '../models/maintenance_record.dart';

abstract class MaintenanceRepository {
  Future<List<MaintenanceRecord>> listAll();

  Future<void> insert(MaintenanceRecord record);

  Future<void> update(MaintenanceRecord record);

  Future<void> deleteById(int id);
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
  Future<void> insert(MaintenanceRecord record) async {
    final db = await AppDatabase.database;

    await db.insert(_table, record.toMap()..remove('id'));
  }

  // --------------------------------------------------
  // 更新
  // --------------------------------------------------
  @override
  Future<void> update(MaintenanceRecord record) async {
    final db = await AppDatabase.database;

    await db.update(
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

    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
