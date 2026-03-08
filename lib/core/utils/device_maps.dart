import '../../data/models/device.dart';

Map<int, Device> buildDeviceByIdMap(Iterable<Device> devices) {
  final deviceById = <int, Device>{};
  for (final d in devices) {
    final id = d.id;
    if (id == null) continue;
    deviceById[id] = d;
  }
  return deviceById;
}
