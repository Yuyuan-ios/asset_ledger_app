import '../../../data/models/device.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/services/timing_monthly_expense_service.dart';
import '../../account/use_cases/compute_account_summary_use_case.dart';

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
/// 收入口径复用账户页汇总用例，避免计时页维护第二套应收公式。
class ComputeTimingChartFinanceUseCase {
  const ComputeTimingChartFinanceUseCase({
    this.computeAccountSummaryUseCase = const ComputeAccountSummaryUseCase(),
  });

  final ComputeAccountSummaryUseCase computeAccountSummaryUseCase;

  TimingChartFinanceResult execute({
    required List<TimingRecord> timingRecords,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required TimingMonthlyExpenseStats expenseStats,
  }) {
    final accountSummary = computeAccountSummaryUseCase.execute(
      timingRecords: timingRecords,
      devices: devices,
      rates: rates,
      // totalReceivable 与收款记录无关；传空列表避免计时页新增无关 Store 依赖。
      payments: const [],
    );
    final totalReceivable = accountSummary.totalReceivable;
    final totalExpense = expenseStats.totalExpense;

    return TimingChartFinanceResult(
      totalReceivable: totalReceivable,
      totalExpense: totalExpense,
      displayIncome: totalReceivable - totalExpense,
    );
  }
}
