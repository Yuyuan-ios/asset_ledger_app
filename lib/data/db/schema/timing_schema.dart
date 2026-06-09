import 'package:sqflite/sqflite.dart';

/// timing_records（project_id 外键指向 projects）。
class TimingSchema {
  static Future<void> create(Database db) async {
    // v7 字段：exclude_from_fuel_eff / is_breaking 已内置在全量 schema
    await db.execute('''
      CREATE TABLE timing_records (
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
        income_fen INTEGER,
        exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
        is_breaking INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (project_id)
          REFERENCES projects(id) ON DELETE RESTRICT
      );
    ''');
  }
}
