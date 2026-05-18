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
    final normalizedContact = contact.trim();
    final normalizedSite = site.trim();
    if (normalizedContact.isEmpty || normalizedSite.isEmpty) {
      throw ArgumentError('联系人和工地不能为空');
    }

    final activeMatches = await _projectRepository.findActiveByContactSite(
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
    await _projectRepository.insert(project);
    return ProjectResolveResult(project: project, created: true);
  }

  String _timestamp() => _now().toUtc().toIso8601String();
}
