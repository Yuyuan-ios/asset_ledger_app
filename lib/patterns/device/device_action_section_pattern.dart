import 'package:flutter/material.dart';

import 'device_action_card_pattern.dart';
import 'device_section_group_pattern.dart';

class DeviceActionItemConfig {
  const DeviceActionItemConfig({
    required this.title,
    required this.onTap,
    this.leading,
    this.trailingIcon,
  });

  final String title;
  final VoidCallback onTap;
  final Widget? leading;
  final IconData? trailingIcon;
}

class DeviceActionSection extends StatelessWidget {
  const DeviceActionSection({
    super.key,
    required this.title,
    required this.items,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final List<DeviceActionItemConfig> items;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DeviceSectionGroup(
      title: title,
      padding: padding,
      children: [
        for (final item in items)
          DeviceActionCard(
            title: item.title,
            onTap: item.onTap,
            leading: item.leading,
            trailingIcon: item.trailingIcon,
          ),
      ],
    );
  }
}
