import 'package:sqflite/sqflite.dart';

/// projects 表与其索引（项目身份权威表）。
class ProjectSchema {
  static Future<void> create(Database db) async {
    // legacy_project_key 不再使用全局 UNIQUE 约束：同一 key 下允许保留多个
    // 已结清的历史项目，但同一 key 下只允许一个 active 项目，由下面的
    // partial unique index `idx_projects_active_legacy_key` 在 DB 层强制。
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
        legacy_project_key TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_projects_legacy_key
      ON projects(legacy_project_key);
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_projects_active_legacy_key
      ON projects(legacy_project_key)
      WHERE legacy_project_key IS NOT NULL AND status = 'active';
    ''');

    await db.execute('''
      CREATE INDEX idx_projects_active_contact_site
      ON projects(contact, site)
      WHERE status = 'active';
    ''');
  }
}
