import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../features/account/model/account_view_model.dart';
import '../../tokens/mapper/account_tokens.dart';
import '../../tokens/mapper/core_tokens.dart';
import 'account_project_list_pattern.dart';

class AccountProjectPinnedHeader extends StatelessWidget {
  const AccountProjectPinnedHeader({
    super.key,
    required this.projectCount,
    required this.trailing,
  });

  final int projectCount;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.scaffoldBg,
      child: Container(
        height: AccountTokens.projectPinnedHeaderHeight,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.only(bottom: AccountTokens.projectListTopGap),
        child: Row(
          children: [
            Text(
              '项目($projectCount)',
              style: AppTypography.sectionTitle(
                context,
                fontSize: AccountTokens.projectTitleFontSize,
                fontWeight: AccountTokens.projectTitleWeight,
                height: AccountTokens.projectTitleLineHeight,
              ),
            ),
            const Spacer(),
            trailing,
          ],
        ),
      ),
    );
  }
}

class AccountProjectFilterButton extends StatelessWidget {
  const AccountProjectFilterButton({
    super.key,
    required this.hasActiveFilter,
    required this.onOpenFilter,
    required this.onClearFilter,
  });

  final bool hasActiveFilter;
  final VoidCallback onOpenFilter;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final filterColor = AppColors.brand.withValues(alpha: 0.8);
    final filterTextStyle = AppTypography.actionText(
      context,
      fontSize: AccountTokens.projectFilterFontSize,
      fontWeight: FontWeight.w400,
    );
    final filterIconColor =
        filterTextStyle?.color ?? DefaultTextStyle.of(context).style.color;

    return TextButton(
      onPressed: hasActiveFilter ? onClearFilter : onOpenFilter,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: filterColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hasActiveFilter ? '取消筛选' : '筛选', style: filterTextStyle),
          const SizedBox(width: 0),
          Icon(Icons.filter_alt_outlined, size: 18, color: filterIconColor),
        ],
      ),
    );
  }
}

class AccountProjectMergeButton extends StatelessWidget {
  const AccountProjectMergeButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.brand.withValues(alpha: 0.8);
    final textStyle = AppTypography.actionText(
      context,
      fontSize: AccountTokens.projectFilterFontSize,
      fontWeight: FontWeight.w400,
    );
    final iconColor =
        textStyle?.color ?? DefaultTextStyle.of(context).style.color;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: color,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('合并', style: textStyle),
          const SizedBox(width: 0),
          Icon(Icons.call_merge_outlined, size: 18, color: iconColor),
        ],
      ),
    );
  }
}

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
        AccountProjectPinnedHeader(
          projectCount: projects.length,
          trailing: AccountProjectFilterButton(
            hasActiveFilter: hasActiveFilter,
            onOpenFilter: onOpenFilter,
            onClearFilter: onClearFilter,
          ),
        ),
        AccountProjectList(projects: projects, onTap: onTapProject),
        const SizedBox(height: AccountTokens.homeBottomGap),
      ],
    );
  }
}
