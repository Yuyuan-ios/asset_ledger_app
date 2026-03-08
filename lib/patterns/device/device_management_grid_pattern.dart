import 'package:flutter/material.dart';

import '../../components/avatars/app_device_avatar.dart';
import '../../core/foundation/typography.dart';
import '../../core/utils/device_label.dart';
import '../../data/models/device.dart';
import '../../tokens/mapper/device_tokens.dart';

class DeviceManagementGrid extends StatelessWidget {
  const DeviceManagementGrid({
    super.key,
    required this.devices,
    required this.onDeviceTap,
    required this.onDeviceLongPress,
  });

  final List<Device> devices;
  final ValueChanged<Device> onDeviceTap;
  final ValueChanged<Device> onDeviceLongPress;

  @override
  Widget build(BuildContext context) {
    final visible = devices.take(DeviceManagementGridTokens.slots).toList();
    return Container(
      height: DeviceManagementGridTokens.height,
      decoration: BoxDecoration(
        color: DeviceTokens.managementGridBackgroundColor,
        border: Border.all(color: DeviceTokens.managementGridBorderColor),
        borderRadius: BorderRadius.circular(
          DeviceManagementGridTokens.borderRadius,
        ),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          DeviceManagementGridTokens.padLeft,
          DeviceManagementGridTokens.padTop,
          DeviceManagementGridTokens.padRight,
          DeviceManagementGridTokens.padBottom,
        ),
        itemCount: DeviceManagementGridTokens.slots,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: DeviceManagementGridTokens.columns,
          crossAxisSpacing: DeviceManagementGridTokens.crossSpacing,
          mainAxisSpacing: DeviceManagementGridTokens.mainSpacing,
          childAspectRatio: DeviceManagementGridTokens.aspectRatio,
        ),
        itemBuilder: (context, index) {
          if (index >= visible.length) {
            return _placeholderItem();
          }

          final d = visible[index];
          final label = DeviceLabel.indexOnly(d.name);
          final displayIndex = label.trim().isEmpty ? '—' : label.trim();
          final categoryLabel = d.equipmentType == EquipmentType.loader
              ? '装载机'
              : '挖掘机';
          final displayText = displayIndex == '—'
              ? categoryLabel
              : '$displayIndex$categoryLabel';

          return Tooltip(
            message: label.trim().isEmpty ? d.name : label,
            child: GestureDetector(
              onTap: () => onDeviceTap(d),
              onLongPress: () => onDeviceLongPress(d),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: DeviceManagementGridTokens.avatarSize,
                    height: DeviceManagementGridTokens.avatarSize,
                    child: DeviceAvatar(
                      brand: d.brand,
                      customAvatarPath: d.customAvatarPath,
                      radius: DeviceManagementGridTokens.avatarRadius,
                    ),
                  ),
                  const SizedBox(
                    height: DeviceManagementGridTokens.labelTopGap,
                  ),
                  Text(
                    displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(
                      context,
                      fontSize: DeviceManagementGridTokens.labelFontSize,
                      fontWeight: DeviceManagementGridTokens.labelFontWeight,
                      color: DeviceTokens.managementGridLabelColor.withValues(
                        alpha: DeviceManagementGridTokens.labelAlpha,
                      ),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholderItem() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: DeviceManagementGridTokens.avatarSize,
          height: DeviceManagementGridTokens.avatarSize,
          decoration: BoxDecoration(
            color: DeviceTokens.managementGridPlaceholderColor.withValues(
              alpha: DeviceManagementGridTokens.placeholderAlpha,
            ),
            borderRadius: BorderRadius.circular(
              DeviceManagementGridTokens.placeholderRadius,
            ),
          ),
        ),
        const SizedBox(height: DeviceManagementGridTokens.labelTopGap),
        const Text(
          '',
          style: TextStyle(
            fontSize: DeviceTokens.managementGridPlaceholderLabelFontSize,
            height: 1,
          ),
        ),
      ],
    );
  }
}
