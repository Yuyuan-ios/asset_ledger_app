import 'package:flutter/material.dart';

import '../../../../patterns/account/account_project_section_pattern.dart';

class AccountProjectAreaHeader extends StatelessWidget {
  const AccountProjectAreaHeader({
    super.key,
    required this.isExternalWork,
    required this.projectCount,
    required this.externalWorkTitle,
    required this.isCompactProjectList,
    required this.hasActiveFilter,
    required this.onToggleCompactProjectList,
    required this.onOpenMerge,
    required this.onOpenFilter,
    required this.onClearFilter,
  });

  final bool isExternalWork;
  final int projectCount;
  final String externalWorkTitle;
  final bool isCompactProjectList;
  final bool hasActiveFilter;
  final VoidCallback onToggleCompactProjectList;
  final VoidCallback onOpenMerge;
  final VoidCallback onOpenFilter;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    if (isExternalWork) {
      return AccountProjectPinnedHeader(
        titleLabel: externalWorkTitle,
        projectCount: projectCount,
        trailing: const SizedBox.shrink(),
      );
    }

    return AccountProjectPinnedHeader(
      projectCount: projectCount,
      isCompactProjectList: isCompactProjectList,
      onToggleCompactProjectList: onToggleCompactProjectList,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AccountProjectMergeButton(onPressed: onOpenMerge),
          AccountProjectFilterButton(
            hasActiveFilter: hasActiveFilter,
            onOpenFilter: onOpenFilter,
            onClearFilter: onClearFilter,
          ),
        ],
      ),
    );
  }
}
