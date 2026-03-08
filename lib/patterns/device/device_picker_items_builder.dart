import '../../core/utils/device_maps.dart';
import '../../core/utils/format_utils.dart';
import '../../data/models/device.dart';
import '../../data/models/timing_record.dart';
import '../../data/services/timing_service.dart';
import 'device_picker_pattern.dart';

class DeviceEditorContextVm {
  final Map<int, Device> deviceById;
  final List<DevicePickerItemVm> deviceItems;

  const DeviceEditorContextVm({
    required this.deviceById,
    required this.deviceItems,
  });
}

DeviceEditorContextVm buildDeviceEditorContext({
  required List<Device> activeDevices,
  required List<Device> allDevices,
  required List<TimingRecord> records,
  int? selectedId,
}) {
  return DeviceEditorContextVm(
    deviceById: buildDeviceByIdMap(allDevices),
    deviceItems: buildDevicePickerItems(
      activeDevices: activeDevices,
      allDevices: allDevices,
      records: records,
      selectedId: selectedId,
    ),
  );
}

List<DevicePickerItemVm> buildDevicePickerItems({
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
        DevicePickerItemVm(id: selectedId, label: '未知设备（已停用）', enabled: false),
      );
    }
  }

  return items;
}
