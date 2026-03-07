// =====================================================================
// ============================== ProjectDeviceRate（项目×设备单价） ==============================
// =====================================================================
//
// 口径：
// - 覆盖某项目中某台设备的单价
// - 若不存在覆盖，则使用 Device.defaultUnitPrice
//
// 复合主键：projectKey + deviceId + isBreaking
// =====================================================================

class ProjectDeviceRate {
  final String projectKey;
  final int deviceId;
  final bool isBreaking;
  final double rate;

  const ProjectDeviceRate({
    required this.projectKey,
    required this.deviceId,
    this.isBreaking = false,
    required this.rate,
  });

  Map<String, Object?> toMap() {
    return {
      'project_key': projectKey,
      'device_id': deviceId,
      'is_breaking': isBreaking ? 1 : 0,
      'rate': rate,
    };
  }

  static ProjectDeviceRate fromMap(Map<String, Object?> m) {
    return ProjectDeviceRate(
      projectKey: (m['project_key'] as String?) ?? '',
      deviceId: (m['device_id'] as int?) ?? 0,
      isBreaking: ((m['is_breaking'] as int?) ?? 0) == 1,
      rate: (m['rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
