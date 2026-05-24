import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../core/utils/format_utils.dart';
import '../../features/account/model/account_view_model.dart';
import '../../tokens/mapper/account_tokens.dart';
import '../../tokens/mapper/color_tokens.dart';

enum _PriceBadgeKind { single, multi, rent }

const double _projectCardMoneyEpsilon = 0.000001;
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
const Key _externalWorkAvatarKey = Key('account-external-work-avatar');
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
    this.emptyText = '暂无项目（计时页有记录后将自动出现）',
  });

  final List<AccountProjectVM> projects;
  final List<AccountExternalWorkProjectVM> externalWorkProjects;
  final ValueChanged<AccountProjectVM> onTap;
  final bool isCompact;
  final String emptyText;

  String _priceText(AccountProjectVM p) {
    final rate = p.minRate;
    if (rate == null) {
      if (p.rentIncomeTotal > 0) return '租金(台班)';
      return '单价:—';
    }
    if (p.isMultiDevice) {
      return '单价:${FormatUtils.money(rate)}(多设备)';
    }
    if (p.isMultiMode) {
      return '单价:${FormatUtils.money(rate)}起(多模式)';
    }
    return '单价:${FormatUtils.money(rate)}';
  }

  _PriceBadgeKind _priceBadgeKind(AccountProjectVM p, String priceText) {
    if (p.rentIncomeTotal > 0 ||
        priceText.contains('租金') ||
        priceText.contains('台班')) {
      return _PriceBadgeKind.rent;
    }

    if (p.isMultiDevice ||
        p.isMultiMode ||
        priceText.contains('起') ||
        priceText.contains('多设备') ||
        priceText.contains('多模式') ||
        priceText.contains('多单价')) {
      return _PriceBadgeKind.multi;
    }

    return _PriceBadgeKind.single;
  }

  _PriceBadgeStyle _priceBadgeStyle(_PriceBadgeKind kind) {
    switch (kind) {
      case _PriceBadgeKind.rent:
        return const _PriceBadgeStyle(
          backgroundColor: AccountTokens.projectCardRentBadgeBackground,
          borderColor: AccountTokens.projectCardRentBadgeBorder,
          textColor: AccountTokens.projectCardRentBadgeText,
        );
      case _PriceBadgeKind.multi:
        return const _PriceBadgeStyle(
          backgroundColor: AccountTokens.projectCardMultiRateBadgeBackground,
          borderColor: AccountTokens.projectCardMultiRateBadgeBorder,
          textColor: AccountTokens.projectCardMultiRateBadgeText,
        );
      case _PriceBadgeKind.single:
        return const _PriceBadgeStyle(
          backgroundColor: AccountTokens.projectCardSingleRateBadgeBackground,
          borderColor: AccountTokens.projectCardSingleRateBadgeBorder,
          textColor: AccountTokens.projectCardSingleRateBadgeText,
        );
    }
  }

  String? _totalHoursText(AccountProjectVM p) {
    final total = p.hoursByDevice.values.fold<double>(0, (sum, h) => sum + h);
    if (total <= 0) return null;
    final one = total.toStringAsFixed(1);
    final normalized = one.endsWith('.0')
        ? one.substring(0, one.length - 2)
        : one;
    return '总共:  $normalized h';
  }

  String _receivedBaseText(AccountProjectVM p, {required bool compact}) {
    if (_isSettled(p)) {
      if (p.writeOff > _projectCardMoneyEpsilon) {
        if (compact) {
          final netReceived = (p.receivable - p.writeOff).clamp(
            0.0,
            p.receivable,
          );
          return '实收 ${FormatUtils.money(netReceived)}';
        }
        return '总额 ${FormatUtils.money(p.receivable)}-核销 ${FormatUtils.money(p.writeOff)}';
      }
      return '总额 ${FormatUtils.money(p.receivable)}';
    }
    return '${FormatUtils.percent1(p.ratio)}实收';
  }

  Widget _receivedText(
    AccountProjectVM p,
    TextStyle? style, {
    required bool compact,
  }) {
    final base = _receivedBaseText(p, compact: compact);
    final sitesSuffix = !_isSettled(p) && p.kind == AccountProjectKind.merged
        ? _mergedSitesSuffix(p.includedSites)
        : '';
    if (sitesSuffix.isEmpty) {
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

  String _mergedSitesSuffix(List<String> includedSites) {
    final effectiveSites = includedSites
        .map((site) => site.trim())
        .where((site) => site.isNotEmpty)
        .toList();
    final joined = effectiveSites.join('+');
    if (joined.isEmpty) return '';

    const maxPrefixLength = AccountTokens.projectCardMergedSitesPreviewMaxChars;
    if (joined.length <= maxPrefixLength) return joined;
    return '${joined.substring(0, maxPrefixLength)}...';
  }

  bool _isSettled(AccountProjectVM p) {
    return p.receivable > _projectCardMoneyEpsilon &&
        p.remaining <= _projectCardMoneyEpsilon;
  }

  double _displayProgress(AccountProjectVM p, {required bool compact}) {
    if (_isSettled(p)) return 1.0;
    return (p.ratio ?? 0).clamp(0.0, 1.0).toDouble();
  }

  String _settlementStatusText(AccountProjectVM p, {required bool compact}) {
    if (_isSettled(p)) {
      return '已结清';
    }
    return compact
        ? '待收 ${FormatUtils.money(p.remaining)}'
        : '余: ${FormatUtils.money(p.remaining)} / ${FormatUtils.money(p.receivable)}';
  }

  Widget _settlementStatus(
    AccountProjectVM p,
    TextStyle? style, {
    required bool compact,
  }) {
    final text = _settlementStatusText(p, compact: compact);
    if (!_isSettled(p)) {
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

  @override
  Widget build(BuildContext context) {
    final emptyStyle = AppTypography.bodySecondary(
      context,
      fontSize: 14,
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
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(emptyText, style: emptyStyle)),
      );
    }

    return Column(
      children: [
        for (final p in projects) ...[
          Builder(
            builder: (context) {
              final totalHoursText = _totalHoursText(p);
              final priceText = _priceText(p);
              final badgeStyle = _priceBadgeStyle(
                _priceBadgeKind(p, priceText),
              );
              final isSettled = _isSettled(p);
              final displayProgress = _displayProgress(p, compact: isCompact);
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
                                      p.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: titleStyle,
                                    ),
                                  ),
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
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  isCompact
                                      ? '项目总额 ${FormatUtils.money(p.receivable)}'
                                      : FormatUtils.date(p.minYmd),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: dateStyle,
                                ),
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
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      totalHoursText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      textAlign: TextAlign.right,
                                      style: totalHoursStyle,
                                    ),
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
                              child: _receivedText(
                                p,
                                resolvedStatusStyle,
                                compact: isCompact,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _settlementStatus(
                                  p,
                                  resolvedStatusStyle,
                                  compact: isCompact,
                                ),
                              ),
                            ),
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
              child: Container(
                key: const Key('account-external-work-card-link-badge'),
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: _externalWorkValueText,
                  shape: BoxShape.circle,
                  border: Border.all(color: _externalWorkCardBg, width: 2),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.link, size: 9, color: Colors.white),
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
