// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

// 1.1 项目内：数据库入口（统一拿到 sqflite Database 实例）
import 'package:sqflite/sqflite.dart';

import '../../core/measure/measure_unit.dart';
import '../db/database.dart';

// 1.2 项目内：计时记录模型（TimingRecord / TimingType）
import '../models/timing_record.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';

abstract class TimingRepository {
  Future<List<TimingRecord>> listAll();

  Future<int> insert(TimingRecord record);

  Future<int> update(TimingRecord record);

  Future<TimingRecord> saveWithCalculationHistories(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  });

  Future<int> deleteById(int id);

  Future<int> deleteByIds(Iterable<int> ids) async {
    var deleted = 0;
    for (final id in ids) {
      deleted += await deleteById(id);
    }
    return deleted;
  }

  Future<int> deleteByDeviceId(int deviceId);
}

// =====================================================================
// ============================== 二、数据仓库 SqfliteTimingRepository ==============================
// =====================================================================
//
// 设计目标：
// - Repo 只做“DB CRUD”（不做业务判断、不做 UI 逻辑）
// - 对上层（Store/Service）提供稳定接口：listAll/insert/update/delete...
//
class SqfliteTimingRepository implements TimingRepository {
  static const _table = 'timing_records';
  final SqfliteTimingCalculationHistoryRepository
  _calculationHistoryRepository = SqfliteTimingCalculationHistoryRepository();

  // =====================================================================
  // ============================== 三、查询（Read） ==============================
  // =====================================================================

  /// 读全部记录（按 start_date 降序，其次 id 降序）
  @override
  Future<List<TimingRecord>> listAll() async {
    final db = await AppDatabase.database;
    final rows = await db.query(_table, orderBy: 'start_date DESC, id DESC');
    return rows.map(_fromRow).toList();
  }

  // 以下为删除影响协调器（TimingRecordDeleteCoordinator）使用的具体读/写辅助，
  // 不纳入抽象接口，避免在多处测试假实现中扩散。

  Future<TimingRecord?> findById(int id) async {
    final db = await AppDatabase.database;
    return findByIdWithExecutor(db, id);
  }

  Future<TimingRecord?> findByIdWithExecutor(
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
    return _fromRow(rows.single);
  }

  Future<int> countByProjectIdExcluding({
    required String projectId,
    required int excludeRecordId,
  }) async {
    final db = await AppDatabase.database;
    return countByProjectIdExcludingWithExecutor(
      db,
      projectId: projectId,
      excludeRecordId: excludeRecordId,
    );
  }

  Future<int> countByProjectIdExcludingWithExecutor(
    DatabaseExecutor executor, {
    required String projectId,
    required int excludeRecordId,
  }) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return 0;
    final rows = await executor.rawQuery(
      'SELECT COUNT(*) AS count FROM $_table '
      'WHERE project_id = ? AND id != ?',
      [normalized, excludeRecordId],
    );
    return (rows.single['count'] as num?)?.toInt() ?? 0;
  }

  Future<int> countByProjectIdWithExecutor(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return 0;
    final rows = await executor.rawQuery(
      'SELECT COUNT(*) AS count FROM $_table WHERE project_id = ?',
      [normalized],
    );
    return (rows.single['count'] as num?)?.toInt() ?? 0;
  }

  /// 事务内按 project_id 列出计时记录。被 LocalSaveTimingRecordWithImpactUseCase
  /// 用来在保存事务内重算每个受影响项目的应收（fen）口径。
  Future<List<TimingRecord>> listByProjectIdWithExecutor(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return const [];
    final rows = await executor.query(
      _table,
      where: 'project_id = ?',
      whereArgs: [normalized],
      orderBy: 'start_date DESC, id DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// 事务内按 device_id 列出计时记录。保存层 allocation cutoff 校验只读使用；
  /// 排序口径与月收入隐式分摊一致：start_date → start_meter → id。
  Future<List<TimingRecord>> listByDeviceIdWithExecutor(
    DatabaseExecutor executor,
    int deviceId,
  ) async {
    final rows = await executor.query(
      _table,
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'start_date ASC, start_meter ASC, id ASC',
    );
    return rows.map(_fromRow).toList();
  }

  // =====================================================================
  // ============================== 四、新增（Create） ==============================
  // =====================================================================

  /// 新增记录：返回新行 id
  @override
  Future<int> insert(TimingRecord r) async {
    final db = await AppDatabase.database;
    return insertWithExecutor(db, r);
  }

  Future<int> insertWithExecutor(DatabaseExecutor executor, TimingRecord r) {
    return executor.insert(_table, _toRow(r));
  }

  // =====================================================================
  // ============================== 五、更新（Update） ==============================
  // =====================================================================

  /// 更新记录：按 id 更新
  @override
  Future<int> update(TimingRecord r) async {
    final db = await AppDatabase.database;
    return updateWithExecutor(db, r);
  }

  Future<int> updateWithExecutor(DatabaseExecutor executor, TimingRecord r) {
    if (r.id == null) {
      throw Exception(
        'SqfliteTimingRepository.update: TimingRecord.id is null',
      );
    }

    return executor.update(
      _table,
      _toRow(r),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  @override
  Future<TimingRecord> saveWithCalculationHistories(
    TimingRecord record, {
    List<TimingCalculationHistory> calculationHistories = const [],
  }) {
    return AppDatabase.inTransaction((txn) async {
      final recordId = record.id;
      if (recordId == null) {
        final insertedId = await insertWithExecutor(txn, record);
        final savedRecord = record.copyWith(id: insertedId);
        await _calculationHistoryRepository.insertManyWithExecutor(
          txn,
          insertedId,
          calculationHistories,
        );
        return savedRecord;
      }

      await updateWithExecutor(txn, record);
      await _calculationHistoryRepository.insertManyWithExecutor(
        txn,
        recordId,
        calculationHistories,
      );
      return record;
    });
  }

  // =====================================================================
  // ============================== 六、删除（Delete） ==============================
  // =====================================================================

  /// 删除记录：按记录 id 删除一条
  @override
  Future<int> deleteById(int id) async {
    final db = await AppDatabase.database;
    return deleteByIdWithExecutor(db, id);
  }

  Future<int> deleteByIdWithExecutor(DatabaseExecutor executor, int id) {
    return executor.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// 删除记录：按记录 id 批量删除多条
  @override
  Future<int> deleteByIds(Iterable<int> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) return 0;

    return AppDatabase.inTransaction((txn) async {
      var deleted = 0;
      for (final id in uniqueIds) {
        deleted += await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
      }
      return deleted;
    });
  }

  /// 删除记录：按设备 id 删除该设备所有记录
  @override
  Future<int> deleteByDeviceId(int deviceId) async {
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
      'project_id': r.effectiveProjectId,
      'device_id': r.deviceId,
      'start_date': r.startDate,
      'allocation_cutoff_date': r.allocationCutoffDate,
      'display_end_date': r.displayEndDate,
      'contact': r.contact,
      'site': r.site,
      'type': r.type.name,
      'start_meter': r.startMeter,
      'end_meter': r.endMeter,
      'hours': r.hours,
      'income': r.income,
      // fen 主存镜像与 REAL income 双写。v34 起 income_fen 为 NOT NULL,由
      // schema 强制——此前 _toRow 漏写该列,落库一直依赖 onOpen ensure 回填,
      // 读路径靠 REAL 回退掩盖;NOT NULL 翻转暴露后在此补齐写路径。
      'income_fen': r.incomeFen,
      // S2/v33 统一计量镜像(与 type/hours 双写;rent 行 quantity 为 null)。
      'unit': r.unit.dbValue,
      'quantity_scaled': r.quantityScaled,
      // ✅ v6：包油规则（不计入燃油效率）
      'exclude_from_fuel_eff': r.excludeFromFuelEfficiency ? 1 : 0,
      'is_breaking': r.isBreaking ? 1 : 0,
    };
  }

  /// DB Row -> Model
  ///
  /// 兼容老数据：字段不存在/为 null 时，默认 false
  static TimingRecord _fromRow(Map<String, Object?> row) {
    return TimingRecord.fromMap(row);
  }
}
