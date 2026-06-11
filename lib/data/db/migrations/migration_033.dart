part of '../db_migrations.dart';

/// v33：timing_records 新增 nullable unit / quantity_scaled（S2 计量泛化第一片）。
///
/// 统一计量模型(《机账通商业与实现纲要》§3/§10.2)落库的 additive 起步:
/// - unit TEXT:计量单位 dbValue(HOUR/SHIFT/MU/…),按既有 type 回填——
///   rent 行回填 'RENT',其余回填 'HOUR'。
/// - quantity_scaled INTEGER:计量值定标整数(×1000)。hours 行按
///   round(hours × 1000) 回填(即 hours_milli 在统一模型下的同义镜像);
///   rent 行的计量语义(租期段数)未定,保持 NULL,留待租期模板落地时定义。
/// 本片不重建表、不切换读路径:hours REAL + type 仍是权威,unit/quantity_scaled
/// 是与之双写的镜像(模式同 migration_029 的 income_fen/B3)。
/// ensure* 形式幂等,可由 DbSchemaCompat.ensure 在 onOpen 兜底:列缺失则 ADD,
/// 值为 NULL 则回填,已有非 NULL 值不被覆盖。
class Migration033 {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 33) {
      await ensureTimingQuantityUnit(db);
    }
  }

  static Future<void> ensureTimingQuantityUnit(Database db) async {
    if (!await _tableExists(db, 'timing_records')) {
      return;
    }

    await _addColumnIfMissing(db, 'timing_records', 'unit', 'TEXT');
    await _addColumnIfMissing(
      db,
      'timing_records',
      'quantity_scaled',
      'INTEGER',
    );

    // 防御:回填引用 type / hours 列。生产 timing_records 始终含两列,但极简/
    // 历史 schema(如纯 FK 升级测试桩)可能缺列,此时按可用列降级回填或跳过,
    // 避免迁移链因 "no such column" 中断(同 migration_029 的防御策略)。
    final hasType = await _columnExists(db, 'timing_records', 'type');
    if (hasType) {
      await db.execute('''
        UPDATE timing_records
        SET unit = CASE WHEN type = 'rent' THEN 'RENT' ELSE 'HOUR' END
        WHERE unit IS NULL;
      ''');
    } else {
      await db.execute('''
        UPDATE timing_records SET unit = 'HOUR' WHERE unit IS NULL;
      ''');
    }

    if (!await _columnExists(db, 'timing_records', 'hours')) {
      return;
    }
    if (hasType) {
      await db.execute('''
        UPDATE timing_records
        SET quantity_scaled = CAST(ROUND(hours * 1000) AS INTEGER)
        WHERE quantity_scaled IS NULL AND type != 'rent';
      ''');
    } else {
      await db.execute('''
        UPDATE timing_records
        SET quantity_scaled = CAST(ROUND(hours * 1000) AS INTEGER)
        WHERE quantity_scaled IS NULL;
      ''');
    }
  }
}
