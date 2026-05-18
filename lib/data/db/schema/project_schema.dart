import 'package:sqflite/sqflite.dart';

/// projects 表与其索引（项目身份权威表）。
class ProjectSchema {
  static Future<void> create(Database db) async {
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
  }
}
