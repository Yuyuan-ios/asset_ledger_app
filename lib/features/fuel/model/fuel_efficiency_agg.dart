/// =====================================================================
/// FuelEfficiencyAgg
/// - 轻量聚合模型（不落库）
/// - totalHours=0 时：lph / cph 返回 null（UI 显示 "--"）
/// =====================================================================
class FuelEfficiencyAgg {
  final int deviceId;

  double totalLiters = 0.0;
  double totalCost = 0.0;

  /// 燃油效率分母：仅包含参与燃油效率统计的工时。
  double totalHours = 0.0;

  /// 展示用总计时：包含设备所有计时记录填入的 hours，包括租金/台班模式。
  double totalTimingHours = 0.0;

  FuelEfficiencyAgg({required this.deviceId});

  double? get litersPerHour {
    if (totalHours <= 0) return null;
    return totalLiters / totalHours;
  }

  double? get costPerHour {
    if (totalHours <= 0) return null;
    return totalCost / totalHours;
  }
}
