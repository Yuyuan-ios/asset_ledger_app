import 'package:flutter/material.dart';

import '../../../core/foundation/typography.dart';
import '../domain/entities/device.dart';
import '../domain/services/device_business_ledger.dart';
import '../domain/services/device_label.dart';
import '../domain/services/lifecycle_payback_calculator.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../patterns/device/device_action_section_pattern.dart';
import '../../../patterns/device/device_management_section_pattern.dart';
import '../../../patterns/device/device_section_group_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';
import 'device_page_action_sections.dart';
import 'device_business_ledger_section.dart';

class DevicePageSectionHandlers {
  const DevicePageSectionHandlers({
    required this.onOpenUpgradePage,
    required this.onOpenAccountCenter,
    required this.accountCenterSubtitle,
    required this.onOpenAddDeviceFlow,
    required this.onOpenRateApp,
    required this.onOpenTermsPage,
    required this.onOpenPrivacyPage,
    required this.onOpenContact,
    required this.onDeviceTap,
    required this.onDeviceLongPress,
    this.businessLedgers = const [],
    this.lifecyclePaybackAmountsFor,
    this.onOpenLifecyclePayback,
  });

  final VoidCallback onOpenUpgradePage;
  final VoidCallback onOpenAccountCenter;
  final String accountCenterSubtitle;
  final VoidCallback onOpenAddDeviceFlow;
  final VoidCallback onOpenRateApp;
  final VoidCallback onOpenTermsPage;
  final VoidCallback onOpenPrivacyPage;
  final VoidCallback onOpenContact;
  final ValueChanged<Device> onDeviceTap;
  final ValueChanged<Device> onDeviceLongPress;
  final List<DeviceBusinessLedger> businessLedgers;
  final LifecyclePaybackAmounts? Function(DeviceBusinessLedger ledger)?
  lifecyclePaybackAmountsFor;
  final ValueChanged<DeviceBusinessLedger>? onOpenLifecyclePayback;
}

List<Widget> buildDevicePageSections({
  required AppLocalizations l10n,
  required List<Device> devices,
  required DevicePageSectionHandlers handlers,
}) {
  final actionConfigs = buildDevicePageActionSectionConfigs(
    l10n: l10n,
    onOpenUpgradePage: handlers.onOpenUpgradePage,
    onOpenAddDeviceFlow: handlers.onOpenAddDeviceFlow,
    onOpenRateApp: handlers.onOpenRateApp,
    onOpenTermsPage: handlers.onOpenTermsPage,
    onOpenPrivacyPage: handlers.onOpenPrivacyPage,
    onOpenContact: handlers.onOpenContact,
    forwardIcon: Icons.chevron_right,
    externalIcon: Icons.north_east,
  );

  final sections = <Widget>[];
  for (final config in actionConfigs) {
    if (config.id == DevicePageActionSectionId.profile) {
      sections.add(_buildAccountSyncSection(l10n, handlers));
      continue;
    }

    sections.add(
      DeviceActionSection(
        title: config.title,
        items: config.items,
        padding: config.padding,
      ),
    );
    if (config.id == DevicePageActionSectionId.equipment) {
      sections.add(
        DeviceManagementSection(
          title: l10n.deviceManagementTitle,
          devices: devices,
          onDeviceTap: handlers.onDeviceTap,
          onDeviceLongPress: handlers.onDeviceLongPress,
          resolveIndexLabel: (device) => DeviceLabel.indexOnly(device.name),
        ),
      );
      sections.add(
        DeviceBusinessLedgerSection(
          ledgers: handlers.businessLedgers,
          amountsFor: handlers.lifecyclePaybackAmountsFor,
          onOpenLifecyclePayback: handlers.onOpenLifecyclePayback,
        ),
      );
    }
  }

  return _withSectionSpacing(sections);
}

List<Widget> _withSectionSpacing(List<Widget> sections) {
  if (sections.isEmpty) return const [];
  final widgets = <Widget>[const SizedBox(height: DeviceTokens.sectionTopGap)];
  for (var i = 0; i < sections.length; i++) {
    if (i > 0) {
      widgets.add(const SizedBox(height: DeviceTokens.sectionTopGap));
    }
    widgets.add(sections[i]);
  }
  return widgets;
}

Widget _buildAccountSyncSection(
  AppLocalizations l10n,
  DevicePageSectionHandlers handlers,
) {
  return DeviceSectionGroup(
    title: l10n.deviceAccountSyncSectionTitle,
    children: [
      _AccountCenterActionCard(
        title: l10n.deviceAccountCenterTitle,
        statusText: handlers.accountCenterSubtitle,
        onTap: handlers.onOpenAccountCenter,
      ),
    ],
  );
}

class _AccountCenterActionCard extends StatelessWidget {
  const _AccountCenterActionCard({
    required this.title,
    required this.statusText,
    required this.onTap,
  });

  final String title;
  final String statusText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trimmedStatus = statusText.trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DeviceActionCardTokens.radius),
      child: Container(
        height: DeviceActionCardTokens.height,
        decoration: BoxDecoration(
          color: DeviceTokens.actionCardBackgroundColor,
          borderRadius: BorderRadius.circular(DeviceActionCardTokens.radius),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DeviceActionCardTokens.horizontalPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  context,
                  fontSize: DeviceActionCardTokens.titleFontSize,
                  fontWeight: DeviceActionCardTokens.titleFontWeight,
                  color: DeviceTokens.actionCardTitleColor,
                ),
              ),
            ),
            if (trimmedStatus.isNotEmpty) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  trimmedStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppTypography.caption(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: DeviceTokens.actionCardTitleColor.withValues(
                      alpha: 0.56,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: DeviceActionCardTokens.trailingIconSize,
              color: DeviceTokens.actionCardTrailingIconColor,
            ),
          ],
        ),
      ),
    );
  }
}
