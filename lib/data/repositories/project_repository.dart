import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/project.dart';
import '../models/project_id.dart';
import '../models/project_key.dart';

abstract class ProjectRepository {
  Future<List<Project>> listAll();

  Future<Project?> findById(String id);

  Future<List<Project>> findActiveByContactSite({
    required String contact,
    required String site,
  });

  Future<List<Project>> findActiveByContactSiteWithExecutor(
    DatabaseExecutor executor, {
    required String contact,
    required String site,
  });

  Future<void> insert(Project project);

  Future<void> insertWithExecutor(DatabaseExecutor executor, Project project);

  Future<Project> findOrCreateLegacyProject({
    required String contact,
    required String site,
  });

  Future<void> upsert(Project project);
}

class SqfliteProjectRepository implements ProjectRepository {
  static const String table = 'projects';

  @override
  Future<List<Project>> listAll() async {
    final db = await AppDatabase.database;
    final rows = await db.query(table, orderBy: 'created_at ASC, id ASC');
    return rows.map(Project.fromMap).toList();
  }

  @override
  Future<Project?> findById(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;
    final db = await AppDatabase.database;
    return findByIdWithExecutor(db, normalized);
  }

  Future<Project?> findByIdWithExecutor(
    DatabaseExecutor executor,
    String id,
  ) async {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;
    final rows = await executor.query(
      table,
      where: 'id = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Project.fromMap(rows.single);
  }

  @override
  Future<List<Project>> findActiveByContactSite({
    required String contact,
    required String site,
  }) async {
    final db = await AppDatabase.database;
    return findActiveByContactSiteWithExecutor(
      db,
      contact: contact,
      site: site,
    );
  }

  @override
  Future<List<Project>> findActiveByContactSiteWithExecutor(
    DatabaseExecutor executor, {
    required String contact,
    required String site,
  }) async {
    final normalizedContact = contact.trim();
    final normalizedSite = site.trim();
    if (normalizedContact.isEmpty || normalizedSite.isEmpty) {
      return const [];
    }
    final rows = await executor.query(
      table,
      where: 'contact = ? AND site = ? AND status = ?',
      whereArgs: [normalizedContact, normalizedSite, ProjectStatus.active.name],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(Project.fromMap).toList();
  }

  @override
  Future<void> insert(Project project) async {
    final db = await AppDatabase.database;
    await insertWithExecutor(db, project);
  }

  @override
  Future<void> insertWithExecutor(
    DatabaseExecutor executor,
    Project project,
  ) async {
    await executor.insert(table, project.toMap());
  }

  Future<int> updateWithExecutor(
    DatabaseExecutor executor,
    Project project,
  ) async {
    final normalized = project.id.trim();
    if (normalized.isEmpty) return 0;
    return executor.update(
      table,
      project.toMap(),
      where: 'id = ?',
      whereArgs: [normalized],
    );
  }

  @override
  Future<Project> findOrCreateLegacyProject({
    required String contact,
    required String site,
  }) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final legacyKey = ProjectKey.buildKey(contact: contact, site: site);
    final projectId = ProjectId.legacyFromKey(legacyKey);
    final project = Project(
      id: projectId,
      contact: contact.trim(),
      site: site.trim(),
      status: ProjectStatus.active,
      createdAt: timestamp,
      updatedAt: timestamp,
      legacyProjectKey: legacyKey,
    );

    final db = await AppDatabase.database;
    await upsertWithExecutor(db, project);
    final saved = await findById(projectId);
    return saved ?? project;
  }

  @override
  Future<void> upsert(Project project) async {
    final db = await AppDatabase.database;
    await upsertWithExecutor(db, project);
  }

  // 删除影响协调器使用的具体读/写辅助（不纳入抽象接口）。
  Future<bool> isSettledWithExecutor(
    DatabaseExecutor executor,
    String projectId,
  ) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return false;
    final rows = await executor.query(
      table,
      columns: const ['status'],
      where: 'id = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.single['status'] as String?) == ProjectStatus.settled.name;
  }

  Future<bool> restoreActiveWithExecutor(
    DatabaseExecutor executor, {
    required String projectId,
    required String updatedAt,
  }) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return false;
    final rows = await executor.query(
      table,
      where: 'id = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final project = Project.fromMap(rows.single);
    if (project.status != ProjectStatus.settled) return false;
    await upsertWithExecutor(
      executor,
      project.copyWith(
        status: ProjectStatus.active,
        settledAt: null,
        settledSnapshot: null,
        updatedAt: updatedAt,
      ),
    );
    return true;
  }

  static Future<void> upsertWithExecutor(
    DatabaseExecutor executor,
    Project project,
  ) async {
    final existing = await executor.query(
      table,
      where: 'id = ?',
      whereArgs: [project.id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await executor.insert(table, project.toMap());
      return;
    }
    await executor.update(
      table,
      {
        'contact': project.contact,
        'site': project.site,
        'status': project.status.name,
        'settled_at': project.settledAt,
        'settled_snapshot': project.settledSnapshot,
        'updated_at': project.updatedAt,
        'legacy_project_key': project.legacyProjectKey,
      },
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }
}
