import 'package:flutter/material.dart';

import '../../features/fuel/model/fuel_efficiency_agg.dart';
import '../../core/utils/format_utils.dart';
import '../../core/foundation/typography.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../tokens/mapper/account_tokens.dart';
import '../../tokens/mapper/fuel_tokens.dart';
import '../../tokens/mapper/radius_tokens.dart';
import '../../tokens/mapper/summary_card_tokens.dart';

class FuelEfficiencySummary extends StatelessWidget {
  final Map<int, FuelEfficiencyAgg> byDevice;
  final String Function(int deviceId) deviceNameOf;

  const FuelEfficiencySummary({
    super.key,
    required this.byDevice,
    required this.deviceNameOf,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titleStyle = AppTypography.body(
      context,
      fontSize: SummaryCardTokens.titleFontSize,
      fontWeight: FontWeight.w800,
      color: Colors.black,
    );
    final nameStyle = AppTypography.body(
      context,
      fontSize: SummaryCardTokens.rowLabelFontSize,
      color: Colors.black,
    );
    final metricStyle = AppTypography.body(
      context,
      fontSize: SummaryCardTokens.rowValueFontSize,
      fontWeight: FontWeight.w400,
      color: Colors.black,
    );
    final emptyStyle = AppTypography.bodySecondary(
      context,
      color: Colors.black.withValues(alpha: 0.7),
    );

    String fmtRate(double? v, {required String suffix}) {
      if (v == null) return '--';
      return '${FormatUtils.meter(v)} $suffix';
    }

    final ids = byDevice.keys.toList()
      ..sort((a, b) {
        final nameA = deviceNameOf(a);
        final nameB = deviceNameOf(b);
        final byLen = nameA.length.compareTo(nameB.length);
        if (byLen != 0) return byLen;
        return nameA.compareTo(nameB);
      });
    final colorById = <int, Color>{
      for (var i = 0; i < ids.length; i++)
        ids[i]:
            AccountTokens.overviewChartPalette[i %
                AccountTokens.overviewChartPalette.length],
    };

    Widget buildRow(int id) {
      final agg = byDevice[id]!;
      final name = deviceNameOf(id);
      final markerColor = colorById[id] ?? Colors.grey;
      final totalTimingText = FormatUtils.hours(agg.totalTimingHours);
      final litersText = fmtRate(agg.litersPerHour, suffix: 'L/h');
      final costText = fmtRate(agg.costPerHour, suffix: '¥/h');
      return Padding(
        padding: const EdgeInsets.only(
          left: SummaryCardTokens.rowLeftInset,
          bottom: SummaryCardTokens.rowBottomGap,
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: markerColor,
                      borderRadius: BorderRadius.circular(
                        RadiusTokens.decoration,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: FuelTokens.summaryHoursColumnWidth,
                  child: Text(
                    totalTimingText,
                    textAlign: TextAlign.right,
                    style: metricStyle,
                  ),
                ),
                const SizedBox(width: FuelTokens.summaryMetricColumnGap),
                SizedBox(
                  width: FuelTokens.summaryLitersColumnWidth,
                  child: Text(
                    litersText,
                    textAlign: TextAlign.right,
                    style: metricStyle,
                  ),
                ),
                const SizedBox(width: FuelTokens.summaryMetricColumnGap),
                SizedBox(
                  width: FuelTokens.summaryCostColumnWidth,
                  child: Text(
                    costText,
                    textAlign: TextAlign.right,
                    style: metricStyle,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (byDevice.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.fuelEfficiencyTitle, style: titleStyle),
          const SizedBox(height: SummaryCardTokens.titleToContentGap),
          Expanded(
            child: Center(
              child: Text(l10n.fuelEfficiencyEmpty, style: emptyStyle),
            ),
          ),
        ],
      );
    }

    final bodyChild = ids.length == 1
        ? Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(
                top: FuelTokens.efficiencySingleItemTitleGap,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ids.map(buildRow).toList(),
              ),
            ),
          )
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: FuelTokens.efficiencyListBottomPadding,
              ),
              child: Column(children: ids.map(buildRow).toList()),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.fuelEfficiencyTitle, style: titleStyle),
        const SizedBox(height: SummaryCardTokens.titleToContentGap),
        Expanded(child: bodyChild),
      ],
    );
  }
}
