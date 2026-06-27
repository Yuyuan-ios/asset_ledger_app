import 'package:flutter/material.dart';

import '../../../core/measure/measure_unit.dart';
import '../../../l10n/gen/app_localizations.dart';
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
          LifecyclePaybackCard(
            deviceName: _titleFor(l10n, ledger),
            operatedHours: _operatedHours(ledger),
            operationItems: ledger.projects.length,
            initialCostFen: amountsFor?.call(ledger)?.initialCostFen,
            netReceivedFen: lifecyclePaybackNetReceivedFen(ledger),
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
}
