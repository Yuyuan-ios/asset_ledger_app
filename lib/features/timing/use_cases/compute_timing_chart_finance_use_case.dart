import '../../../data/services/timing_monthly_expense_service.dart';

class TimingChartFinanceResult {
  const TimingChartFinanceResult({
    required this.totalReceivable,
    required this.totalExpense,
    required this.displayIncome,
  });

  final double totalReceivable;
  final double totalExpense;
  final double displayIncome;
}

/// 计时页年度图表财务口径编排。
///
/// 收入口径复用月柱图的净收入合计，保证图例与柱状图同一口径。
class ComputeTimingChartFinanceUseCase {
  const ComputeTimingChartFinanceUseCase();

  TimingChartFinanceResult execute({
    required List<double> monthlyIncome,
    required TimingMonthlyExpenseStats expenseStats,
  }) {
    final totalIncome = monthlyIncome.fold<double>(
      0.0,
      (sum, income) => sum + income,
    );
    final totalExpense = expenseStats.totalExpense;

    return TimingChartFinanceResult(
      totalReceivable: totalIncome,
      totalExpense: totalExpense,
      displayIncome: totalIncome,
    );
  }
}
