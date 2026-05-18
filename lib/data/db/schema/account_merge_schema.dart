import 'package:sqflite/sqflite.dart';

/// account_project_merge_groups / account_project_merge_members
/// （members.project_id 外键指向 projects，group_id 级联指向 groups）。
class AccountMergeSchema {
  static Future<void> create(Database db) async {
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
