import '../entities/device.dart';

/// 当前方案不支持自定义头像。domain 抛 typed 异常，用户可见文案由 view 层映射 l10n。
class CustomAvatarNotAllowedException implements Exception {
  const CustomAvatarNotAllowedException();
}

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
      throw const CustomAvatarNotAllowedException();
    }

    return device.copyWith(customAvatarPath: normalizedPath);
  }
}
