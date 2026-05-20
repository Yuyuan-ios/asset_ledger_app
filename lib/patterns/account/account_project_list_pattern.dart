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
    this.isCompact = false,
  });

  final List<AccountProjectVM> projects;
  final ValueChanged<AccountProjectVM> onTap;
  final bool isCompact;

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

  String _settlementStatusText(AccountProjectVM p, {required bool compact}) {
    if (_isSettled(p)) {
      return '已结清';
    }
    return compact
        ? '待收 ${FormatUtils.money(p.remaining)}'
        : '余: ${FormatUtils.money(p.remaining)} / ${FormatUtils.money(p.receivable)}';
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

    if (projects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('暂无项目（计时页有记录后将自动出现）', style: emptyStyle)),
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
                                child: Text(
                                  isCompact
                                      ? _settlementStatusText(p, compact: true)
                                      : _settlementStatusText(
                                          p,
                                          compact: false,
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: resolvedStatusStyle,
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
                                  widthFactor: (p.ratio ?? 0).clamp(0, 1),
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
      ],
    );
  }
}
