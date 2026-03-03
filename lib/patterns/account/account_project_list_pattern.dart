import 'package:flutter/material.dart';

import '../../core/utils/format_utils.dart';
import '../../features/account/state/account_store.dart';
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
    if (rate == null) return '单价：—';
    return p.isMultiDevice
        ? '单价：${FormatUtils.money(rate)}(多设备)'
        : '单价：${FormatUtils.money(rate)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final emptyStyle = textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      color: TimingColors.textSecondary,
    );
    final titleStyle = textTheme.titleMedium?.copyWith(
      fontSize: AccountTokens.projectCardTitleFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: Colors.black,
    );
    final dateStyle = textTheme.bodyMedium?.copyWith(
      fontSize: AccountTokens.projectCardDateFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: Colors.black.withValues(alpha: 0.9),
    );
    final chipStyle = textTheme.bodyMedium?.copyWith(
      fontSize: AccountTokens.projectCardChipFontSize,
      fontWeight: FontWeight.w400,
      height: 1,
      color: Colors.black,
    );
    final statusStyle = textTheme.bodyMedium?.copyWith(
      fontSize: AccountTokens.projectCardStatusFontSize,
      fontWeight: FontWeight.w400,
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
          Container(
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
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(
                AccountTokens.projectCardRadius,
              ),
              onTap: () => onTap(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AccountTokens.projectCardPaddingHorizontal,
                  vertical: AccountTokens.projectCardPaddingVertical,
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
                    const SizedBox(height: AccountTokens.projectCardSectionGap),
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: AccountTokens.projectCardChipWidth,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal:
                            AccountTokens.projectCardChipPaddingHorizontal,
                        vertical: AccountTokens.projectCardChipPaddingVertical,
                      ),
                      decoration: BoxDecoration(
                        color: AccountTokens.projectCardChipColor,
                        borderRadius: BorderRadius.circular(
                          AccountTokens.projectCardChipRadius,
                        ),
                      ),
                      child: Text(_priceText(p), style: chipStyle),
                    ),
                    const SizedBox(
                      height: AccountTokens.projectCardRateToStatusGap,
                    ),
                    Row(
                      children: [
                        Text(
                          '${FormatUtils.percent1(p.ratio)}实收',
                          style: statusStyle,
                        ),
                        const Spacer(),
                        Text(
                          '余: ${FormatUtils.money(p.remaining)} / ${FormatUtils.money(p.receivable)}',
                          style: statusStyle,
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
                              height:
                                  AccountTokens.projectCardProgressFillHeight,
                              decoration: BoxDecoration(
                                color: AccountTokens.projectCardProgressTrack,
                                borderRadius: BorderRadius.circular(
                                  AccountTokens.projectCardProgressRadius,
                                ),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (p.ratio ?? 0).clamp(0, 1),
                              child: Container(
                                height:
                                    AccountTokens.projectCardProgressFillHeight,
                                decoration: BoxDecoration(
                                  color: AccountTokens.projectCardProgressFill,
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
          ),
        ],
      ],
    );
  }
}
