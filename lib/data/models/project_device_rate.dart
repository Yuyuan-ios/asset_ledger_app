// =====================================================================

import 'project_id.dart';
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
  final String projectId;
  final String projectKey;
  final int deviceId;
  final bool isBreaking;
  final int rateFen;

  ProjectDeviceRate({
    this.projectId = '',
    required this.projectKey,
    required this.deviceId,
    this.isBreaking = false,
    required double rate,
    int? rateFen,
  }) : rateFen = rateFen ?? (rate * 100).round();

  /// 覆盖单价的派生 yuan 视图；存储权威是 [rateFen]。
  double get rate => rateFen / 100.0;

  double get effectiveRate => rateFen / 100.0;

  Map<String, Object?> toMap() {
    return {
      'project_id': effectiveProjectId,
      'project_key': projectKey,
      'device_id': deviceId,
      'is_breaking': isBreaking ? 1 : 0,
      'rate_fen': rateFen,
    };
  }

  static ProjectDeviceRate fromMap(Map<String, Object?> m) {
    final rawRateFen = m['rate_fen'];
    if (rawRateFen == null) {
      throw StateError('project_device_rates.rate_fen is required');
    }
    return ProjectDeviceRate(
      projectId: (m['project_id'] as String?) ?? '',
      projectKey: (m['project_key'] as String?) ?? '',
      deviceId: (m['device_id'] as int?) ?? 0,
      isBreaking: ((m['is_breaking'] as int?) ?? 0) == 1,
      rate: 0,
      rateFen: (rawRateFen as num).toInt(),
    );
  }

  String get effectiveProjectId {
    return ProjectId.ensure(projectId: projectId, legacyProjectKey: projectKey);
  }
}
