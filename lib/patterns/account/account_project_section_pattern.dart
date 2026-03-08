import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../features/account/state/account_store.dart';
import '../../tokens/mapper/account_tokens.dart';
import '../../tokens/mapper/core_tokens.dart';
import 'account_project_list_pattern.dart';

class AccountProjectSection extends StatelessWidget {
  const AccountProjectSection({
    super.key,
    required this.projects,
    required this.hasActiveFilter,
    required this.onOpenFilter,
    required this.onClearFilter,
    required this.onTapProject,
  });

  final List<AccountProjectVM> projects;
  final bool hasActiveFilter;
  final VoidCallback onOpenFilter;
  final VoidCallback onClearFilter;
  final ValueChanged<AccountProjectVM> onTapProject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '项目(${projects.length})',
              style: AppTypography.sectionTitle(
                context,
                fontSize: AccountTokens.projectTitleFontSize,
                fontWeight: AccountTokens.projectTitleWeight,
                height: AccountTokens.projectTitleLineHeight,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: hasActiveFilter ? onClearFilter : onOpenFilter,
              style: TextButton.styleFrom(
                padding: EdgeInsets.only(
                  right: AccountTokens.projectFilterRightInset,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.brand.withValues(alpha: 0.8),
              ),
              child: Text(
                hasActiveFilter ? '取消筛选' : '筛选',
                style: AppTypography.actionText(
                  context,
                  fontSize: AccountTokens.projectFilterFontSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AccountTokens.projectListTopGap),
        AccountProjectList(projects: projects, onTap: onTapProject),
        const SizedBox(height: AccountTokens.homeBottomGap),
      ],
    );
  }
}
