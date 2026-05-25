import '../../domain/entities/account_entities.dart';
import '../../model/account_view_model.dart';

class MergeProjectSheetContactGroup {
  final String contact;
  final List<MergeProjectSheetItem> unmergedItems;
  final List<MergeProjectSheetItem> mergedItems;

  const MergeProjectSheetContactGroup({
    required this.contact,
    required this.unmergedItems,
    required this.mergedItems,
  });
}

class MergeProjectSheetItem {
  final String projectId;
  final String projectKey;
  final String displayName;
  final bool isMerged;

  /// 该项目当前是否还有计时记录聚合出的项目。
  /// 仅对「已合并」成员有意义：用于区分正常成员与仅有账务痕迹的弱化成员。
  final bool hasTimingRecord;

  /// 已合并成员的弱化标注（无计时记录但仍有账务/外协/结清痕迹时）；否则为 null。
  final String? note;

  const MergeProjectSheetItem({
    required this.projectId,
    required this.projectKey,
    required this.displayName,
    required this.isMerged,
    this.hasTimingRecord = true,
    this.note,
  });
}

/// 构建合并弹窗的联系人分组。
///
/// 「已合并」列表不再无条件展示所有 active merge members：
/// - [timingProjectIds]：当前仍有计时记录聚合出的项目 → 正常显示；
/// - [tracedProjectIds]：无计时但仍有账务/外协/结清痕迹的项目 → 保留显示并弱化标注；
/// - 两者都不在（无痕迹孤儿成员）→ 从「已合并」列表隐藏。
List<MergeProjectSheetContactGroup> buildMergeSheetGroups({
  required List<AccountProjectVM> normalProjects,
  required List<AccountProjectMergeGroupWithMembers> activeMergeGroups,
  Set<String> excludedProjectIds = const {},
  Set<String> timingProjectIds = const {},
  Set<String> tracedProjectIds = const {},
}) {
  final groupsByContact = <String, _MutableMergeSheetContactGroup>{};
  final activeMemberProjectIds = <String>{
    for (final groupWithMembers in activeMergeGroups)
      if (groupWithMembers.group.isActive)
        for (final member in groupWithMembers.members)
          if (member.isActive) member.effectiveProjectId,
  };
  final activeMemberProjectKeys = <String>{
    for (final groupWithMembers in activeMergeGroups)
      if (groupWithMembers.group.isActive)
        for (final member in groupWithMembers.members)
          if (member.isActive) member.projectKey.trim(),
  };

  for (final project in normalProjects) {
    if (project.kind != AccountProjectKind.normal) continue;
    final projectId = project.effectiveProjectId;
    if (excludedProjectIds.contains(projectId)) continue;

    final projectKey = project.projectKey.trim();
    if (activeMemberProjectIds.contains(projectId) ||
        activeMemberProjectKeys.contains(projectKey)) {
      continue;
    }

    final key = ProjectKey.fromKey(projectKey);
    final contact = key.contact.trim();
    if (contact.isEmpty || key.site.trim().isEmpty) continue;

    groupsByContact
        .putIfAbsent(
          contact,
          () => _MutableMergeSheetContactGroup(contact: contact),
        )
        .unmergedItems
        .add(
          MergeProjectSheetItem(
            projectId: projectId,
            projectKey: projectKey,
            displayName: project.displayName,
            isMerged: false,
          ),
        );
  }

  for (final groupWithMembers in activeMergeGroups) {
    if (!groupWithMembers.group.isActive) continue;

    final activeMembers =
        groupWithMembers.members.where((member) => member.isActive).toList()
          ..sort((a, b) {
            final byOrder = a.sortOrder.compareTo(b.sortOrder);
            if (byOrder != 0) return byOrder;
            return (a.id ?? 0).compareTo(b.id ?? 0);
          });

    for (final member in activeMembers) {
      final contact = member.contact.trim();
      final site = member.site.trim();
      if (contact.isEmpty || site.isEmpty) continue;

      final memberProjectId = member.effectiveProjectId;
      final hasTiming = timingProjectIds.contains(memberProjectId);
      final hasTrace = tracedProjectIds.contains(memberProjectId);
      // 无计时且无任何痕迹的历史孤儿成员：不在「已合并」列表展示。
      if (!hasTiming && !hasTrace) continue;

      groupsByContact
          .putIfAbsent(
            contact,
            () => _MutableMergeSheetContactGroup(contact: contact),
          )
          .mergedItems
          .add(
            MergeProjectSheetItem(
              projectId: memberProjectId,
              projectKey: member.projectKey,
              displayName: ProjectKey(contact: contact, site: site).displayName,
              isMerged: true,
              hasTimingRecord: hasTiming,
              note: hasTiming ? null : '无计时记录',
            ),
          );
    }
  }

  final groups =
      groupsByContact.values
          .where((group) {
            return group.unmergedItems.length + group.mergedItems.length >= 2;
          })
          .map((group) {
            return MergeProjectSheetContactGroup(
              contact: group.contact,
              unmergedItems: List.unmodifiable(group.unmergedItems),
              mergedItems: List.unmodifiable(group.mergedItems),
            );
          })
          .toList()
        ..sort((a, b) => a.contact.compareTo(b.contact));

  return List.unmodifiable(groups);
}

class _MutableMergeSheetContactGroup {
  _MutableMergeSheetContactGroup({required this.contact});

  final String contact;
  final List<MergeProjectSheetItem> unmergedItems = [];
  final List<MergeProjectSheetItem> mergedItems = [];
}
