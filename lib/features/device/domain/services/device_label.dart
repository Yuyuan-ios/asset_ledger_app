import '../entities/device.dart';

class DeviceLabel {
  const DeviceLabel._();

  static String indexOnly(String deviceName) {
    final idx = indexFromDisplayName(deviceName);
    if (idx == null || idx <= 0) return '?';
    return '$idx#';
  }

  static Map<int, String> indexMapById(Iterable<Device> devices) {
    final out = <int, String>{};
    for (final device in devices) {
      final id = device.id;
      if (id == null) continue;
      out[id] = indexOnly(device.name);
    }
    return out;
  }

  static int? indexFromDisplayName(String name) {
    final match = RegExp(r'(\d+)\s*#').firstMatch(name);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}
