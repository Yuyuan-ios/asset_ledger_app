import '../models/account_project_merge_group.dart';
import '../models/account_project_merge_group_with_members.dart';
import '../models/account_project_merge_member.dart';
import '../models/project_key.dart';
import '../repositories/account_project_merge_repository.dart';

class AccountProjectMergeService {
  AccountProjectMergeService({
    required AccountProjectMergeRepository repository,
    DateTime Function()? now,
  }) : _repository = repository,
       _now = now ?? DateTime.now;

  final AccountProjectMergeRepository _repository;
  final DateTime Function() _now;

  Future<AccountProjectMergeGroupWithMembers> createMergeGroup({
    required String contact,
    required List<String> projectKeys,
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

    final existing = await _repository.listActiveMembersByProjectKeys(
      parsed.map((item) => item.key).toList(),
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

  String _timestamp() => _now().toUtc().toIso8601String();
}
