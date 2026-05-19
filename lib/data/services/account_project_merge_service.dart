import '../models/account_project_merge_group.dart';
import '../models/account_project_merge_group_with_members.dart';
import '../models/account_project_merge_member.dart';
import '../models/project.dart';
import '../models/project_id.dart';
import '../models/project_key.dart';
import '../repositories/account_project_merge_repository.dart';
import '../repositories/project_repository.dart';

const String settledProjectMergeBlockedMessage = '已结清项目不能参与合并，请先撤销结清后再操作。';

class AccountProjectMergeService {
  AccountProjectMergeService({
    required AccountProjectMergeRepository repository,
    ProjectRepository? projectRepository,
    DateTime Function()? now,
  }) : _repository = repository,
       _projectRepository = projectRepository,
       _now = now ?? DateTime.now;

  final AccountProjectMergeRepository _repository;
  final ProjectRepository? _projectRepository;
  final DateTime Function() _now;

  Future<AccountProjectMergeGroupWithMembers> createMergeGroup({
    required String contact,
    required List<String> projectKeys,
    List<String>? projectIds,
  }) async {
    final normalizedContact = contact.trim();
    if (normalizedContact.isEmpty) {
      throw ArgumentError.value(contact, 'contact', '联系人不能为空');
    }

    final parsed = _parseAndValidateProjectKeys(
      contact: normalizedContact,
      projectKeys: projectKeys,
    );
    if (parsed.length < 2) {
      throw ArgumentError.value(projectKeys, 'projectKeys', '至少选择 2 个项目');
    }

    final effectiveProjectIds = _effectiveProjectIds(
      parsed: parsed,
      projectIds: projectIds,
    );
    await _assertProjectsCanMerge(effectiveProjectIds);

    final existing = await _repository.listActiveMembersByProjectIds(
      effectiveProjectIds,
    );
    if (existing.isNotEmpty) {
      throw StateError('项目已属于其他合并组');
    }

    final createdAt = _timestamp();
    final group = AccountProjectMergeGroup(
      contact: normalizedContact,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final members = <AccountProjectMergeMember>[
      for (var index = 0; index < parsed.length; index += 1)
        AccountProjectMergeMember(
          groupId: 0,
          projectId: effectiveProjectIds[index],
          projectKey: parsed[index].key,
          contact: parsed[index].contact,
          site: parsed[index].site,
          sortOrder: index,
          createdAt: createdAt,
        ),
    ];

    return _repository.createGroupWithMembers(group: group, members: members);
  }

  Future<void> dissolveMergeGroup(int groupId) async {
    final group = await _repository.getGroupById(groupId);
    if (group == null) {
      throw StateError('合并组不存在');
    }
    if (!group.isActive) {
      throw StateError('合并组已解除');
    }
    await _repository.dissolveGroup(
      groupId: groupId,
      dissolvedAt: _timestamp(),
    );
  }

  Future<int?> findActiveGroupIdByProjectKey(String projectKey) async {
    final key = projectKey.trim();
    if (key.isEmpty) return null;

    final members = await _repository.listActiveMembersByProjectIds([
      ProjectId.legacyFromKey(key),
    ]);
    if (members.isEmpty) return null;
    return members.first.groupId;
  }

  Future<int?> findActiveGroupIdByProjectId(String projectId) async {
    final id = projectId.trim();
    if (id.isEmpty) return null;

    final members = await _repository.listActiveMembersByProjectIds([id]);
    if (members.isEmpty) return null;
    return members.first.groupId;
  }

  Future<bool> dissolveMergeGroupIfProjectKeyChanged({
    required String oldProjectKey,
    required String newProjectKey,
  }) async {
    final oldKey = oldProjectKey.trim();
    final newKey = newProjectKey.trim();
    if (oldKey.isEmpty || oldKey == newKey) return false;

    final groupId = await findActiveGroupIdByProjectKey(oldKey);
    if (groupId == null) return false;

    await dissolveMergeGroup(groupId);
    return true;
  }

  Future<bool> dissolveMergeGroupIfProjectIdChanged({
    required String oldProjectId,
    required String newProjectId,
  }) async {
    final oldId = oldProjectId.trim();
    final newId = newProjectId.trim();
    if (oldId.isEmpty || oldId == newId) return false;

    final groupId = await findActiveGroupIdByProjectId(oldId);
    if (groupId == null) return false;

    await dissolveMergeGroup(groupId);
    return true;
  }

  Future<List<AccountProjectMergeGroupWithMembers>>
  getActiveMergeGroupsWithMembers() {
    return _repository.listActiveGroupsWithMembers();
  }

  List<ProjectKey> _parseAndValidateProjectKeys({
    required String contact,
    required List<String> projectKeys,
  }) {
    final seen = <String>{};
    final parsed = <ProjectKey>[];

    for (final rawKey in projectKeys) {
      final key = rawKey.trim();
      if (key.isEmpty) continue;
      if (!seen.add(key)) {
        throw ArgumentError.value(projectKeys, 'projectKeys', '项目不能重复选择');
      }

      final project = ProjectKey.fromKey(key);
      final rebuilt = ProjectKey.buildKey(
        contact: project.contact,
        site: project.site,
      );
      if (rebuilt != key) {
        throw ArgumentError.value(rawKey, 'projectKeys', '项目 key 格式不正确');
      }
      if (project.contact.trim() != contact) {
        throw ArgumentError.value(projectKeys, 'projectKeys', '不能跨联系人合并');
      }
      if (project.site.trim().isEmpty) {
        throw ArgumentError.value(rawKey, 'projectKeys', '项目地址不能为空');
      }
      parsed.add(project);
    }

    return parsed;
  }

  List<String> _effectiveProjectIds({
    required List<ProjectKey> parsed,
    required List<String>? projectIds,
  }) {
    if (projectIds == null) {
      return parsed.map((item) => ProjectId.legacyFromKey(item.key)).toList();
    }

    if (projectIds.length != parsed.length) {
      throw ArgumentError.value(projectIds, 'projectIds', '项目 ID 数量不匹配');
    }

    return [
      for (final id in projectIds)
        if (id.trim().isNotEmpty)
          id.trim()
        else
          throw ArgumentError.value(projectIds, 'projectIds', '项目 ID 不能为空'),
    ];
  }

  Future<void> _assertProjectsCanMerge(List<String> projectIds) async {
    final projectRepository = _projectRepository;
    if (projectRepository == null) return;

    for (final projectId in projectIds) {
      final project = await projectRepository.findById(projectId);
      if (project == null) continue;
      if (project.status != ProjectStatus.active) {
        throw StateError(settledProjectMergeBlockedMessage);
      }
    }
  }

  String _timestamp() => _now().toUtc().toIso8601String();
}
