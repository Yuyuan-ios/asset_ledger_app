import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/device.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/services/timing_suggest_service.dart';
import '../../../data/services/timing_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../../components/feedback/app_toast.dart';
import '../../device/state/device_store.dart';
import '../state/timing_store.dart';
import '../../../patterns/layout/bottom_sheet_shell_pattern.dart';
import '../../../patterns/timing/timing_detail_content_pattern.dart';
import '../../../patterns/device/device_picker_pattern.dart';

class TimingDetailPage extends StatelessWidget {
  const TimingDetailPage({super.key, this.editing});

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
    final formKey = GlobalKey<TimingDetailContentState>();
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
      backgroundColor: Colors.transparent,
      body: AppBottomSheetShell(
        title: editing == null ? '新建计时' : '编辑计时',
        scrollable: false,
        contentPadding: EdgeInsets.zero,
        onCancel: () => Navigator.of(context).maybePop(),
        onConfirm: () => formKey.currentState?.submit(),
        child: TimingDetailContent(
          key: formKey,
          editing: editing,
          records: timingStore.records,
          activeDevices: deviceStore.activeDevices,
          deviceById: deviceById,
          deviceItems: deviceItems,
          contactSuggestions:
              (query) => TimingSuggestService.contactSuggestions(
                timingStore.records,
                query,
              ),
          siteSuggestions:
              (query) =>
                  TimingSuggestService.siteSuggestions(timingStore.records, query),
          onSubmit: (record) async {
            await timingStore.save(record);
            if (context.mounted) Navigator.of(context).maybePop();
          },
          onToast: (msg) {
            AppToast.show(context, msg);
          },
        ),
      ),
    );
  }
}
