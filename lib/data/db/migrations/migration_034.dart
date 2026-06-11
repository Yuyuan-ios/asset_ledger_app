part of '../db_migrations.dart';

/// v34：timing_records.income_fen 提升为 INTEGER NOT NULL（重建表）。
///
/// R5.26-B 系列在 account_payments(v31)/project_write_offs(v30) 之后的
/// timing 收尾：migration_029 已保证应用写入与回填恒一致（toMap 恒写非 NULL
/// income_fen、ensure/备份 restore 回填),这里把约束交给 schema 强制。
/// INSERT…SELECT 用 COALESCE(income_fen, CAST(ROUND(income * 100) AS INTEGER))
/// 兜底残留 NULL。income REAL 兼容列保留；unit / quantity_scaled 保持 nullable
/// （rent 行 quantity 合法为 NULL,v33 语义不变）,迁移时顺带 COALESCE 回填。
///
/// 执行策略（重要,同 migration_021）：
/// timing_records **不是叶子表**——timing_calculation_history 经
/// `REFERENCES timing_records(id) ON DELETE CASCADE` 反向引用。sqflite 的
/// onUpgrade 在事务内执行,事务内 `PRAGMA foreign_keys = OFF` 不生效;若在
/// FK 仍 ON 时 DROP timing_records,隐式 DELETE 会**级联清空计算历史**。
/// 因此 [apply] 只推进版本号、刻意不重建;真正的重建由
/// [ensureTimingIncomeFenNotNull] 在 onOpen 路径（DbSchemaCompat.ensure,
/// 事务外）执行,并在 PRAGMA OFF 未生效时抛错而不是冒险 DROP。
///
/// 坑A —— AUTOINCREMENT 高水位：处理方式同 migration_031（先删
/// timing_records / timing_records_v34 两个可能的序列残留行,再插唯一一行
/// max(old_seq, current_max_id)）。
class Migration034 {
  /// onUpgrade 入口：刻意为空（见类文档）。重建在 onOpen 的 ensure 执行。
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    // 故意为空——onUpgrade 事务内 PRAGMA foreign_keys = OFF 不生效,DROP 会
    // 级联删除 timing_calculation_history。重建只能走 onOpen ensure 路径。
  }

  /// 幂等：income_fen 已 NOT NULL 时直接返回。必须在 sqflite **事务外** 调用
  /// （onOpen / DbSchemaCompat.ensure,且在 ensureTimingIncomeFen /
  /// ensureTimingQuantityUnit 等补列回填之后）。
  static Future<void> ensureTimingIncomeFenNotNull(Database db) async {
    if (!await _tableExists(db, 'timing_records')) {
      return;
    }
    if (await _columnIsNotNull(db, 'timing_records', 'income_fen')) {
      return;
    }
    // 极简/历史测试桩可能缺业务列：缺 income/type/hours 时无法做有意义的
    // 重建回填,直接跳过（生产 schema 恒含三列）。
    if (!await _columnExists(db, 'timing_records', 'income') ||
        !await _columnExists(db, 'timing_records', 'type') ||
        !await _columnExists(db, 'timing_records', 'hours')) {
      return;
    }
    // 后续迁移补的 nullable 列防御性补齐,保证 INSERT…SELECT 列集完整。
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

    // 重建前读取旧高水位（容错：sqlite_sequence 表或行可能不存在 → 0）。
    final oldSeq = await _readSqliteSequenceSeq(db, 'timing_records');

    await db.execute('PRAGMA foreign_keys = OFF;');
    final fkState = await db.rawQuery('PRAGMA foreign_keys;');
    final fkEnabled = (fkState.single.values.first as int?) == 1;
    if (fkEnabled) {
      // 仍为 ON：处于活动事务中,PRAGMA 被忽略。此时 DROP timing_records 会
      // 级联删除 timing_calculation_history,绝不能继续。
      throw StateError(
        'timing_records rebuild 需在 sqflite 事务外执行；'
        'PRAGMA foreign_keys = OFF 未生效（疑似在 onUpgrade 事务内调用）。'
        '请把 ensureTimingIncomeFenNotNull 放到 onOpen / DbSchemaCompat.ensure '
        '中执行。',
      );
    }
    try {
      await db.execute('DROP TABLE IF EXISTS timing_records_v34;');
      await db.execute('''
        CREATE TABLE timing_records_v34 (
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
          unit TEXT,
          quantity_scaled INTEGER,
          exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
          is_breaking INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (project_id)
            REFERENCES projects(id) ON DELETE RESTRICT
        );
      ''');
      await db.execute('''
        INSERT INTO timing_records_v34 (
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
        'ALTER TABLE timing_records_v34 RENAME TO timing_records;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_timing_records_project
        ON timing_records(project_id);
      ''');

      // sqlite_sequence 高水位写回：max(old_seq, current_max_id),不倒退。
      final currentMaxId = await _readTimingMaxId(db);
      final computedSeq = oldSeq > currentMaxId ? oldSeq : currentMaxId;
      if (computedSeq > 0) {
        await db.execute(
          "DELETE FROM sqlite_sequence "
          "WHERE name IN ('timing_records', 'timing_records_v34');",
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

  /// 读取 sqlite_sequence 中 [name] 的 seq；表或行缺失返回 0（容错,不抛错）。
  static Future<int> _readSqliteSequenceSeq(Database db, String name) async {
    if (!await _tableExists(db, 'sqlite_sequence')) return 0;
    final rows = await db.rawQuery(
      'SELECT seq FROM sqlite_sequence WHERE name = ?;',
      [name],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['seq'] as int?) ?? 0;
  }

  static Future<int> _readTimingMaxId(Database db) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(id), 0) AS m FROM timing_records;',
    );
    return (rows.first['m'] as int?) ?? 0;
  }
}
