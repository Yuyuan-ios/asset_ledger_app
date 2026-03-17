import 'package:sqflite/sqflite.dart';

/// 数据库首次创建（onCreate）所需的全量 schema。
class DbSchema {
  static Future<void> create(Database db) async {
    // ----------------------------- devices -----------------------------
    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT,
        default_unit_price REAL NOT NULL,
        breaking_unit_price REAL,
        base_meter_hours REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        custom_avatar_path TEXT,
        equipment_type TEXT NOT NULL DEFAULT 'excavator'
      );
    ''');

    // -------------------------- timing_records --------------------------
    // v7 字段：exclude_from_fuel_eff / is_breaking 已内置在全量 schema
    await db.execute('''
      CREATE TABLE timing_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        start_date INTEGER NOT NULL,
        contact TEXT NOT NULL,
        site TEXT NOT NULL,
        type TEXT NOT NULL,
        start_meter REAL NOT NULL,
        end_meter REAL NOT NULL,
        hours REAL NOT NULL,
        income REAL NOT NULL,
        exclude_from_fuel_eff INTEGER NOT NULL DEFAULT 0,
        is_breaking INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // ---------------------------- fuel_logs ----------------------------
    await db.execute('''
      CREATE TABLE fuel_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        date INTEGER NOT NULL,
        supplier TEXT NOT NULL,
        liters REAL NOT NULL,
        cost REAL NOT NULL
      );
    ''');

    // ----------------------- maintenance_records -----------------------
    await db.execute('''
      CREATE TABLE maintenance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER,
        ymd INTEGER NOT NULL,
        item TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT
      );
    ''');

    // ------------------------ account_payments -------------------------
    await db.execute('''
      CREATE TABLE account_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_key TEXT NOT NULL,
        ymd INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_account_payments_project_ymd
      ON account_payments(project_key, ymd);
    ''');

    // --------------------- project_device_rates ------------------------
    await db.execute('''
      CREATE TABLE project_device_rates (
        project_key TEXT NOT NULL,
        device_id INTEGER NOT NULL,
        is_breaking INTEGER NOT NULL DEFAULT 0,
        rate REAL NOT NULL,
        PRIMARY KEY (project_key, device_id, is_breaking)
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_project_device_rates_project
      ON project_device_rates(project_key);
    ''');
  }
}
