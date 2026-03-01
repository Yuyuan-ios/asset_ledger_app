/// =====================================================================
/// FuelEfficiencyAgg
/// - 轻量聚合模型（不落库）
/// - totalHours=0 时：lph / cph 返回 null（UI 显示 "--"）
/// =====================================================================
class FuelEfficiencyAgg {
  final int deviceId;

  double totalLiters = 0.0;
  double totalCost = 0.0;
  double totalHours = 0.0;

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
