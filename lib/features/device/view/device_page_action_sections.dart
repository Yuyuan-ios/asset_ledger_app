import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../patterns/device/device_action_section_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';

enum DevicePageActionSectionId { profile, equipment, rating, terms, contact }

class DevicePageActionSectionConfig {
  const DevicePageActionSectionConfig({
    required this.id,
    required this.title,
    required this.items,
    this.padding = EdgeInsets.zero,
  });

  final DevicePageActionSectionId id;
  final String title;
  final List<DeviceActionItemConfig> items;
  final EdgeInsetsGeometry padding;
}

List<DevicePageActionSectionConfig> buildDevicePageActionSectionConfigs({
  required AppLocalizations l10n,
  required VoidCallback onOpenUpgradePage,
  required VoidCallback onOpenAddDeviceFlow,
  required VoidCallback onOpenRateApp,
  required VoidCallback onOpenTermsPage,
  required VoidCallback onOpenPrivacyPage,
  required VoidCallback onOpenContact,
  required IconData forwardIcon,
  required IconData externalIcon,
}) {
  return [
    DevicePageActionSectionConfig(
      id: DevicePageActionSectionId.profile,
      title: l10n.deviceProfileSectionTitle,
      items: [
        DeviceActionItemConfig(
          leading: Container(
            width: DeviceActionCardTokens.premiumBadgeSize,
            height: DeviceActionCardTokens.premiumBadgeSize,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(
                DeviceActionCardTokens.premiumBadgeRadius,
              ),
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.white,
              size: DeviceActionCardTokens.premiumBadgeIconSize,
            ),
          ),
          title: l10n.deviceUpgradeNowTitle,
          onTap: onOpenUpgradePage,
          trailingIcon: forwardIcon,
        ),
      ],
    ),
    DevicePageActionSectionConfig(
      id: DevicePageActionSectionId.equipment,
      title: l10n.deviceEquipmentSectionTitle,
      padding: const EdgeInsets.symmetric(
        horizontal: DeviceTokens.sectionHorizontalInset,
      ),
      items: [
        DeviceActionItemConfig(
          leading: const Icon(
            Icons.settings,
            size: DeviceActionCardTokens.addDeviceLeadingIconSize,
            color: Colors.black87,
          ),
          title: l10n.deviceAddDeviceAction,
          onTap: onOpenAddDeviceFlow,
          trailingIcon: forwardIcon,
        ),
      ],
    ),
    DevicePageActionSectionConfig(
      id: DevicePageActionSectionId.rating,
      title: l10n.deviceRateUsSectionTitle,
      items: [
        DeviceActionItemConfig(
          title: l10n.deviceRateAppAction,
          onTap: onOpenRateApp,
          trailingIcon: externalIcon,
        ),
      ],
    ),
    DevicePageActionSectionConfig(
      id: DevicePageActionSectionId.terms,
      title: l10n.deviceTermsSectionTitle,
      items: [
        DeviceActionItemConfig(
          title: l10n.deviceTermsTitle,
          onTap: onOpenTermsPage,
          trailingIcon: externalIcon,
        ),
        DeviceActionItemConfig(
          title: l10n.devicePrivacyTitle,
          onTap: onOpenPrivacyPage,
          trailingIcon: externalIcon,
        ),
      ],
    ),
    DevicePageActionSectionConfig(
      id: DevicePageActionSectionId.contact,
      title: l10n.deviceSupportSectionTitle,
      items: [
        DeviceActionItemConfig(
          title: l10n.deviceContactDeveloperAction,
          onTap: onOpenContact,
          trailingIcon: externalIcon,
        ),
      ],
    ),
  ];
}
