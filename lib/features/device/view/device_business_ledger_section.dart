import 'package:flutter/material.dart';

import '../../../core/measure/measure_unit.dart';
import '../../../core/utils/format_utils.dart';
import '../../../patterns/device/device_action_card_pattern.dart';
import '../../../patterns/device/device_section_group_pattern.dart';
import '../../../tokens/mapper/device_tokens.dart';
import '../domain/services/device_business_ledger.dart';

class DeviceBusinessLedgerSection extends StatelessWidget {
  const DeviceBusinessLedgerSection({super.key, required this.ledgers});

  final List<DeviceBusinessLedger> ledgers;

  @override
  Widget build(BuildContext context) {
    final visible = ledgers
        .where((ledger) => ledger.projects.isNotEmpty || ledger.incomeFen > 0)
        .take(4)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return DeviceSectionGroup(
      title: '设备经营',
      padding: const EdgeInsets.symmetric(
        horizontal: DeviceTokens.sectionHorizontalInset,
      ),
      children: [
        for (final ledger in visible)
          DeviceActionCard(
            title: ledger.deviceName,
            subtitle: _subtitleFor(ledger),
            onTap: () {},
          ),
      ],
    );
  }

  String _subtitleFor(DeviceBusinessLedger ledger) {
    final income = FormatUtils.money(ledger.incomeFen / 100);
    final work = _unitSummary(ledger.unitTotals);
    final projectCount = ledger.projects.length;
    final pendingFen = ledger.projects.fold<int>(
      0,
      (sum, project) =>
          sum + (project.remainingFen > 0 ? project.remainingFen : 0),
    );
    final pending = pendingFen <= 0
        ? '已收齐'
        : '待收 ${FormatUtils.money(pendingFen / 100)}';
    return '收入 $income · $work\n$projectCount 项 · $pending';
  }

  String _unitSummary(List<DeviceBusinessUnitTotal> totals) {
    if (totals.isEmpty) return '暂无工作量';
    return totals
        .take(3)
        .map((total) {
          return '${_quantityText(total.quantityScaled)}${_unitLabel(total.unit)}';
        })
        .join('、');
  }

  String _quantityText(int quantityScaled) {
    final value = quantityScaled / 1000;
    if (quantityScaled % 1000 == 0) return value.toStringAsFixed(0);
    if (quantityScaled % 100 == 0) return value.toStringAsFixed(1);
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }

  String _unitLabel(MeasureUnit unit) {
    switch (unit) {
      case MeasureUnit.hour:
        return '小时';
      case MeasureUnit.shift:
        return '台班';
      case MeasureUnit.day:
        return '天';
      case MeasureUnit.rent:
        return '租期';
      case MeasureUnit.mu:
        return '亩';
      case MeasureUnit.acre:
        return '英亩';
      case MeasureUnit.hectare:
        return '公顷';
      case MeasureUnit.ton:
        return '吨';
      case MeasureUnit.cubicMeter:
        return '方';
      case MeasureUnit.trip:
        return '趟';
      case MeasureUnit.sortie:
        return '架次';
      case MeasureUnit.task:
        return '任务';
    }
  }
}
