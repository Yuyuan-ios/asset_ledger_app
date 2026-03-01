import '../../data/models/device.dart';
import '../../data/services/device_service.dart';

// =====================================================================
// ============================== 设备显示标签工具 ==============================
// =====================================================================
//
// 目标：全 App 统一“设备标题怎么显示”
// - 输入：deviceName（例如 "SANY 12#"）
// - 输出：仅编号（例如 "12#"）
// - 兜底：解析失败返回 "?"（避免 UI 出现空白/异常）
//
// 放置层级：Presentation / Utils
// =====================================================================

class DeviceLabel {
  // -------------------------------------------------------------------
  // 从 "SANY 12#" 中提取 "12#"
  // -------------------------------------------------------------------
  static String indexOnly(String deviceName) {
    final idx = DeviceService.indexFromDisplayName(deviceName);
    if (idx == null || idx <= 0) return '?';
    return '$idx#';
  }

  // -------------------------------------------------------------------
  // 设备列表 -> {deviceId: "n#"}（统一映射口径）
  // -------------------------------------------------------------------
  static Map<int, String> indexMapById(Iterable<Device> devices) {
    final out = <int, String>{};
    for (final d in devices) {
      final id = d.id;
      if (id == null) continue;
      out[id] = indexOnly(d.name);
    }
    return out;
  }
}
