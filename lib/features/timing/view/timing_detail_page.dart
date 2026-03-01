import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/device.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/services/timing_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../device/state/device_controller.dart';
import '../state/timing_controller.dart';
import '../../../patterns/timing/timing_detail_content_pattern.dart';
import '../../../patterns/device/device_picker_pattern.dart';

class TimingDetailPage extends StatelessWidget {
  const TimingDetailPage({
    super.key,
    this.editing,
  });

  final TimingRecord? editing;

  List<DevicePickerItemVm> _buildDevicePickerItems({
    required List<Device> activeDevices,
    required List<Device> allDevices,
    required List<TimingRecord> records,
    int? selectedId,
  }) {
    final items = <DevicePickerItemVm>[];
    final activeIds = <int>{};

    for (final d in activeDevices) {
      final id = d.id;
      if (id == null) continue;
      activeIds.add(id);
      final meter = TimingService.currentMeter(
        records,
        id,
        baseMeterHours: d.baseMeterHours,
      );
      final meterText = FormatUtils.meter(meter);
      items.add(
        DevicePickerItemVm(
          id: id,
          label: '${d.name}（码表 $meterText h）',
          enabled: true,
        ),
      );
    }

    if (selectedId != null && !activeIds.contains(selectedId)) {
      final selected = allDevices.firstWhere(
        (d) => d.id == selectedId,
        orElse: () => const Device(
          id: -1,
          name: '未知设备',
          brand: '',
          defaultUnitPrice: 0,
          baseMeterHours: 0,
          isActive: false,
        ),
      );
      final labelId = selected.id ?? selectedId;
      if (labelId >= 0) {
        final meter = TimingService.currentMeter(
          records,
          labelId,
          baseMeterHours: selected.baseMeterHours,
        );
        final meterText = FormatUtils.meter(meter);
        items.insert(
          0,
          DevicePickerItemVm(
            id: labelId,
            label: '${selected.name}（已停用 · 码表 $meterText h）',
            enabled: false,
          ),
        );
      } else {
        items.insert(
          0,
          DevicePickerItemVm(
            id: selectedId,
            label: '未知设备（已停用）',
            enabled: false,
          ),
        );
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final deviceStore = context.read<DeviceStore>();
    final timingStore = context.read<TimingStore>();
    final deviceById = <int, Device>{};
    for (final d in deviceStore.allDevices) {
      final id = d.id;
      if (id == null) continue;
      deviceById[id] = d;
    }
    final deviceItems = _buildDevicePickerItems(
      activeDevices: deviceStore.activeDevices,
      allDevices: deviceStore.allDevices,
      records: timingStore.records,
      selectedId: editing?.deviceId,
    );

    return Scaffold(
      body: TimingDetailContent(
        editing: editing,
        records: timingStore.records,
        activeDevices: deviceStore.activeDevices,
        deviceById: deviceById,
        deviceItems: deviceItems,
        contactSuggestions: timingStore.contactSuggestions,
        siteSuggestions: timingStore.siteSuggestions,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: (record) async {
          await timingStore.save(record);
          if (context.mounted) Navigator.of(context).maybePop();
        },
        onToast: (msg) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        },
      ),
    );
  }
}
