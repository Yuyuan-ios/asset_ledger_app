import 'package:flutter/material.dart';

import '../../components/avatars/app_device_avatar.dart';
import '../../core/foundation/typography.dart';
import '../../data/models/device.dart';
import '../../tokens/mapper/device_tokens.dart';

/// 返回设备的"序号 label"（如 `1#`）。计算由 feature/device 层完成
/// （封装 DeviceLabel.indexOnly），让本 pattern 不再直接依赖 data/services。
typedef DeviceIndexLabelResolver = String Function(Device device);

class DeviceManagementGrid extends StatelessWidget {
  const DeviceManagementGrid({
    super.key,
    required this.devices,
    required this.onDeviceTap,
    required this.onDeviceLongPress,
    required this.resolveIndexLabel,
  });

  final List<Device> devices;
  final ValueChanged<Device> onDeviceTap;
  final ValueChanged<Device> onDeviceLongPress;
  final DeviceIndexLabelResolver resolveIndexLabel;

  @override
  Widget build(BuildContext context) {
    final visible = devices.take(DeviceManagementGridTokens.slots).toList();
    final baseGridWidth =
        DeviceTokens.pageContentWidth -
        (DeviceTokens.pageHorizontalPadding * 2) -
        (DeviceTokens.sectionHorizontalInset * 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final extraWidth = (constraints.maxWidth - baseGridWidth)
            .clamp(0.0, 32.0)
            .toDouble();
        final horizontalInset =
            DeviceManagementGridTokens.padLeft + (extraWidth * 0.25);
        final crossSpacing =
            DeviceManagementGridTokens.crossSpacing + (extraWidth * 0.06);

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
            padding: EdgeInsets.fromLTRB(
              horizontalInset,
              DeviceManagementGridTokens.padTop,
              horizontalInset,
              DeviceManagementGridTokens.padBottom,
            ),
            itemCount: DeviceManagementGridTokens.slots,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: DeviceManagementGridTokens.columns,
              crossAxisSpacing: crossSpacing,
              mainAxisSpacing: DeviceManagementGridTokens.mainSpacing,
              childAspectRatio: DeviceManagementGridTokens.aspectRatio,
            ),
            itemBuilder: (context, index) {
              if (index >= visible.length) {
                return _placeholderItem(context);
              }

              final d = visible[index];
              final label = resolveIndexLabel(d);
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
                          fontWeight:
                              DeviceManagementGridTokens.labelFontWeight,
                          color: DeviceTokens.managementGridLabelColor
                              .withValues(
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
      },
    );
  }

  Widget _placeholderItem(BuildContext context) {
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
        // Placeholder 行高占位：Text 内容为空，仅靠样式撑高，使用 AppTypography 走统一字体体系。
        Text(
          '',
          style: AppTypography.caption(
            context,
            fontSize: DeviceTokens.managementGridPlaceholderLabelFontSize,
            height: 1,
          ),
        ),
      ],
    );
  }
}
