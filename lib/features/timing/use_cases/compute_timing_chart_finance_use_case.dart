import '../../../core/date/gregorian_year_range.dart';
import '../../../data/models/device.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/project_write_off.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/services/account_service.dart';
import '../../../data/services/timing_monthly_expense_service.dart';

class TimingChartFinanceResult {
  const TimingChartFinanceResult({
    required this.chartIncome,
    required this.totalReceivable,
    required this.totalExpense,
    required this.netIncome,
  });

  final double chartIncome;
  final double totalReceivable;
  final double totalExpense;
  final double netIncome;
}

/// 计时页年度图表财务口径编排。
///
/// 绿色柱仍使用月收入合计；摘要单独展示净收入。
class ComputeTimingChartFinanceUseCase {
  const ComputeTimingChartFinanceUseCase();

  TimingChartFinanceResult execute({
    required List<double> monthlyIncome,
    required TimingMonthlyExpenseStats expenseStats,
    required double annualReceivable,
  }) {
    final chartIncome = monthlyIncome.fold<double>(
      0.0,
      (sum, income) => sum + income,
    );
    final totalExpense = expenseStats.totalExpense;
    final netIncome = annualReceivable - totalExpense;

    return TimingChartFinanceResult(
      chartIncome: chartIncome,
      totalReceivable: annualReceivable,
      totalExpense: totalExpense,
      netIncome: netIncome,
    );
  }

  double computeAnnualSelfOwnedReceivable({
    required List<TimingRecord> records,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<ProjectWriteOff> writeOffs,
    required int targetYear,
  }) {
    final range = GregorianYearRange.forYear(targetYear);
    final annualRecords = records.where((record) {
      return range.containsYmd(record.startDate);
    }).toList();
    final projects = AccountService.buildProjects(timingRecords: annualRecords);
    if (projects.isEmpty) return 0.0;

    final annualProjectIds = projects.keys.toSet();
    final annualWriteOffFen = writeOffs.fold<int>(0, (sum, writeOff) {
      final projectId = writeOff.projectId.trim();
      if (!annualProjectIds.contains(projectId)) return sum;
      if (!range.containsDateText(writeOff.writeOffDate)) return sum;
      return sum + _yuanToFen(writeOff.amount);
    });

    final annualOriginalFen = projects.values.fold<int>(0, (sum, agg) {
      final money = AccountService.calcMoney(
        agg: agg,
        devices: devices,
        rates: rates,
        payments: const [],
        writeOffs: const [],
      );
      return sum + _yuanToFen(money.receivable);
    });

    final receivableFen = annualOriginalFen > annualWriteOffFen
        ? annualOriginalFen - annualWriteOffFen
        : 0;
    return _fenToYuan(receivableFen);
  }
}

int _yuanToFen(num value) => (value * 100).round();

double _fenToYuan(int value) => value / 100.0;
