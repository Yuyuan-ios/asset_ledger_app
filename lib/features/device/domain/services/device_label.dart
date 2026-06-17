import '../entities/device.dart';

class DeviceLabel {
  const DeviceLabel._();

  static String indexOnly(String deviceName) {
    final idx = indexFromDisplayName(deviceName);
    if (idx == null || idx <= 0) return '?';
    return '$idx#';
  }

  static String replaceIndexLabel(String deviceName, String indexLabel) {
    final name = deviceName.trim();
    final label = indexLabel.trim();
    if (label.isEmpty) return name;

    final match = RegExp(r'(\d+)\s*#').firstMatch(name);
    if (match == null) {
      return name.isEmpty ? label : '$name $label';
    }

    final prefix = name.substring(0, match.start).trimRight();
    final suffix = name.substring(match.end).trimLeft();
    return [
      if (prefix.isNotEmpty) prefix,
      label,
      if (suffix.isNotEmpty) suffix,
    ].join(' ');
  }

  static Map<int, String> indexMapById(
    Iterable<Device> devices, {
    String? inactiveLabel,
  }) {
    final out = <int, String>{};
    for (final device in devices) {
      final id = device.id;
      if (id == null) continue;
      out[id] = !device.isActive && inactiveLabel != null
          ? inactiveLabel
          : indexOnly(device.name);
    }
    return out;
  }

  static String displayName(Device device, {required String inactiveLabel}) {
    if (device.isActive) return device.name;
    return replaceIndexLabel(device.name, inactiveLabel);
  }

  static Map<int, String> displayNameMapById(
    Iterable<Device> devices, {
    required String inactiveLabel,
  }) {
    final out = <int, String>{};
    for (final device in devices) {
      final id = device.id;
      if (id == null) continue;
      out[id] = displayName(device, inactiveLabel: inactiveLabel);
    }
    return out;
  }

  static int? indexFromDisplayName(String name) {
    final match = RegExp(r'(\d+)\s*#').firstMatch(name);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}
