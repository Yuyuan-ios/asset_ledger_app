import 'package:flutter/material.dart';

import '../../../data/models/device.dart';
import '../../../patterns/device/device_action_section_pattern.dart';
import '../../../patterns/device/device_management_section_pattern.dart';
import '../../../tokens/mapper/core_tokens.dart';
import 'device_page_action_sections.dart';

class DevicePageSectionHandlers {
  const DevicePageSectionHandlers({
    required this.onOpenUpgradePage,
    required this.onOpenAddDeviceFlow,
    required this.onOpenRateApp,
    required this.onOpenTermsPage,
    required this.onOpenPrivacyPage,
    required this.onOpenContact,
    required this.onDeviceTap,
    required this.onDeviceLongPress,
  });

  final VoidCallback onOpenUpgradePage;
  final VoidCallback onOpenAddDeviceFlow;
  final VoidCallback onOpenRateApp;
  final VoidCallback onOpenTermsPage;
  final VoidCallback onOpenPrivacyPage;
  final VoidCallback onOpenContact;
  final ValueChanged<Device> onDeviceTap;
  final ValueChanged<Device> onDeviceLongPress;
}

List<Widget> buildDevicePageSections({
  required List<Device> devices,
  required DevicePageSectionHandlers handlers,
}) {
  final actionConfigs = buildDevicePageActionSectionConfigs(
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
          devices: devices,
          onDeviceTap: handlers.onDeviceTap,
          onDeviceLongPress: handlers.onDeviceLongPress,
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
