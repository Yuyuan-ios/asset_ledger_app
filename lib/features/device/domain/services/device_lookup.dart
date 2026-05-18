import '../entities/device.dart';

Map<int, Device> buildDeviceByIdMap(Iterable<Device> devices) {
  final deviceById = <int, Device>{};
  for (final device in devices) {
    final id = device.id;
    if (id == null) continue;
    deviceById[id] = device;
  }
  return deviceById;
}
