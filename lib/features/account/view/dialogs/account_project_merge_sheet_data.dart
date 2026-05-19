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

  const MergeProjectSheetItem({
    required this.projectId,
    required this.projectKey,
    required this.displayName,
    required this.isMerged,
  });
}

List<MergeProjectSheetContactGroup> buildMergeSheetGroups({
  required List<AccountProjectVM> normalProjects,
  required List<AccountProjectMergeGroupWithMembers> activeMergeGroups,
  Set<String> excludedProjectIds = const {},
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

      groupsByContact
          .putIfAbsent(
            contact,
            () => _MutableMergeSheetContactGroup(contact: contact),
          )
          .mergedItems
          .add(
            MergeProjectSheetItem(
              projectId: member.effectiveProjectId,
              projectKey: member.projectKey,
              displayName: ProjectKey(contact: contact, site: site).displayName,
              isMerged: true,
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
