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
  final double rate;

  /// 存储的 rate_fen（v35，nullable）。null 表示 legacy 行，由 [rateFen]
  /// getter 派生回退。仅 [fromMap] 设置。
  final int? _rateFen;

  const ProjectDeviceRate({
    this.projectId = '',
    required this.projectKey,
    required this.deviceId,
    this.isBreaking = false,
    required this.rate,
    int? rateFen,
  }) : _rateFen = rateFen;

  /// 覆盖单价的整数分（fen 主存读优先口径,v35）。优先返回存储值，
  /// legacy 行由 REAL [rate] 派生 round(×100) 回退。
  int get rateFen => _rateFen ?? (rate * 100).round();

  double get effectiveRate => rateFen / 100.0;

  Map<String, Object?> toMap() {
    return {
      'project_id': effectiveProjectId,
      'project_key': projectKey,
      'device_id': deviceId,
      'is_breaking': isBreaking ? 1 : 0,
      'rate': rate,
      // v35：fen 镜像与 REAL 双写;REAL 仍是读口径,切换留待 S1 收口。
      'rate_fen': rateFen,
    };
  }

  static ProjectDeviceRate fromMap(Map<String, Object?> m) {
    return ProjectDeviceRate(
      projectId: (m['project_id'] as String?) ?? '',
      projectKey: (m['project_key'] as String?) ?? '',
      deviceId: (m['device_id'] as int?) ?? 0,
      isBreaking: ((m['is_breaking'] as int?) ?? 0) == 1,
      rate: (m['rate'] as num?)?.toDouble() ?? 0.0,
      rateFen: (m['rate_fen'] as num?)?.toInt(),
    );
  }

  String get effectiveProjectId {
    return ProjectId.ensure(projectId: projectId, legacyProjectKey: projectKey);
  }
}
