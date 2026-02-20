// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

// 1.1 项目内：数据库入口（统一拿到 sqflite Database 实例）
import '../db/db.dart';

// 1.2 项目内：计时记录模型（TimingRecord / TimingType）
import '../models/timing_record.dart';

// =====================================================================
// ============================== 二、数据仓库 TimingRepo ==============================
// =====================================================================
//
// 设计目标：
// - Repo 只做“DB CRUD”（不做业务判断、不做 UI 逻辑）
// - 对上层（Store/Service）提供稳定接口：listAll/insert/update/delete...
//
class TimingRepo {
  static const _table = 'timing_records';

  // =====================================================================
  // ============================== 三、查询（Read） ==============================
  // =====================================================================

  /// 读全部记录（按 start_date 升序，其次 id 升序）
  static Future<List<TimingRecord>> listAll() async {
    final db = await AppDatabase.database;
    final rows = await db.query(_table, orderBy: 'start_date ASC, id ASC');
    return rows.map(_fromRow).toList();
  }

  // =====================================================================
  // ============================== 四、新增（Create） ==============================
  // =====================================================================

  /// 新增记录：返回新行 id
  static Future<int> insert(TimingRecord r) async {
    final db = await AppDatabase.database;
    return db.insert(_table, _toRow(r));
  }

  // =====================================================================
  // ============================== 五、更新（Update） ==============================
  // =====================================================================

  /// 更新记录：按 id 更新
  static Future<int> update(TimingRecord r) async {
    if (r.id == null) {
      throw Exception('TimingRepo.update: TimingRecord.id is null');
    }

    final db = await AppDatabase.database;
    return db.update(_table, _toRow(r), where: 'id = ?', whereArgs: [r.id]);
  }

  // =====================================================================
  // ============================== 六、删除（Delete） ==============================
  // =====================================================================

  /// 删除记录：按记录 id 删除一条
  static Future<int> deleteById(int id) async {
    final db = await AppDatabase.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// 删除记录：按设备 id 删除该设备所有记录
  static Future<int> deleteByDeviceId(int deviceId) async {
    final db = await AppDatabase.database;
    return db.delete(_table, where: 'device_id = ?', whereArgs: [deviceId]);
  }

  // =====================================================================
  // ============================== 七、映射（DB row <-> Model） ==============================
  // =====================================================================

  /// Model -> DB Row
  ///
  /// 说明：
  /// - bool 在 SQLite 中使用 0/1 存储
  static Map<String, Object?> _toRow(TimingRecord r) {
    return {
      'device_id': r.deviceId,
      'start_date': r.startDate,
      'contact': r.contact,
      'site': r.site,
      'type': r.type.name,
      'start_meter': r.startMeter,
      'end_meter': r.endMeter,
      'hours': r.hours,
      'income': r.income,
      // ✅ v6：包油规则（不计入燃油效率）
      'exclude_from_fuel_eff': r.excludeFromFuelEfficiency ? 1 : 0,
    };
  }

  /// DB Row -> Model
  ///
  /// 兼容老数据：字段不存在/为 null 时，默认 false
  static TimingRecord _fromRow(Map<String, Object?> row) {
    return TimingRecord(
      id: row['id'] as int,
      deviceId: row['device_id'] as int,
      startDate: row['start_date'] as int,
      contact: row['contact'] as String,
      site: row['site'] as String,
      type: TimingType.values.byName(row['type'] as String),
      startMeter: (row['start_meter'] as num).toDouble(),
      endMeter: (row['end_meter'] as num).toDouble(),
      hours: (row['hours'] as num).toDouble(),
      income: (row['income'] as num).toDouble(),
      excludeFromFuelEfficiency:
          ((row['exclude_from_fuel_eff'] as int?) ?? 0) == 1,
    );
  }
}
