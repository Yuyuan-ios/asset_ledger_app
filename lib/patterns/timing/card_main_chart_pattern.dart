import 'package:flutter/material.dart';
import '../../tokens/mapper/core_tokens.dart';
import '../../tokens/mapper/timing_tokens.dart';

class CardMainChart extends StatelessWidget {
  const CardMainChart({super.key});

  @override
  Widget build(BuildContext context) {
    const months = [
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月',
    ];
    const incomeBars = [
      150.0,
      150.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
    ];
    const expenseBars = [
      15.0,
      75.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
    ];

    return Container(
      height: TimingTokens.chartCardHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: SheetColors.background,
        borderRadius: BorderRadius.circular(TimingTokens.chartCardRadius),
        border: Border.all(
          color: TimingColors.cardBorder,
          width: TimingTokens.chartCardBorderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TimingTokens.chartPaddingLeft,
          TimingTokens.chartPaddingTop,
          TimingTokens.chartPaddingRight,
          TimingTokens.chartPaddingBottom,
        ),
        child: Column(
          children: [
            const SizedBox(
              height: TimingTokens.chartHeaderHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '<',
                    style: TextStyle(
                      fontSize: TimingTokens.chartArrowFontSize,
                      height: 1,
                      color: TimingColors.arrow,
                    ),
                  ),
                  Text(
                    '2026年',
                    style: TextStyle(
                      fontSize: TimingTokens.chartYearFontSize,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '>',
                    style: TextStyle(
                      fontSize: TimingTokens.chartArrowFontSize,
                      height: 1,
                      color: AppColors.textPrimary,
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
                        children: List.generate(months.length, (index) {
                          return Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: TimingTokens.chartBarWidth,
                                      height: incomeBars[index],
                                      color: TimingColors.chartIncome,
                                    ),
                                    const SizedBox(
                                      width: TimingTokens.chartBarPairGap,
                                    ),
                                    Container(
                                      width: TimingTokens.chartBarWidth,
                                      height: expenseBars[index],
                                      color: TimingColors.expense,
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: TimingTokens.chartMonthTopGap,
                                ),
                                Text(
                                  months[index],
                                  style: const TextStyle(
                                    fontSize: TimingTokens.chartMonthFontSize,
                                    height: 1,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: TimingTokens.chartLegendTopGap),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Legend(
                            label: '收入',
                            swatchColor: TimingColors.chartIncome,
                            value: '￥1000000',
                          ),
                          SizedBox(width: TimingTokens.chartLegendGap),
                          _Legend(
                            label: '支出',
                            swatchColor: TimingColors.expense,
                            value: '￥500000',
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
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color swatchColor;
  final String value;

  const _Legend({
    required this.label,
    required this.swatchColor,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
            Text(
              label,
              style: const TextStyle(
                fontSize: TimingTokens.chartLegendLabelFontSize,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: TimingTokens.chartLegendValueTopGap),
        Text(
          value,
          style: const TextStyle(
            fontSize: TimingTokens.chartLegendValueFontSize,
            color: AppColors.textPrimary,
            height: 1,
          ),
        ),
      ],
    );
  }
}
