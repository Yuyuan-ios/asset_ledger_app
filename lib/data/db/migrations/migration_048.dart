part of '../db_migrations.dart';

/// v48：timing_records 删除 income REAL，income_fen 成为唯一存储权威。
///
/// timing_records 是非叶子表，timing_calculation_history 通过
/// `REFERENCES timing_records(id) ON DELETE CASCADE` 反向引用。sqflite
/// onUpgrade 在事务内执行，事务内 `PRAGMA foreign_keys = OFF` 不生效；
/// FK 仍 ON 时 DROP timing_records 会级联清空计算历史。因此 [apply] 刻意为空，
/// 重建只走 onOpen 的 [ensureTimingIncomeRealDropped]。
///
/// 坑A：AUTOINCREMENT 高水位同 migration_034/036，重建后写回
/// max(old_seq, current_max_id)，并清掉 timing_records_v48 残留序列行。
class Migration048 {
  /// onUpgrade 入口：刻意为空。重建必须走 onOpen ensure。
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    // 故意为空——非叶子表重建只能走 onOpen ensure 路径。
  }

  /// 幂等：income REAL 已不存在时直接返回。必须在 sqflite 事务外调用。
  static Future<void> ensureTimingIncomeRealDropped(Database db) async {
    if (!await _tableExists(db, 'timing_records')) {
      return;
    }
    if (!await _columnExists(db, 'timing_records', 'income')) {
      return;
    }
    // 极简/历史测试桩缺业务列时无法完整复刻当前 schema，直接跳过。
    if (!await _columnExists(db, 'timing_records', 'type') ||
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
        '请把 ensureTimingIncomeRealDropped 放到 onOpen / '
        'DbSchemaCompat.ensure 中执行。',
      );
    }

    try {
      await db.execute('DROP TABLE IF EXISTS timing_records_v48;');
      await db.execute('''
        CREATE TABLE timing_records_v48 (
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
        INSERT INTO timing_records_v48 (
          id, project_id, device_id, start_date, allocation_cutoff_date,
          display_end_date, contact, site, type, start_meter, end_meter,
          hours, income_fen, unit, quantity_scaled,
          exclude_from_fuel_eff, is_breaking
        )
        SELECT
          id, project_id, device_id, start_date, allocation_cutoff_date,
          display_end_date, contact, site, type, start_meter, end_meter,
          hours,
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
        'ALTER TABLE timing_records_v48 RENAME TO timing_records;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_timing_records_project
        ON timing_records(project_id);
      ''');

      final currentMaxId = await _readTimingMaxIdV48(db);
      final computedSeq = oldSeq > currentMaxId ? oldSeq : currentMaxId;
      if (computedSeq > 0) {
        await db.execute(
          "DELETE FROM sqlite_sequence "
          "WHERE name IN ('timing_records', 'timing_records_v48');",
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

  static Future<int> _readTimingMaxIdV48(Database db) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(id), 0) AS m FROM timing_records;',
    );
    return (rows.first['m'] as int?) ?? 0;
  }
}
