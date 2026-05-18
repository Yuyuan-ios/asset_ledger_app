import '../entities/device.dart';

class DeviceAvatarPolicy {
  const DeviceAvatarPolicy._();

  static Device applyCustomAvatar({
    required Device device,
    required String? customAvatarPath,
    required bool canUseCustomAvatar,
  }) {
    final normalizedPath = customAvatarPath?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return device.copyWith(customAvatarPath: null);
    }

    if (!canUseCustomAvatar) {
      throw Exception('当前方案不支持自定义头像');
    }

    return device.copyWith(customAvatarPath: normalizedPath);
  }
}
