// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

// 1.1 sqflite：DB 操作
import 'package:sqflite/sqflite.dart';

// 1.2 项目内：数据库入口
import '../db/db.dart';

// 1.3 项目内：设备模型
import '../models/device.dart';

// =====================================================================
// ============================== 二、DeviceRepo（数据仓库层） ==============================
// =====================================================================
//
// 设计原则：Repo 只做 CRUD，不做业务决策
// - 不负责“同品牌自动命名”
// - 不负责“是否允许复用编号”
// - 不负责“删除联动业务逻辑”
//
// 这些业务都应当放在 Store / Service / UI
// =====================================================================

class DeviceRepo {
  // -------------------------------------------------------------------
  // 2.1 表名常量
  // -------------------------------------------------------------------
  static const String _table = 'devices';

  // =====================================================================
  // ============================== 三、查询（Read） ==============================
  // =====================================================================

  // -------------------------------------------------------------------
  // 3.1 查询全部设备（包含 active + inactive）
  //
  // 用途：
  // - TimingPage 渲染历史记录时，需要通过 device_id 找到旧设备名/品牌等信息
  // - 即便设备停用了（is_active=0），也必须查得到（保证历史记录可回显）
  // -------------------------------------------------------------------
  static Future<List<Device>> listAll() async {
    final db = await AppDatabase.database;

    final rows = await db.query(_table, orderBy: 'id ASC');

    return rows.map(Device.fromMap).toList();
  }

  // -------------------------------------------------------------------
  // 3.2 查询在用设备（is_active=1）
  //
  // 用途：
  // - 设备页列表（只展示在用）
  // - 计时页下拉框（只允许选择在用设备）
  // -------------------------------------------------------------------
  static Future<List<Device>> listActive() async {
    final db = await AppDatabase.database;

    final rows = await db.query(
      _table,
      where: 'is_active = 1',
      orderBy: 'id ASC',
    );

    return rows.map(Device.fromMap).toList();
  }

  // -------------------------------------------------------------------
  // 3.3 按 id 查一台设备（包含停用）
  // -------------------------------------------------------------------
  static Future<Device?> findById(int id) async {
    final db = await AppDatabase.database;

    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return Device.fromMap(rows.first);
  }

  // =====================================================================
  // ============================== 四、新增/更新（Create/Update） ==============================
  // =====================================================================

  // -------------------------------------------------------------------
  // 4.1 新增设备：返回新 id
  //
  // ✅ 核心目标：deviceId 永远唯一、永不复用
  // - insert 时永远不传 id
  // - 让 SQLite AUTOINCREMENT 分配
  // -------------------------------------------------------------------
  static Future<int> insert(Device device) async {
    final db = await AppDatabase.database;

    final row = device.toMap()..remove('id');

    return db.insert(_table, row, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  // -------------------------------------------------------------------
  // 4.2 更新设备（按 id）
  // -------------------------------------------------------------------
  static Future<int> update(Device device) async {
    final db = await AppDatabase.database;

    if (device.id == null) {
      throw Exception('DeviceRepo.update: device.id 不能为空');
    }

    final row = device.toMap()..remove('id');

    return db.update(_table, row, where: 'id = ?', whereArgs: [device.id]);
  }

  // -------------------------------------------------------------------
  // 4.3 软删除/启用：只改 is_active
  //
  // ✅ 当前策略：删设备不删任何记录（计时/燃油/收入）
  // - 设备页“删除”按钮应该调用这里 setActive(id, false)
  // -------------------------------------------------------------------
  static Future<int> setActive(int id, bool active) async {
    final db = await AppDatabase.database;

    return db.update(
      _table,
      {'is_active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // -------------------------------------------------------------------
  // 4.4 ❌ 硬删除（调试用，不建议业务使用）
  // -------------------------------------------------------------------
  static Future<int> deleteById(int id) async {
    final db = await AppDatabase.database;

    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
