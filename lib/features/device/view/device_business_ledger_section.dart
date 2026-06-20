import 'package:flutter/material.dart';

import '../../../core/measure/measure_unit.dart';
import '../../../core/utils/format_utils.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../patterns/device/device_action_card_pattern.dart';
import '../../../patterns/device/device_section_group_pattern.dart';
import '../../../tokens/mapper/device_tokens.dart';
import '../domain/services/device_label.dart';
import '../domain/services/device_business_ledger.dart';
import '../domain/services/lifecycle_payback_calculator.dart';
import 'lifecycle_payback_card.dart';

class DeviceBusinessLedgerSection extends StatelessWidget {
  const DeviceBusinessLedgerSection({
    super.key,
    required this.ledgers,
    this.amountsFor,
    this.onOpenLifecyclePayback,
  });

  final List<DeviceBusinessLedger> ledgers;
  final LifecyclePaybackAmounts? Function(DeviceBusinessLedger ledger)?
  amountsFor;
  final ValueChanged<DeviceBusinessLedger>? onOpenLifecyclePayback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = ledgers
        .where((ledger) => ledger.projects.isNotEmpty || ledger.incomeFen > 0)
        .take(4)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return DeviceSectionGroup(
      title: l10n.deviceLedgerSectionTitle,
      padding: const EdgeInsets.symmetric(
        horizontal: DeviceTokens.sectionHorizontalInset,
      ),
      children: [
        for (final ledger in visible) ...[
          DeviceActionCard(
            title: _titleFor(l10n, ledger),
            subtitle: _subtitleFor(l10n, ledger),
            onTap: () {},
          ),
          LifecyclePaybackCard(
            deviceName: _titleFor(l10n, ledger),
            operatedHours: _operatedHours(ledger),
            operationItems: ledger.projects.length,
            initialCostFen: amountsFor?.call(ledger)?.initialCostFen,
            netReceivedFen: _netReceivedFen(ledger),
            estimatedResidualFen: amountsFor
                ?.call(ledger)
                ?.estimatedResidualFen,
            pendingReceivableFen: _pendingReceivableFen(ledger),
            onTap: () => onOpenLifecyclePayback?.call(ledger),
          ),
        ],
      ],
    );
  }

  String _titleFor(AppLocalizations l10n, DeviceBusinessLedger ledger) {
    if (ledger.deviceIsActive) return ledger.deviceName;
    return DeviceLabel.replaceIndexLabel(
      ledger.deviceName,
      l10n.deviceInactiveIndexLabel,
    );
  }

  String _subtitleFor(AppLocalizations l10n, DeviceBusinessLedger ledger) {
    final income = FormatUtils.money(ledger.incomeFen / 100);
    final work = _unitSummary(l10n, ledger.unitTotals);
    final projectCount = ledger.projects.length;
    final pendingFen = ledger.projects.fold<int>(
      0,
      (sum, project) =>
          sum + (project.remainingFen > 0 ? project.remainingFen : 0),
    );
    final pending = pendingFen <= 0
        ? l10n.deviceLedgerPaidFull
        : l10n.deviceLedgerPendingAmount(FormatUtils.money(pendingFen / 100));
    return l10n.deviceLedgerSubtitle(income, work, projectCount, pending);
  }

  int _netReceivedFen(DeviceBusinessLedger ledger) {
    final receivedFen = ledger.projects.fold<int>(
      0,
      (sum, project) => sum + project.receivedFen,
    );
    if (ledger.projects.isNotEmpty || receivedFen != 0) return receivedFen;
    return ledger.incomeFen;
  }

  int _pendingReceivableFen(DeviceBusinessLedger ledger) {
    return ledger.projects.fold<int>(
      0,
      (sum, project) =>
          sum + (project.remainingFen > 0 ? project.remainingFen : 0),
    );
  }

  double _operatedHours(DeviceBusinessLedger ledger) {
    final hourTotal = ledger.unitTotals
        .where((total) => total.unit == MeasureUnit.hour)
        .fold<int>(0, (sum, total) => sum + total.quantityScaled);
    return hourTotal / 1000;
  }

  String _unitSummary(
    AppLocalizations l10n,
    List<DeviceBusinessUnitTotal> totals,
  ) {
    if (totals.isEmpty) return l10n.deviceLedgerNoWork;
    return totals
        .take(3)
        .map((total) {
          return '${_quantityText(total.quantityScaled)}${_unitLabel(l10n, total.unit)}';
        })
        .join(l10n.deviceListSeparator);
  }

  String _quantityText(int quantityScaled) {
    final value = quantityScaled / 1000;
    if (quantityScaled % 1000 == 0) return value.toStringAsFixed(0);
    if (quantityScaled % 100 == 0) return value.toStringAsFixed(1);
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }

  String _unitLabel(AppLocalizations l10n, MeasureUnit unit) {
    switch (unit) {
      case MeasureUnit.hour:
        return l10n.deviceUnitHour;
      case MeasureUnit.shift:
        return l10n.deviceUnitShift;
      case MeasureUnit.day:
        return l10n.deviceUnitDay;
      case MeasureUnit.rent:
        return l10n.deviceUnitRent;
      case MeasureUnit.mu:
        return l10n.deviceUnitMu;
      case MeasureUnit.acre:
        return l10n.deviceUnitAcre;
      case MeasureUnit.hectare:
        return l10n.deviceUnitHectare;
      case MeasureUnit.ton:
        return l10n.deviceUnitTon;
      case MeasureUnit.cubicMeter:
        return l10n.deviceUnitCubicMeter;
      case MeasureUnit.trip:
        return l10n.deviceUnitTrip;
      case MeasureUnit.sortie:
        return l10n.deviceUnitSortie;
      case MeasureUnit.task:
        return l10n.deviceUnitTask;
    }
  }
}
