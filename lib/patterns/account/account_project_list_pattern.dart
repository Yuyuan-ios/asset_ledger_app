import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../core/utils/format_utils.dart';
import '../../features/account/model/account_view_model.dart';
import '../../tokens/mapper/account_tokens.dart';
import '../../tokens/mapper/color_tokens.dart';

class AccountProjectList extends StatelessWidget {
  const AccountProjectList({
    super.key,
    required this.projects,
    required this.onTap,
  });

  final List<AccountProjectVM> projects;
  final ValueChanged<AccountProjectVM> onTap;

  String _priceText(AccountProjectVM p) {
    final rate = p.minRate;
    if (rate == null) {
      if (p.rentIncomeTotal > 0) return '租金(台班)';
      return '单价：—';
    }
    if (p.isMultiDevice) {
      return '单价：${FormatUtils.money(rate)}起(多设备)';
    }
    if (p.isMultiMode) {
      return '单价：${FormatUtils.money(rate)}起(多模式)';
    }
    return '单价：${FormatUtils.money(rate)}';
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

  String _receivedBaseText(AccountProjectVM p) {
    return '${FormatUtils.percent1(p.ratio)}实收';
  }

  Widget _receivedText(AccountProjectVM p, TextStyle? style) {
    final base = _receivedBaseText(p);
    final sitesSuffix = p.kind == AccountProjectKind.merged
        ? _mergedSitesSuffix(p.includedSites)
        : '';
    if (sitesSuffix.isEmpty) {
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

    final maxPrefixLength = '家里+成都+鲜滩+'.length;
    if (joined.length <= maxPrefixLength) return joined;
    return '${joined.substring(0, maxPrefixLength)}...';
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
              return Container(
                margin: const EdgeInsets.only(
                  bottom: AccountTokens.projectCardBottomMargin,
                ),
                constraints: const BoxConstraints(
                  minHeight: AccountTokens.projectCardMinHeight,
                ),
                decoration: BoxDecoration(
                  color: SheetColors.background,
                  border: Border.all(
                    color: AccountTokens.projectCardBorderColor,
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
                    padding: const EdgeInsets.only(
                      left: AccountTokens.projectCardPaddingHorizontal,
                      right: AccountTokens.projectCardPaddingHorizontal,
                      top: AccountTokens.projectCardPaddingTop,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                p.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                            ),
                            const SizedBox(
                              width: AccountTokens.projectCardTitleDateGap,
                            ),
                            Text(FormatUtils.date(p.minYmd), style: dateStyle),
                          ],
                        ),
                        const SizedBox(
                          height: AccountTokens.projectCardSectionGap,
                        ),
                        Row(
                          children: [
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: AccountTokens.projectCardChipWidth,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AccountTokens
                                    .projectCardChipPaddingHorizontal,
                                vertical: AccountTokens
                                    .projectCardChipPaddingVertical,
                              ),
                              decoration: BoxDecoration(
                                color: AccountTokens.projectCardChipColor,
                                borderRadius: BorderRadius.circular(
                                  AccountTokens.projectCardChipRadius,
                                ),
                              ),
                              child: Text(_priceText(p), style: chipStyle),
                            ),
                            if (totalHoursText != null) ...[
                              const Spacer(),
                              Text(totalHoursText, style: totalHoursStyle),
                            ],
                          ],
                        ),
                        const SizedBox(
                          height: AccountTokens.projectCardRateToStatusGap,
                        ),
                        Row(
                          children: [
                            Expanded(child: _receivedText(p, statusStyle)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '余: ${FormatUtils.money(p.remaining)} / ${FormatUtils.money(p.receivable)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: statusStyle,
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
