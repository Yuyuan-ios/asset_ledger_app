// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

// 1.1 项目内：计时记录模型（纯算法需要读取 deviceId/startDate/endMeter 等字段）
import '../models/timing_record.dart';

// =====================================================================
// ============================== 二、TimingService（纯算法/纯函数） ==============================
// =====================================================================
//
// 设计原则：
// - 这里不做任何 UI / setState / Provider 操作
// - 输入是什么，就返回一个计算结果（可单元测试）
// - 页面/Store 只负责“拿数据 -> 调用这里 -> 展示/校验”
//
class TimingService {
  // -------------------------------------------------------------------
  // 2.1 currentMeter：计算“当前码表小时”
  // -------------------------------------------------------------------
  //
  // 规则解释（逐条对应）：
  // - baseMeterHours：设备基准码表（来自设备页录入/交接数据）
  // - maxEndMeter   ：计时记录里该设备 endMeter 的最大值
  // - 当前码表 = max(baseMeterHours, maxEndMeter)
  //
  // 为什么要这样做：
  // - 设备没有任何记录时：currentMeter 不应该是 0，而应该是 baseMeterHours
  // - 删除最新记录后：currentMeter 也不该掉回 0，而是回到 baseMeterHours
  // - 同时避免“历史记录比基准更小”导致码表倒拨的体验问题
  //
  static double currentMeter(
    List<TimingRecord> records,
    int deviceId, {
    required double baseMeterHours,
  }) {
    // 先从 0 开始扫描“记录中最大的 endMeter”
    double maxEnd = 0.0;

    // 遍历所有记录，筛选出同设备的记录
    for (final r in records) {
      // 只看当前设备
      if (r.deviceId != deviceId) continue;

      // 记录的 endMeter 更大就更新
      if (r.endMeter > maxEnd) maxEnd = r.endMeter;
    }

    // 当前码表取两者最大值：
    // - 记录最大 endMeter
    // - 设备基准 baseMeterHours
    return (maxEnd > baseMeterHours) ? maxEnd : baseMeterHours;
  }

  // -------------------------------------------------------------------
  // 2.2 lowerBound：下界（更早日期里最大的 endMeter）
  // -------------------------------------------------------------------
  //
  // 用途：
  // - 保存/编辑记录时防止 endMeter 小于“历史最大值”，造成码表倒拨
  //
  // 规则：
  // - 只看同设备
  // - 只看严格更早日期（r.startDate < startDate）
  // - 编辑时排除自己（excludeId）
  // - 返回“更早记录里最大的 endMeter”，若没有更早记录则返回 0.0
  //
  static double lowerBound({
    required List<TimingRecord> records,
    required int deviceId,
    required int startDate,
    int? excludeId,
  }) {
    // 没有更早记录时，下界默认 0
    double maxEnd = 0.0;

    for (final r in records) {
      // 只看同设备
      if (r.deviceId != deviceId) continue;

      // 编辑时排除自己（避免自己卡自己）
      if (excludeId != null && r.id == excludeId) continue;

      // 只看更早日期（严格 <）
      if (r.startDate >= startDate) continue;

      // 取更早记录里 endMeter 的最大值
      if (r.endMeter > maxEnd) maxEnd = r.endMeter;
    }

    return maxEnd;
  }

  // -------------------------------------------------------------------
  // 2.3 upperBound：上界（更晚日期里最小的 endMeter）
  // -------------------------------------------------------------------
  //
  // 用途：
  // - 允许修改历史记录，但不能把 endMeter 改大到影响未来记录
  //
  // 规则：
  // - 只看同设备
  // - 只看严格更晚日期（r.startDate > startDate）
  // - 编辑时排除自己（excludeId）
  // - 返回“更晚记录里最小的 endMeter”
  // - 若没有更晚记录：返回 double.infinity（表示“没有上界限制”）
  //
  static double upperBound({
    required List<TimingRecord> records,
    required int deviceId,
    required int startDate,
    int? excludeId,
  }) {
    // 默认没有上界限制
    double minEnd = double.infinity;

    for (final r in records) {
      // 只看同设备
      if (r.deviceId != deviceId) continue;

      // 编辑时排除自己
      if (excludeId != null && r.id == excludeId) continue;

      // 只看更晚日期（严格 >）
      if (r.startDate <= startDate) continue;

      // 取更晚记录里 endMeter 的最小值
      if (r.endMeter < minEnd) minEnd = r.endMeter;
    }

    return minEnd;
  }
}
