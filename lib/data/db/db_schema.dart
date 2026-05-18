import 'package:sqflite/sqflite.dart';

/// 数据库首次创建（onCreate）所需的全量 schema。
class DbSchema {
  static Future<void> create(Database db) async {
    // ----------------------------- projects -----------------------------
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        contact TEXT NOT NULL,
        site TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        settled_at TEXT,
        settled_snapshot TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        legacy_project_key TEXT UNIQUE
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_projects_legacy_key
      ON projects(legacy_project_key);
    ''');

    await db.execute('''
      CREATE INDEX idx_projects_active_contact_site
      ON projects(contact, site)
      WHERE status = 'active';
    ''');

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
        project_id TEXT NOT NULL,
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
        is_breaking INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (project_id)
          REFERENCES projects(id) ON DELETE RESTRICT
      );
    ''');

    // ------------------- timing_calculation_history -------------------
    await db.execute('''
      CREATE TABLE timing_calculation_history (
        id TEXT PRIMARY KEY,
        timing_record_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        expression TEXT NOT NULL,
        result REAL NOT NULL,
        ticket_count INTEGER NOT NULL,
        FOREIGN KEY (timing_record_id)
          REFERENCES timing_records(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_timing_calc_record_id
      ON timing_calculation_history(timing_record_id);
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
        project_id TEXT NOT NULL,
        project_key TEXT NOT NULL,
        ymd INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        source_type TEXT NOT NULL DEFAULT 'manual',
        merge_group_id INTEGER,
        merge_batch_id TEXT,
        merge_batch_total_amount REAL,
        merge_batch_note TEXT,
        created_at TEXT,
        FOREIGN KEY (project_id)
          REFERENCES projects(id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_account_payments_project_ymd
      ON account_payments(project_id, ymd);
    ''');

    // --------------------- project_device_rates ------------------------
    await db.execute('''
      CREATE TABLE project_device_rates (
        project_id TEXT NOT NULL,
        project_key TEXT NOT NULL,
        device_id INTEGER NOT NULL,
        is_breaking INTEGER NOT NULL DEFAULT 0,
        rate REAL NOT NULL,
        PRIMARY KEY (project_id, device_id, is_breaking),
        FOREIGN KEY (project_id)
          REFERENCES projects(id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_project_device_rates_project
      ON project_device_rates(project_id);
    ''');

    // ------------------ account_project_merge_groups ------------------
    await db.execute('''
      CREATE TABLE account_project_merge_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        dissolved_at TEXT,
        source_type TEXT NOT NULL DEFAULT 'local'
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_account_project_merge_groups_active_contact
      ON account_project_merge_groups(is_active, contact);
    ''');

    // ------------------ account_project_merge_members -----------------
    await db.execute('''
      CREATE TABLE account_project_merge_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        project_id TEXT NOT NULL,
        project_key TEXT NOT NULL,
        contact TEXT NOT NULL,
        site TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (group_id)
          REFERENCES account_project_merge_groups(id) ON DELETE CASCADE,
        FOREIGN KEY (project_id)
          REFERENCES projects(id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_account_project_merge_members_group
      ON account_project_merge_members(group_id, sort_order);
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_account_project_merge_members_group_project
      ON account_project_merge_members(group_id, project_id);
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_account_project_merge_members_active_project
      ON account_project_merge_members(project_id)
      WHERE is_active = 1;
    ''');
  }
}
