import 'package:sqflite/sqflite.dart';

import '../models/project.dart';
import '../models/project_id.dart';
import '../models/project_key.dart';
import '../repositories/project_repository.dart';

class ProjectResolveResult {
  const ProjectResolveResult({required this.project, required this.created});

  final Project project;
  final bool created;

  String get projectId => project.id;
}

class ProjectResolver {
  ProjectResolver({
    required ProjectRepository projectRepository,
    DateTime Function()? now,
  }) : _projectRepository = projectRepository,
       _now = now ?? DateTime.now;

  final ProjectRepository _projectRepository;
  final DateTime Function() _now;

  Future<ProjectResolveResult> resolveOrCreate({
    required String contact,
    required String site,
    DateTime? workDate,
  }) async {
    return _resolveOrCreate(
      contact: contact,
      site: site,
      findActiveByContactSite: _projectRepository.findActiveByContactSite,
      insertProject: _projectRepository.insert,
    );
  }

  Future<ProjectResolveResult> resolveOrCreateWithExecutor(
    DatabaseExecutor executor, {
    required String contact,
    required String site,
    DateTime? workDate,
  }) async {
    return _resolveOrCreate(
      contact: contact,
      site: site,
      findActiveByContactSite:
          ({required String contact, required String site}) {
            return _projectRepository.findActiveByContactSiteWithExecutor(
              executor,
              contact: contact,
              site: site,
            );
          },
      insertProject: (project) {
        return _projectRepository.insertWithExecutor(executor, project);
      },
    );
  }

  Future<ProjectResolveResult> _resolveOrCreate({
    required String contact,
    required String site,
    required Future<List<Project>> Function({
      required String contact,
      required String site,
    })
    findActiveByContactSite,
    required Future<void> Function(Project project) insertProject,
  }) async {
    final normalizedContact = contact.trim();
    final normalizedSite = site.trim();
    if (normalizedContact.isEmpty || normalizedSite.isEmpty) {
      throw ArgumentError('联系人和工地不能为空');
    }

    final activeMatches = await findActiveByContactSite(
      contact: normalizedContact,
      site: normalizedSite,
    );
    if (activeMatches.length == 1) {
      return ProjectResolveResult(
        project: activeMatches.single,
        created: false,
      );
    }
    if (activeMatches.length > 1) {
      throw StateError('存在多个 active 项目匹配同一联系人和工地');
    }

    final timestamp = _timestamp();
    final legacyKey = ProjectKey.buildKey(
      contact: normalizedContact,
      site: normalizedSite,
    );
    final project = Project(
      id: ProjectId.create(),
      contact: normalizedContact,
      site: normalizedSite,
      status: ProjectStatus.active,
      createdAt: timestamp,
      updatedAt: timestamp,
      legacyProjectKey: legacyKey,
    );
    await insertProject(project);
    return ProjectResolveResult(project: project, created: true);
  }

  Future<String?> resolveExistingActiveProjectId({
    required String contact,
    required String site,
  }) async {
    final activeProject = await resolveExistingActiveProject(
      contact: contact,
      site: site,
    );
    return activeProject?.id;
  }

  Future<Project?> resolveExistingActiveProject({
    required String contact,
    required String site,
  }) async {
    final normalizedContact = contact.trim();
    final normalizedSite = site.trim();
    if (normalizedContact.isEmpty || normalizedSite.isEmpty) return null;

    final activeMatches = await _projectRepository.findActiveByContactSite(
      contact: normalizedContact,
      site: normalizedSite,
    );
    if (activeMatches.length == 1) return activeMatches.single;
    if (activeMatches.length > 1) {
      throw StateError('存在多个 active 项目匹配同一联系人和工地');
    }
    return null;
  }

  String _timestamp() => _now().toUtc().toIso8601String();
}
