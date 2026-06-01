import 'package:flutter/material.dart';

import '../../components/avatars/linked_external_work_badge.dart';
import '../../core/foundation/typography.dart';
import '../../core/utils/format_utils.dart';
import '../../features/account/model/account_view_model.dart';
import '../../tokens/mapper/account_tokens.dart';
import '../../tokens/mapper/color_tokens.dart';
import 'account_project_card_vm.dart';

const Color _settledCardBg = SheetColors.background;
const Color _settledCardBorder = AccountTokens.projectCardBorderColor;
const Color _settledCheckBlue = Color(0xFF4AAFD8);
const Color _settledTextGreen = Color(0xFF3F8F5D);
const Color _externalWorkCardBg = SheetColors.background;
const Color _externalWorkCardBorder = Color(0xFFD9EDE3);
const Color _externalWorkBadgeBg = Color(0xFFE4F4EA);
const Color _externalWorkBadgeText = Color(0xFF3F8F5F);
const Color _externalWorkValueText = Color(0xFF2F6F49);
const double _externalWorkAvatarTopInset = 4;
const double _externalWorkCardTopPadding =
    _externalWorkAvatarTopInset - AccountTokens.projectCardBorderWidth;
const double _externalWorkCardBottomPadding = 6;
const double _externalWorkCardMetricTopGap = 12;
const double _accountProjectEmptyTopPadding = 48;
const double _accountProjectEmptyBottomPadding = 24;
const Key _externalWorkAvatarKey = Key('account-external-work-avatar');
const Key _accountProjectWorklogExportButtonKey = Key(
  'account-project-worklog-export-button',
);
const double _worklogExportButtonSize = 30;
const Key _accountProjectLinkedExternalWorkBadgeKey = Key(
  'account-project-linked-external-work-badge',
);
const String _settledCelebrationIconAsset =
    'assets/icons/account/settled_celebration.png';
const Key _settledCelebrationIconKey = Key('settled-project-celebration-icon');

class _PriceBadgeStyle {
  const _PriceBadgeStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
}

class AccountProjectList extends StatelessWidget {
  const AccountProjectList({
    super.key,
    required this.projects,
    required this.onTap,
    this.externalWorkProjects = const [],
    this.isCompact = false,
    this.onExportWorklog,
    this.canExportWorklog,
    this.emptyText = '暂无项目（计时页有记录后将自动出现）',
  });

  final List<AccountProjectVM> projects;
  final List<AccountExternalWorkProjectVM> externalWorkProjects;
  final ValueChanged<AccountProjectVM> onTap;
  final bool isCompact;
  final ValueChanged<AccountProjectVM>? onExportWorklog;
  final bool Function(AccountProjectVM project)? canExportWorklog;
  final String emptyText;

  _PriceBadgeStyle _priceBadgeStyle(AccountProjectPriceBadgeKind kind) {
    switch (kind) {
      case AccountProjectPriceBadgeKind.rent:
        return const _PriceBadgeStyle(
          backgroundColor: AccountTokens.projectCardRentBadgeBackground,
          borderColor: AccountTokens.projectCardRentBadgeBorder,
          textColor: AccountTokens.projectCardRentBadgeText,
        );
      case AccountProjectPriceBadgeKind.multi:
        return const _PriceBadgeStyle(
          backgroundColor: AccountTokens.projectCardMultiRateBadgeBackground,
          borderColor: AccountTokens.projectCardMultiRateBadgeBorder,
          textColor: AccountTokens.projectCardMultiRateBadgeText,
        );
      case AccountProjectPriceBadgeKind.single:
        return const _PriceBadgeStyle(
          backgroundColor: AccountTokens.projectCardSingleRateBadgeBackground,
          borderColor: AccountTokens.projectCardSingleRateBadgeBorder,
          textColor: AccountTokens.projectCardSingleRateBadgeText,
        );
    }
  }

  Widget _receivedText(AccountProjectCardVm vm, TextStyle? style) {
    final base = vm.receivedBaseText;
    final sitesSuffix = vm.mergedSitesSuffix;
    if (sitesSuffix == null || sitesSuffix.isEmpty) {
      if (base.isEmpty) return const SizedBox.shrink();
      return Text(
        base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$base(', maxLines: 1, style: style),
        Flexible(
          child: Text(
            sitesSuffix,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        Text(')', maxLines: 1, style: style),
      ],
    );
  }

  Widget _settlementStatus(AccountProjectCardVm vm, TextStyle? style) {
    final text = vm.settlementStatusText;
    if (!vm.isSettled) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: style,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          _settledCelebrationIconAsset,
          key: _settledCelebrationIconKey,
          width: 18,
          height: 18,
          semanticLabel: '结清图标',
        ),
        const SizedBox(width: 4),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: style,
        ),
      ],
    );
  }

  bool _showWorklogExport(AccountProjectVM project) {
    if (onExportWorklog == null) return false;
    final predicate = canExportWorklog;
    return predicate == null || predicate(project);
  }

  Widget _worklogExportButton(BuildContext context, AccountProjectVM project) {
    final color = AppColors.textPrimary.withValues(alpha: 0.64);
    return SizedBox.square(
      dimension: _worklogExportButtonSize,
      child: IconButton(
        key: _accountProjectWorklogExportButtonKey,
        tooltip: '导出工时表',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: _worklogExportButtonSize,
          height: _worklogExportButtonSize,
        ),
        style: IconButton.styleFrom(
          foregroundColor: color,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(
          Icons.file_upload_outlined,
          size: 17,
          semanticLabel: '导出工时表',
        ),
        onPressed: () => onExportWorklog?.call(project),
      ),
    );
  }

  Widget _totalHoursWithExportAction({
    required BuildContext context,
    required AccountProjectVM project,
    required String totalHoursText,
    required TextStyle? style,
    required bool showExport,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            totalHoursText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.right,
            style: style,
          ),
        ),
        if (showExport) ...[
          const SizedBox(width: 2),
          _worklogExportButton(context, project),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final emptyStyle = AppTypography.bodySecondary(
      context,
      fontSize: 16,
      color: TimingColors.textSecondary,
    );
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontSize: AccountTokens.projectCardTitleFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: Colors.black,
    );
    final dateStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectCardDateFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: Colors.black.withValues(alpha: 0.9),
    );
    final chipStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectCardChipFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: Colors.black,
    );
    final statusStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectCardStatusFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: Colors.black,
    );
    final totalHoursStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectCardStatusFontSize,
      fontWeight: FontWeight.w700,
      height: 1,
      color: Colors.black,
    );

    if (projects.isEmpty && externalWorkProjects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(
          top: _accountProjectEmptyTopPadding,
          bottom: _accountProjectEmptyBottomPadding,
        ),
        child: Center(child: Text(emptyText, style: emptyStyle)),
      );
    }

    return Column(
      children: [
        for (final p in projects) ...[
          Builder(
            builder: (context) {
              final vm = AccountProjectCardVmBuilder.build(
                project: p,
                isCompact: isCompact,
              );
              final totalHoursText = vm.totalHoursText;
              final priceText = vm.priceText;
              final badgeStyle = _priceBadgeStyle(vm.priceBadgeKind);
              final isSettled = vm.isSettled;
              final displayProgress = vm.displayProgress;
              final showExport = _showWorklogExport(p);
              final resolvedStatusStyle = isSettled
                  ? statusStyle?.copyWith(color: _settledTextGreen)
                  : statusStyle;
              return Container(
                margin: const EdgeInsets.only(
                  bottom: AccountTokens.projectCardBottomMargin,
                ),
                constraints: BoxConstraints(
                  minHeight: isCompact ? 0 : AccountTokens.projectCardMinHeight,
                ),
                decoration: BoxDecoration(
                  color: isSettled ? _settledCardBg : SheetColors.background,
                  border: Border.all(
                    color: isSettled
                        ? _settledCardBorder
                        : AccountTokens.projectCardBorderColor,
                    width: AccountTokens.projectCardBorderWidth,
                  ),
                  borderRadius: BorderRadius.circular(
                    AccountTokens.projectCardRadius,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: AccountTokens.projectCardShadowOpacity,
                      ),
                      blurRadius: AccountTokens.projectCardShadowBlur,
                      offset: const Offset(
                        AccountTokens.projectCardShadowOffsetX,
                        AccountTokens.projectCardShadowOffsetY,
                      ),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    AccountTokens.projectCardRadius,
                  ),
                  onTap: () => onTap(p),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: AccountTokens.projectCardPaddingHorizontal,
                      right: AccountTokens.projectCardPaddingHorizontal,
                      top: AccountTokens.projectCardPaddingTop,
                      bottom: isCompact
                          ? AccountTokens.projectCardProgressBottomGap
                          : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      vm.titleText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: titleStyle,
                                    ),
                                  ),
                                  if (vm.hasLinkedExternalWork) ...[
                                    const SizedBox(width: 6),
                                    LinkedExternalWorkBadge(
                                      key:
                                          _accountProjectLinkedExternalWorkBadgeKey,
                                      borderColor: isSettled
                                          ? _settledCardBg
                                          : SheetColors.background,
                                    ),
                                  ],
                                  if (isSettled) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 18,
                                      color: _settledCheckBlue,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(
                              width: AccountTokens.projectCardTitleDateGap,
                            ),
                            Flexible(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Text(
                                      vm.topRightText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: dateStyle,
                                    ),
                                  ),
                                  if (isCompact && showExport) ...[
                                    const SizedBox(width: 2),
                                    _worklogExportButton(context, p),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: AccountTokens.projectCardSectionGap,
                        ),
                        if (!isCompact) ...[
                          Row(
                            children: [
                              Container(
                                constraints: const BoxConstraints(
                                  minWidth: AccountTokens.projectCardChipWidth,
                                  maxWidth: 220,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeStyle.backgroundColor,
                                  border: Border.all(
                                    color: badgeStyle.borderColor,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AccountTokens.projectCardChipRadius,
                                  ),
                                ),
                                child: Text(
                                  priceText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: chipStyle?.copyWith(
                                    color: badgeStyle.textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (totalHoursText != null) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _totalHoursWithExportAction(
                                    context: context,
                                    project: p,
                                    totalHoursText: totalHoursText,
                                    style: totalHoursStyle,
                                    showExport: showExport,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(
                            height: AccountTokens.projectCardRateToStatusGap,
                          ),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: _receivedText(vm, resolvedStatusStyle),
                            ),
                            const SizedBox(width: 8),
                            _settlementStatus(vm, resolvedStatusStyle),
                          ],
                        ),
                        const SizedBox(
                          height: AccountTokens.projectCardProgressTopGap,
                        ),
                        SizedBox(
                          height: AccountTokens.projectCardProgressHeight,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Stack(
                              children: [
                                Container(
                                  height: AccountTokens
                                      .projectCardProgressFillHeight,
                                  decoration: BoxDecoration(
                                    color:
                                        AccountTokens.projectCardProgressTrack,
                                    borderRadius: BorderRadius.circular(
                                      AccountTokens.projectCardProgressRadius,
                                    ),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: displayProgress,
                                  child: Container(
                                    height: AccountTokens
                                        .projectCardProgressFillHeight,
                                    decoration: BoxDecoration(
                                      color:
                                          AccountTokens.projectCardProgressFill,
                                      borderRadius: BorderRadius.circular(
                                        AccountTokens.projectCardProgressRadius,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        for (final project in externalWorkProjects)
          _ExternalWorkProjectCard(project: project, isCompact: isCompact),
      ],
    );
  }
}

class _ExternalWorkProjectCard extends StatelessWidget {
  const _ExternalWorkProjectCard({
    required this.project,
    required this.isCompact,
  });

  final AccountExternalWorkProjectVM project;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.sectionTitle(
      context,
      fontSize: AccountTokens.projectCardTitleFontSize,
      fontWeight: FontWeight.w500,
      height: 1.1,
      color: Colors.black,
    );
    final dateStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectCardDateFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: Colors.black.withValues(alpha: 0.65),
    );
    final metricLabelStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectCardStatusFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: Colors.black.withValues(alpha: 0.58),
    );
    final metricValueStyle = AppTypography.body(
      context,
      fontSize: AccountTokens.projectCardStatusFontSize,
      fontWeight: FontWeight.w700,
      height: 1,
      color: _externalWorkValueText,
    );
    final pendingValueStyle = metricValueStyle?.copyWith(
      color: Colors.black.withValues(alpha: 0.62),
      fontWeight: FontWeight.w500,
    );

    return Container(
      key: Key('account-external-work-card-${project.importBatchId}'),
      margin: const EdgeInsets.only(
        bottom: AccountTokens.projectCardBottomMargin,
      ),
      constraints: BoxConstraints(
        minHeight: isCompact ? 0 : AccountTokens.projectCardMinHeight,
      ),
      decoration: BoxDecoration(
        color: _externalWorkCardBg,
        border: Border.all(
          color: _externalWorkCardBorder,
          width: AccountTokens.projectCardBorderWidth,
        ),
        borderRadius: BorderRadius.circular(AccountTokens.projectCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AccountTokens.projectCardShadowOpacity,
            ),
            blurRadius: AccountTokens.projectCardShadowBlur,
            offset: const Offset(
              AccountTokens.projectCardShadowOffsetX,
              AccountTokens.projectCardShadowOffsetY,
            ),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AccountTokens.projectCardPaddingHorizontal,
          _externalWorkCardTopPadding,
          AccountTokens.projectCardPaddingHorizontal,
          _externalWorkCardBottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ExternalWorkAvatar(
                  isCompact: isCompact,
                  linked: project.linked,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    project.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  FormatUtils.date(project.minYmd),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: dateStyle,
                ),
              ],
            ),
            SizedBox(height: isCompact ? 10 : _externalWorkCardMetricTopGap),
            Row(
              children: [
                Expanded(
                  child: _ExternalWorkMetric(
                    label: '外协应付',
                    value: FormatUtils.money(project.payable),
                    valueStyle: metricValueStyle,
                    labelStyle: metricLabelStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ExternalWorkMetric(
                    label: '应收项目款',
                    value: '待设置',
                    valueStyle: pendingValueStyle,
                    labelStyle: metricLabelStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ExternalWorkMetric(
                    label: '毛利',
                    value: '待计算',
                    valueStyle: pendingValueStyle,
                    labelStyle: metricLabelStyle,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AccountTokens.projectCardProgressTopGap),
            _ExternalWorkPayableProgressBar(
              paidRatio: project.payablePaidRatio,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExternalWorkPayableProgressBar extends StatelessWidget {
  const _ExternalWorkPayableProgressBar({required this.paidRatio});

  final double paidRatio;

  @override
  Widget build(BuildContext context) {
    final unpaidRatio = (1 - paidRatio).clamp(0.0, 1.0).toDouble();
    final radius = BorderRadius.circular(
      AccountTokens.projectCardProgressRadius,
    );

    return SizedBox(
      height: AccountTokens.projectCardProgressHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          children: [
            Container(
              height: AccountTokens.projectCardProgressFillHeight,
              decoration: BoxDecoration(
                color: AccountTokens.overviewPieReceived,
                borderRadius: radius,
              ),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: unpaidRatio,
              child: Container(
                height: AccountTokens.projectCardProgressFillHeight,
                decoration: BoxDecoration(
                  color: AccountTokens.overviewPieRemaining,
                  borderRadius: radius,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExternalWorkAvatar extends StatelessWidget {
  const _ExternalWorkAvatar({required this.isCompact, this.linked = false});

  final bool isCompact;
  final bool linked;

  @override
  Widget build(BuildContext context) {
    final size = isCompact ? 30.0 : 34.0;
    final textStyle = AppTypography.sectionTitle(
      context,
      fontSize: isCompact ? 15 : 16,
      fontWeight: FontWeight.w700,
      height: 1,
      color: _externalWorkBadgeText,
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            key: _externalWorkAvatarKey,
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _externalWorkBadgeBg,
            ),
            child: Text('协', style: textStyle),
          ),
          if (linked)
            Positioned(
              right: -2,
              bottom: -2,
              child: LinkedExternalWorkBadge(
                key: const Key('account-external-work-card-link-badge'),
                borderColor: _externalWorkCardBg,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExternalWorkMetric extends StatelessWidget {
  const _ExternalWorkMetric({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: labelStyle,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: valueStyle,
        ),
      ],
    );
  }
}
