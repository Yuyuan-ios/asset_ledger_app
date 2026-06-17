import '../../../data/models/device.dart';
import '../../../data/models/timing_record.dart';

class DeviceEditorInitialDeviceContext {
  const DeviceEditorInitialDeviceContext({
    required this.deviceId,
    this.sourceTimingRecord,
  });

  final int? deviceId;
  final TimingRecord? sourceTimingRecord;
}

int? resolveDeviceEditorInitialDeviceId({
  required bool isEditing,
  required int? editingDeviceId,
  required List<TimingRecord> timingRecords,
  required List<Device> activeDevices,
}) {
  return resolveDeviceEditorInitialDeviceContext(
    isEditing: isEditing,
    editingDeviceId: editingDeviceId,
    timingRecords: timingRecords,
    activeDevices: activeDevices,
  ).deviceId;
}

DeviceEditorInitialDeviceContext resolveDeviceEditorInitialDeviceContext({
  required bool isEditing,
  required int? editingDeviceId,
  required List<TimingRecord> timingRecords,
  required List<Device> activeDevices,
}) {
  if (isEditing) {
    return DeviceEditorInitialDeviceContext(deviceId: editingDeviceId);
  }

  final activeDeviceIds = <int>{
    for (final device in activeDevices)
      if (device.id != null) device.id!,
  };
  if (activeDeviceIds.isEmpty) {
    return const DeviceEditorInitialDeviceContext(deviceId: null);
  }

  for (final record in timingRecords) {
    if (activeDeviceIds.contains(record.deviceId)) {
      return DeviceEditorInitialDeviceContext(
        deviceId: record.deviceId,
        sourceTimingRecord: record,
      );
    }
  }
  return const DeviceEditorInitialDeviceContext(deviceId: null);
}
