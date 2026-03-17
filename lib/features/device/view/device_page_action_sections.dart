import 'package:flutter/material.dart';

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
      title: '个人资料',
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
          title: '立即升级',
          onTap: onOpenUpgradePage,
          trailingIcon: forwardIcon,
        ),
      ],
    ),
    DevicePageActionSectionConfig(
      id: DevicePageActionSectionId.equipment,
      title: '设备',
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
          title: '添加设备',
          onTap: onOpenAddDeviceFlow,
          trailingIcon: forwardIcon,
        ),
      ],
    ),
    DevicePageActionSectionConfig(
      id: DevicePageActionSectionId.rating,
      title: '给我们评分',
      items: [
        DeviceActionItemConfig(
          title: '给app评分',
          onTap: onOpenRateApp,
          trailingIcon: externalIcon,
        ),
      ],
    ),
    DevicePageActionSectionConfig(
      id: DevicePageActionSectionId.terms,
      title: '条款',
      items: [
        DeviceActionItemConfig(
          title: '使用条款',
          onTap: onOpenTermsPage,
          trailingIcon: externalIcon,
        ),
        DeviceActionItemConfig(
          title: '隐私政策',
          onTap: onOpenPrivacyPage,
          trailingIcon: externalIcon,
        ),
      ],
    ),
    DevicePageActionSectionConfig(
      id: DevicePageActionSectionId.contact,
      title: '支持与反馈',
      items: [
        DeviceActionItemConfig(
          title: '联系开发者',
          onTap: onOpenContact,
          trailingIcon: externalIcon,
        ),
      ],
    ),
  ];
}
