import '../../core/utils/format_utils.dart';
import '../models/fuel_log.dart';
import '../models/maintenance_record.dart';

/// 计时页支出图表统计结果（分类分层）
///
/// 当前阶段先用于：
/// - monthlyTotal：渲染图表黑色支出柱
/// - totalExpense：渲染图表总支出文案
///
/// 分层数据 monthlyFuel / monthlyMaintenance 同步产出，
/// 便于后续扩展分层图表而不改 service 口径。
class TimingMonthlyExpenseStats {
  const TimingMonthlyExpenseStats({
    required this.monthlyFuel,
    required this.monthlyMaintenance,
    required this.monthlyTotal,
    required this.totalFuel,
    required this.totalMaintenance,
    required this.totalExpense,
  });

  final List<double> monthlyFuel;
  final List<double> monthlyMaintenance;
  final List<double> monthlyTotal;
  final double totalFuel;
  final double totalMaintenance;
  final double totalExpense;
}

/// 计时页支出图表：动态支出汇总视图
///
/// 规则：
/// 1) cutoffDate = min(asOfDate/今天, targetMonth 月末)
/// 2) 超过 cutoffDate 的 fuel / maintenance 记录不参与当前图表
/// 3) 非正金额（cost <= 0 / amount <= 0）跳过
/// 4) 仅按“记录发生月”直接汇总（不做区间分摊）
class TimingMonthlyExpenseService {
  const TimingMonthlyExpenseService._();

  static TimingMonthlyExpenseStats computeMonthlyExpense({
    required List<FuelLog> fuelLogs,
    required List<MaintenanceRecord> maintenanceRecords,
    required int targetYear,
    required int targetMonth,
    DateTime? asOfDate,
  }) {
    final month = targetMonth.clamp(1, 12);
    final targetMonthEnd = _monthEnd(targetYear, month);
    final asOf = _dateOnly(asOfDate ?? DateTime.now());
    final cutoffDate = asOf.isBefore(targetMonthEnd) ? asOf : targetMonthEnd;

    final monthlyFuel = List<double>.filled(12, 0.0);
    final monthlyMaintenance = List<double>.filled(12, 0.0);

    for (final log in fuelLogs) {
      final cost = log.cost;
      if (cost <= 0) continue;

      final recordDate = FormatUtils.dateFromYmd(log.date);
      if (recordDate.isAfter(cutoffDate)) continue;
      if (recordDate.year != targetYear) continue;

      monthlyFuel[recordDate.month - 1] += cost;
    }

    for (final record in maintenanceRecords) {
      final amount = record.amount;
      if (amount <= 0) continue;

      final recordDate = FormatUtils.dateFromYmd(record.ymd);
      if (recordDate.isAfter(cutoffDate)) continue;
      if (recordDate.year != targetYear) continue;

      monthlyMaintenance[recordDate.month - 1] += amount;
    }

    final monthlyTotal = List<double>.generate(
      12,
      (i) => monthlyFuel[i] + monthlyMaintenance[i],
    );
    final totalFuel = monthlyFuel.fold<double>(0.0, (sum, x) => sum + x);
    final totalMaintenance = monthlyMaintenance.fold<double>(
      0.0,
      (sum, x) => sum + x,
    );

    return TimingMonthlyExpenseStats(
      monthlyFuel: monthlyFuel,
      monthlyMaintenance: monthlyMaintenance,
      monthlyTotal: monthlyTotal,
      totalFuel: totalFuel,
      totalMaintenance: totalMaintenance,
      totalExpense: totalFuel + totalMaintenance,
    );
  }

  static DateTime _monthEnd(int year, int month) {
    return DateTime(year, month + 1, 0);
  }

  static DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }
}
