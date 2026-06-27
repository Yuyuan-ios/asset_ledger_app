import 'package:flutter/material.dart';
import '../../core/foundation/typography.dart';
import '../../features/timing/model/timing_chart_data.dart';
import '../../l10n/gen/app_localizations.dart';
import '../layout/phone_page_layout.dart';
import '../layout/summary_card_surface.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

class CardMainChart extends StatelessWidget {
  const CardMainChart({
    super.key,
    required this.data,
    this.onPrevYear,
    this.onNextYear,
    this.canGoPrevYear = true,
    this.canGoNextYear = true,
  });

  final TimingChartData data;
  final VoidCallback? onPrevYear;
  final VoidCallback? onNextYear;
  final bool canGoPrevYear;
  final bool canGoNextYear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final arrowStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.chartArrowFontSize,
      color: TimingColors.arrow,
      height: 1,
    );
    final yearStyle = AppTypography.body(
      context,
      fontSize: TimingTokens.chartYearFontSize,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    );
    final monthStyle = AppTypography.caption(
      context,
      fontSize: TimingTokens.chartMonthFontSize,
      fontWeight: FontWeight.w300,
      color: AppColors.textPrimary,
      height: 1,
    );

    final baseChartContentWidth =
        TimingTokens.homeFixedContentWidth -
        (TimingTokens.homePageHorizontalPadding * 2) -
        TimingTokens.chartPaddingLeft -
        TimingTokens.chartPaddingRight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth =
            constraints.maxWidth -
            TimingTokens.chartPaddingLeft -
            TimingTokens.chartPaddingRight;
        final maxChartContentWidth = PhonePageLayout.resolveMaxContentWidth(
          innerWidth,
          baseWidth: baseChartContentWidth,
          maxWideGain: 14,
          wideGrowthFactor: 0.35,
        );

        return SummaryCardSurface(
          height: TimingTokens.chartCardHeight,
          padding: const EdgeInsets.fromLTRB(
            TimingTokens.chartPaddingLeft,
            TimingTokens.chartPaddingTop,
            TimingTokens.chartPaddingRight,
            TimingTokens.chartPaddingBottom,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxChartContentWidth),
              child: Column(
                children: [
                  SizedBox(
                    height: TimingTokens.chartHeaderHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: canGoPrevYear ? onPrevYear : null,
                          child: Text('<', style: arrowStyle),
                        ),
                        Text(
                          l10n.timingChartYearLabel(data.year),
                          style: yearStyle,
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: canGoNextYear ? onNextYear : null,
                          child: Text(
                            '>',
                            style: AppTypography.body(
                              context,
                              fontSize: TimingTokens.chartArrowFontSize,
                              height: 1,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: TimingTokens.chartDividerThickness,
                    thickness: TimingTokens.chartDividerThickness,
                    color: TimingColors.divider,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: TimingTokens.chartPlotTopPadding,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(data.monthLabels.length, (
                                index,
                              ) {
                                return Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            width: TimingTokens.chartBarWidth,
                                            height: data.incomeBars[index],
                                            color: TimingColors.chartIncome,
                                          ),
                                          const SizedBox(
                                            width: TimingTokens.chartBarPairGap,
                                          ),
                                          Container(
                                            width: TimingTokens.chartBarWidth,
                                            height: data.expenseBars[index],
                                            color: TimingColors.expense,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                        height: TimingTokens.chartMonthTopGap,
                                      ),
                                      Text(
                                        data.monthLabels[index],
                                        style: monthStyle,
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(
                            height: TimingTokens.chartLegendTopGap,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Legend(
                                  label: l10n.timingChartIncomeLegend,
                                  swatchColor: TimingColors.chartIncome,
                                  valueLabel:
                                      l10n.timingChartNetIncomeValueLabel,
                                  value: data.netIncomeText,
                                ),
                                const SizedBox(
                                  width: TimingTokens.chartLegendGap,
                                ),
                                _Legend(
                                  label: l10n.timingChartExpenseLabel,
                                  swatchColor: TimingColors.expense,
                                  valueLabel: l10n.timingChartExpenseLabel,
                                  value: data.totalExpenseText,
                                ),
                              ],
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
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color swatchColor;
  final String valueLabel;
  final String value;

  const _Legend({
    required this.label,
    required this.swatchColor,
    required this.valueLabel,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTypography.caption(
      context,
      fontSize: TimingTokens.chartLegendLabelFontSize,
      color: AppColors.textPrimary,
      height: 1,
    );
    final valueStyle = AppTypography.caption(
      context,
      fontSize: TimingTokens.chartLegendValueFontSize,
      color: AppColors.textPrimary,
      height: 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: TimingTokens.chartLegendSwatchSize,
              height: TimingTokens.chartLegendSwatchSize,
              color: swatchColor,
            ),
            const SizedBox(width: TimingTokens.chartLegendLabelGap),
            Text(label, style: labelStyle),
          ],
        ),
        const SizedBox(height: TimingTokens.chartLegendValueTopGap),
        Text('$valueLabel$value', style: valueStyle),
      ],
    );
  }
}
