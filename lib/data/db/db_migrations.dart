import 'package:sqflite/sqflite.dart';

/// 数据库增量迁移链（onUpgrade）。
///
/// 说明：
/// - 保持 if(oldVersion < X) 的顺序与语义稳定。
/// - 迁移版本需与 AppDatabase._dbVersion 同步维护。
class DbMigrations {
  static Future<void> apply(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2：devices 增加 custom_avatar_path
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE devices ADD COLUMN custom_avatar_path TEXT;',
      );
    }

    // v2 -> v3：fuel_logs 增加 supplier
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE fuel_logs ADD COLUMN supplier TEXT NOT NULL DEFAULT '';",
      );
    }

    // v3 -> v4：新增 maintenance_records
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS maintenance_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id INTEGER,
          ymd INTEGER NOT NULL,
          item TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT
        );
      ''');
    }

    // v4 -> v5：新增 account_payments + project_device_rates
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_key TEXT NOT NULL,
          ymd INTEGER NOT NULL,
          amount REAL NOT NULL,
          note TEXT
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_account_payments_project_ymd
        ON account_payments(project_key, ymd);
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS project_device_rates (
          project_key TEXT NOT NULL,
          device_id INTEGER NOT NULL,
          is_breaking INTEGER NOT NULL DEFAULT 0,
          rate REAL NOT NULL,
          PRIMARY KEY (project_key, device_id, is_breaking)
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
        ON project_device_rates(project_key);
      ''');
    }

    // ✅ v5 -> v6：timing_records 增加 exclude_from_fuel_eff
    if (oldVersion < 6) {
      await db.execute('''
        ALTER TABLE timing_records
        ADD COLUMN exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0;
      ''');
    }

    // ✅ v6 -> v7：timing_records 增加 is_breaking
    if (oldVersion < 7) {
      await db.execute('''
        ALTER TABLE timing_records
        ADD COLUMN is_breaking INTEGER NOT NULL DEFAULT 0;
      ''');
    }

    // ✅ v7 -> v8：设备增加破碎默认单价；项目设备单价覆盖按模式拆分
    if (oldVersion < 8) {
      await db.execute('''
        ALTER TABLE devices
        ADD COLUMN breaking_unit_price REAL;
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS project_device_rates_v2 (
          project_key TEXT NOT NULL,
          device_id INTEGER NOT NULL,
          is_breaking INTEGER NOT NULL DEFAULT 0,
          rate REAL NOT NULL,
          PRIMARY KEY (project_key, device_id, is_breaking)
        );
      ''');

      await db.execute('''
        INSERT OR REPLACE INTO project_device_rates_v2 (
          project_key, device_id, is_breaking, rate
        )
        SELECT project_key, device_id, 0, rate
        FROM project_device_rates;
      ''');

      await db.execute('DROP TABLE IF EXISTS project_device_rates;');
      await db.execute(
        'ALTER TABLE project_device_rates_v2 RENAME TO project_device_rates;',
      );
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_project_device_rates_project
        ON project_device_rates(project_key);
      ''');
    }

    // ✅ v8 -> v9：设备增加 equipment_type
    if (oldVersion < 9) {
      await db.execute('''
        ALTER TABLE devices
        ADD COLUMN equipment_type TEXT NOT NULL DEFAULT 'excavator';
      ''');
    }
  }
}
