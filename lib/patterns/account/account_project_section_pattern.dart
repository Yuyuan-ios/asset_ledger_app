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
    this.isCompactProjectList = false,
    this.onToggleCompactProjectList,
  });

  final int projectCount;
  final Widget trailing;
  final bool isCompactProjectList;
  final VoidCallback? onToggleCompactProjectList;

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
            InkWell(
              onTap: onToggleCompactProjectList,
              borderRadius: BorderRadius.circular(1),
              child: Container(
                padding: EdgeInsets.only(
                  right: onToggleCompactProjectList == null ? 0 : 2,
                ),
                decoration: BoxDecoration(
                  color: isCompactProjectList
                      ? const Color(0xFFECECEC)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                    if (onToggleCompactProjectList != null) ...[
                      const SizedBox(width: 2),
                      _ProjectDensityToggleIcon(
                        isCompact: isCompactProjectList,
                      ),
                    ],
                  ],
                ),
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

class _ProjectDensityToggleIcon extends StatelessWidget {
  const _ProjectDensityToggleIcon({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isCompact ? '普通显示' : '紧凑显示',
      child: SizedBox(
        width: 22,
        height: 28,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ProjectDensityLine(isCompact: isCompact),
            const SizedBox(height: 2.5),
            _ProjectDensityLine(isCompact: isCompact),
            const SizedBox(height: 2.5),
            _ProjectDensityLine(isCompact: isCompact),
          ],
        ),
      ),
    );
  }
}

class _ProjectDensityLine extends StatelessWidget {
  const _ProjectDensityLine({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 3,
      decoration: BoxDecoration(
        color: isCompact ? const Color(0xFF666666) : const Color(0xFF8A8A8A),
        borderRadius: BorderRadius.circular(1.2),
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
    this.isCompactProjectList = false,
    this.onToggleCompactProjectList,
  });

  final List<AccountProjectVM> projects;
  final bool hasActiveFilter;
  final VoidCallback onOpenFilter;
  final VoidCallback onClearFilter;
  final ValueChanged<AccountProjectVM> onTapProject;
  final bool isCompactProjectList;
  final VoidCallback? onToggleCompactProjectList;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AccountProjectPinnedHeader(
          projectCount: projects.length,
          isCompactProjectList: isCompactProjectList,
          onToggleCompactProjectList: onToggleCompactProjectList,
          trailing: AccountProjectFilterButton(
            hasActiveFilter: hasActiveFilter,
            onOpenFilter: onOpenFilter,
            onClearFilter: onClearFilter,
          ),
        ),
        AccountProjectList(
          projects: projects,
          isCompact: isCompactProjectList,
          onTap: onTapProject,
        ),
        const SizedBox(height: AccountTokens.homeBottomGap),
      ],
    );
  }
}
