import 'package:sqflite/sqflite.dart';

/// account_payments / project_write_offs / project_device_rates
/// （project_id 外键指向 projects）。
class AccountSchema {
  static Future<void> create(Database db) async {
    await db.execute('''
      CREATE TABLE account_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id TEXT NOT NULL,
        project_key TEXT NOT NULL,
        ymd INTEGER NOT NULL,
        amount REAL NOT NULL,
        amount_fen INTEGER,
        note TEXT,
        source_type TEXT NOT NULL DEFAULT 'manual',
        merge_group_id INTEGER,
        merge_batch_id TEXT,
        merge_batch_total_amount REAL,
        merge_batch_total_amount_fen INTEGER,
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

    await db.execute('''
      CREATE TABLE project_write_offs (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        amount REAL NOT NULL CHECK (amount > 0),
        amount_fen INTEGER,
        reason TEXT NOT NULL,
        note TEXT,
        write_off_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (project_id)
          REFERENCES projects(id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_project_write_offs_project_id
      ON project_write_offs(project_id);
    ''');

    await db.execute('''
      CREATE INDEX idx_project_write_offs_write_off_date
      ON project_write_offs(write_off_date);
    ''');

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
  }
}
