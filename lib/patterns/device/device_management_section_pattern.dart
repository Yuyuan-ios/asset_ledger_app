import 'package:flutter/material.dart';

import '../../data/models/device.dart';
import '../../tokens/mapper/device_tokens.dart';
import 'device_management_grid_pattern.dart';
import 'device_section_group_pattern.dart';

class DeviceManagementSection extends StatelessWidget {
  const DeviceManagementSection({
    super.key,
    required this.devices,
    required this.onDeviceTap,
    required this.onDeviceLongPress,
    this.title = '管理设备(长按图标删除)',
    this.padding = const EdgeInsets.symmetric(
      horizontal: DeviceTokens.sectionHorizontalInset,
    ),
  });

  final List<Device> devices;
  final ValueChanged<Device> onDeviceTap;
  final ValueChanged<Device> onDeviceLongPress;
  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DeviceSectionGroup(
      title: title,
      padding: padding,
      children: [
        DeviceManagementGrid(
          devices: devices,
          onDeviceTap: onDeviceTap,
          onDeviceLongPress: onDeviceLongPress,
        ),
      ],
    );
  }
}
