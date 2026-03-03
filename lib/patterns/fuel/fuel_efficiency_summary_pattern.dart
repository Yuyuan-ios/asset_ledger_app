import 'package:flutter/material.dart';

import '../../features/fuel/model/fuel_efficiency_agg.dart';
import '../../tokens/mapper/fuel_tokens.dart';
import '../../core/utils/format_utils.dart';

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
    String fmtRate(double? v, {required String suffix}) {
      if (v == null) return '--';
      return '${FormatUtils.meter(v)} $suffix';
    }

    Widget buildRow(int id) {
      final agg = byDevice[id]!;
      final name = deviceNameOf(id);
      final litersText = fmtRate(agg.litersPerHour, suffix: 'L/h');
      final costText = fmtRate(agg.costPerHour, suffix: '¥/h');
      return Padding(
        padding: const EdgeInsets.only(
          left: FuelTokens.efficiencyRowLeftInset,
          bottom: FuelTokens.summaryCardRowBottomGap,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: FuelTokens.summaryCardNameSize,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: FuelTokens.summaryLitersColumnWidth,
                  child: Text(
                    litersText,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: FuelTokens.summaryCardMetricSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: FuelTokens.summaryMetricColumnGap),
                SizedBox(
                  width: FuelTokens.summaryCostColumnWidth,
                  child: Text(
                    costText,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: FuelTokens.summaryCardMetricSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (byDevice.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '设备燃油效率',
            style: TextStyle(
              fontSize: FuelTokens.summaryCardTitleSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: FuelTokens.summaryCardItemGap),
          Expanded(child: Center(child: Text('暂无数据（先录入燃油记录与工时记录）'))),
        ],
      );
    }

    final ids = byDevice.keys.toList()
      ..sort((a, b) {
        final nameA = deviceNameOf(a);
        final nameB = deviceNameOf(b);
        final byLen = nameA.length.compareTo(nameB.length);
        if (byLen != 0) return byLen;
        return nameA.compareTo(nameB);
      });

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
        const Text(
          '设备燃油效率',
          style: TextStyle(
            fontSize: FuelTokens.summaryCardTitleSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: FuelTokens.summaryCardItemGap),
        Expanded(child: bodyChild),
      ],
    );
  }
}
