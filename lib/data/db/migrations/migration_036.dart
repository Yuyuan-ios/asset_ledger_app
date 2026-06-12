part of '../db_migrations.dart';

/// v36：timing_records.unit 提升为 TEXT NOT NULL（重建表，S2 schema 权威收口）。
///
/// v33 起 unit 为 nullable 镜像、v34 起写路径恒写非 NULL,本片把约束交给
/// schema 强制(纲要 §6.2「数据模型不得为单一小时写死」的机器强制形态)。
/// INSERT…SELECT 用 COALESCE(unit, CASE type) 兜底残留 NULL。
/// quantity_scaled **保持 nullable**——rent 行租期计量语义未定,NULL 合法
/// (v33 决策不变)。income_fen 维持 v34 的 NOT NULL。
///
/// 执行策略（同 migration_021/034）：timing_records 非叶子表
/// (timing_calculation_history FK CASCADE 入边),onUpgrade 事务内
/// PRAGMA foreign_keys=OFF 不生效,FK ON 时 DROP 会级联清空计算历史。
/// 因此 [apply] 刻意为空,重建只走 onOpen 的 ensure,且 PRAGMA 未生效即抛错。
///
/// 坑A —— AUTOINCREMENT 高水位：同 migration_031/034,先删新旧两名残留
/// 序列行,再插唯一一行 max(old_seq, current_max_id)。
class Migration036 {
  /// onUpgrade 入口：刻意为空（见类文档）。重建在 onOpen 的 ensure 执行。
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    // 故意为空——非叶子表重建只能走 onOpen ensure 路径。
  }

  /// 幂等：unit 已 NOT NULL 时直接返回。必须在 sqflite **事务外** 调用,
  /// 且在 ensureTimingQuantityUnit（补列+回填）与
  /// ensureTimingIncomeFenNotNull（income_fen NOT NULL 重建）之后。
  static Future<void> ensureTimingUnitNotNull(Database db) async {
    if (!await _tableExists(db, 'timing_records')) {
      return;
    }
    if (await _columnIsNotNull(db, 'timing_records', 'unit')) {
      return;
    }
    // 极简/历史测试桩缺业务列时无法做有意义的重建,直接跳过。
    if (!await _columnExists(db, 'timing_records', 'income') ||
        !await _columnExists(db, 'timing_records', 'type') ||
        !await _columnExists(db, 'timing_records', 'hours')) {
      return;
    }
    await _addColumnIfMissing(
      db,
      'timing_records',
      'allocation_cutoff_date',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      'timing_records',
      'display_end_date',
      'INTEGER',
    );
    await _addColumnIfMissing(db, 'timing_records', 'income_fen', 'INTEGER');
    await _addColumnIfMissing(db, 'timing_records', 'unit', 'TEXT');
    await _addColumnIfMissing(
      db,
      'timing_records',
      'quantity_scaled',
      'INTEGER',
    );

    final oldSeq = await _readSqliteSequenceSeq(db, 'timing_records');

    await db.execute('PRAGMA foreign_keys = OFF;');
    final fkState = await db.rawQuery('PRAGMA foreign_keys;');
    final fkEnabled = (fkState.single.values.first as int?) == 1;
    if (fkEnabled) {
      throw StateError(
        'timing_records rebuild 需在 sqflite 事务外执行；'
        'PRAGMA foreign_keys = OFF 未生效（疑似在 onUpgrade 事务内调用）。'
        '请把 ensureTimingUnitNotNull 放到 onOpen / DbSchemaCompat.ensure '
        '中执行。',
      );
    }
    try {
      await db.execute('DROP TABLE IF EXISTS timing_records_v36;');
      await db.execute('''
        CREATE TABLE timing_records_v36 (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id TEXT NOT NULL,
          device_id INTEGER NOT NULL,
          start_date INTEGER NOT NULL,
          allocation_cutoff_date INTEGER,
          display_end_date INTEGER,
          contact TEXT NOT NULL,
          site TEXT NOT NULL,
          type TEXT NOT NULL,
          start_meter REAL NOT NULL,
          end_meter REAL NOT NULL,
          hours REAL NOT NULL,
          income REAL NOT NULL,
          income_fen INTEGER NOT NULL,
          unit TEXT NOT NULL,
          quantity_scaled INTEGER,
          exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
          is_breaking INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (project_id)
            REFERENCES projects(id) ON DELETE RESTRICT
        );
      ''');
      await db.execute('''
        INSERT INTO timing_records_v36 (
          id, project_id, device_id, start_date, allocation_cutoff_date,
          display_end_date, contact, site, type, start_meter, end_meter,
          hours, income, income_fen, unit, quantity_scaled,
          exclude_from_fuel_eff, is_breaking
        )
        SELECT
          id, project_id, device_id, start_date, allocation_cutoff_date,
          display_end_date, contact, site, type, start_meter, end_meter,
          hours, income,
          COALESCE(income_fen, CAST(ROUND(income * 100) AS INTEGER)),
          COALESCE(unit, CASE WHEN type = 'rent' THEN 'RENT' ELSE 'HOUR' END),
          CASE WHEN type = 'rent' THEN quantity_scaled
               ELSE COALESCE(
                 quantity_scaled,
                 CAST(ROUND(hours * 1000) AS INTEGER)
               )
          END,
          exclude_from_fuel_eff, is_breaking
        FROM timing_records;
      ''');
      await db.execute('DROP TABLE timing_records;');
      await db.execute(
        'ALTER TABLE timing_records_v36 RENAME TO timing_records;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_timing_records_project
        ON timing_records(project_id);
      ''');

      final currentMaxId = await _readTimingMaxIdV36(db);
      final computedSeq = oldSeq > currentMaxId ? oldSeq : currentMaxId;
      if (computedSeq > 0) {
        await db.execute(
          "DELETE FROM sqlite_sequence "
          "WHERE name IN ('timing_records', 'timing_records_v36');",
        );
        await db.execute(
          "INSERT INTO sqlite_sequence(name, seq) "
          "VALUES ('timing_records', ?);",
          [computedSeq],
        );
      }
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }

    final issues = await db.rawQuery('PRAGMA foreign_key_check;');
    if (issues.isNotEmpty) {
      throw StateError('timing_records 外键校验失败: $issues');
    }
  }

  static Future<int> _readSqliteSequenceSeq(Database db, String name) async {
    if (!await _tableExists(db, 'sqlite_sequence')) return 0;
    final rows = await db.rawQuery(
      'SELECT seq FROM sqlite_sequence WHERE name = ?;',
      [name],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['seq'] as int?) ?? 0;
  }

  static Future<int> _readTimingMaxIdV36(Database db) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(id), 0) AS m FROM timing_records;',
    );
    return (rows.first['m'] as int?) ?? 0;
  }
}
