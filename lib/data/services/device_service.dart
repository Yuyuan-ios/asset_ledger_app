// =====================================================================
// ============================== 一、设备业务服务 DeviceService ==============================
// =====================================================================
//
// 目标：把“业务决策”集中在 Service，Store/UI 不写业务分支
// - 自动命名：同品牌生成 "SANY 1# / 2# / 3# ..."
// - 编号规则：只看 activeDevices（停用的不占号）
//   ✅ 支持“回填空缺”：active 中缺 1# 就回到 1#
// - 订阅能力：通过 SubscriptionService 的“同步缓存”统一判断（UI/Store 不直接判断）
//
// 层级：Service
// =====================================================================

import '../models/device.dart';
import 'subscription_service.dart';

class DeviceService {
  // =====================================================================
  // ============================== 二、命名规则：同品牌自动编号 ==============================
  // =====================================================================

  // -------------------------------------------------------------------
  // 2.1 计算：某 brand 的下一编号（只看 activeDevices，且支持回填空缺）
  //
  // 规则：
  // - 只统计 activeDevices（停用的不占号）
  // - 只统计同品牌（brand 完全匹配 trim 后的字符串）
  // - 从 name 中提取编号（"SANY 12#" -> 12）
  //
  // 关键：回填空缺（你选定的策略）
  // - active 里如果已有 2#，但 1# 不存在 => 新建返回 1
  // - active 里如果已有 1#、2# => 新建返回 3
  // -------------------------------------------------------------------
  static int nextIndex({
    required String brand,
    required List<Device> activeDevices,
  }) {
    final b = brand.trim();
    if (b.isEmpty) return 1;

    // 收集“已占用的编号集合”
    final used = <int>{};

    for (final d in activeDevices) {
      // 双保险：只看 active
      if (!d.isActive) continue;

      // 只统计同品牌
      if (d.brand.trim() != b) continue;

      // 从 name 提取编号
      final idx = indexFromDisplayName(d.name);
      if (idx != null && idx > 0) {
        used.add(idx);
      }
    }

    // 找最小缺失的正整数：1,2,3...
    var n = 1;
    while (used.contains(n)) {
      n++;
    }
    return n;
  }

  // -------------------------------------------------------------------
  // 2.2 计算：下一显示名（"SANY n#"）
  // -------------------------------------------------------------------
  static String nextDisplayName({
    required String brand,
    required List<Device> activeDevices,
  }) {
    final n = nextIndex(brand: brand, activeDevices: activeDevices);
    return '${brand.trim()} $n#';
  }

  // -------------------------------------------------------------------
  // 2.3 从 name 提取编号（"SANY 12#" -> 12）
  //
  // 注意：
  // - 这是“显示标签解析”，不是主键逻辑
  // - 即便 name 将来变更格式，你也只需要改这里
  // -------------------------------------------------------------------
  static int? indexFromDisplayName(String name) {
    final m = RegExp(r'(\d+)\s*#').firstMatch(name);
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? '');
  }

  // =====================================================================
  // ============================== 三、订阅能力：自定义头像 ==============================
  // =====================================================================

  // -------------------------------------------------------------------
  // 3.1 订阅能力：是否允许自定义头像（✅ 同步读取缓存）
  //
  // 关键点：
  // - 你现在的 SubscriptionService 里：
  //   - isPro() / canUseCustomAvatar() 是 Future（异步）
  //   - proCached 是 bool（同步缓存）
  //
  // 我们这里必须同步：
  // - Store/UI 不要 await
  // - 订阅真正的异步刷新在 App 启动时调用 SubscriptionService.refresh()
  // -------------------------------------------------------------------
  static bool get canUseCustomAvatar => SubscriptionService.proCached;

  // -------------------------------------------------------------------
  // 3.2 写入自定义头像路径（不允许则抛错）
  //
  // 约定：
  // - customAvatarPath 为空/空白：视为“清空自定义头像”，回退到默认 brand 头像
  // - 非空：只有订阅允许才写入
  // -------------------------------------------------------------------
  static Device applyCustomAvatar({
    required Device device,
    required String? customAvatarPath,
  }) {
    // ① 空值：当作“清空”，不需要订阅也允许
    if (customAvatarPath == null || customAvatarPath.trim().isEmpty) {
      return Device(
        id: device.id,
        name: device.name,
        brand: device.brand,
        model: device.model,
        defaultUnitPrice: device.defaultUnitPrice,
        breakingUnitPrice: device.breakingUnitPrice,
        baseMeterHours: device.baseMeterHours,
        isActive: device.isActive,
        customAvatarPath: null,
        equipmentType: device.equipmentType,
      );
    }

    // ② 有值：必须订阅允许
    if (!canUseCustomAvatar) {
      throw Exception('当前方案不支持自定义头像');
    }

    // ③ 写入（trim 一下，避免路径前后空格）
    return device.copyWith(customAvatarPath: customAvatarPath.trim());
  }
}
