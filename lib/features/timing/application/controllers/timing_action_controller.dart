import '../../../../core/utils/format_utils.dart';
import '../../../../data/services/project_resolver.dart';
import '../../../../data/services/timing_monthly_expense_service.dart';
import '../../../../data/services/timing_monthly_income_service.dart';
import '../../domain/entities/timing_entities.dart';
import '../../domain/repositories/timing_calculation_history_repository.dart';
import '../../domain/services/timing_meter_bounds.dart';
import '../../domain/services/timing_suggestions.dart';
import '../../model/timing_chart_data.dart';
import '../../use_cases/compute_timing_chart_finance_use_case.dart';
import '../../use_cases/save_timing_record_use_case.dart';
import '../../use_cases/save_timing_record_with_impact_use_case.dart';
import '../../use_cases/timing_preview_income_use_case.dart';
import '../../state/timing_store.dart';

class TimingActionController {
  const TimingActionController({
    required TimingCalculationHistoryRepository calculationHistoryRepository,
    required ProjectResolver projectResolver,
  }) : _calculationHistoryRepository = calculationHistoryRepository,
       _projectResolver = projectResolver;

  final TimingCalculationHistoryRepository _calculationHistoryRepository;
  final ProjectResolver _projectResolver;

  TimingActionController copyWith({
    TimingCalculationHistoryRepository? calculationHistoryRepository,
  }) {
    return TimingActionController(
      calculationHistoryRepository:
          calculationHistoryRepository ?? _calculationHistoryRepository,
      projectResolver: _projectResolver,
    );
  }

  TimingPreviewIncomeUseCase createPreviewIncomeUseCase() {
    return TimingPreviewIncomeUseCase(projectResolver: _projectResolver);
  }

  SaveTimingRecordUseCase createSaveUseCase({
    required TimingStore timingStore,
    required SaveTimingRecordWithImpactUseCase withImpact,
  }) {
    return SaveTimingRecordUseCase(
      timingStore: timingStore,
      withImpact: withImpact,
    );
  }

  Future<List<TimingCalculationHistory>> loadExistingCalculationHistories(
    TimingRecord? editing,
  ) async {
    if (editing == null || editing.type != TimingType.hours) {
      return const <TimingCalculationHistory>[];
    }

    final recordId = editing.id;
    if (recordId == null) return const <TimingCalculationHistory>[];
    return _calculationHistoryRepository.findByTimingRecordId(recordId);
  }

  TimingChartData buildChartData({
    required int targetYear,
    required int targetMonth,
    required bool hasExplicitTargetMonth,
    required List<TimingRecord> records,
    required List<Device> devices,
    required List<ProjectDeviceRate> rates,
    required List<FuelLog> fuelLogs,
    required List<MaintenanceRecord> maintenanceRecords,
    required List<ProjectWriteOff> projectWriteOffs,
  }) {
    const monthLabels = [
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月',
    ];
    const maxBarHeight = 150.0;
    final effectiveTargetMonth = resolveEffectiveTargetMonth(
      targetYear: targetYear,
      targetMonth: targetMonth,
      hasExplicitTargetMonth: hasExplicitTargetMonth,
      records: records,
      fuelLogs: fuelLogs,
      maintenanceRecords: maintenanceRecords,
    );
    final monthlyIncome =
        TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
          records: records,
          devices: devices,
          rates: rates,
          targetYear: targetYear,
          targetMonth: effectiveTargetMonth,
          projectWriteOffs: projectWriteOffs,
        );
    final maxIncome = monthlyIncome.fold<double>(0.0, (acc, value) {
      return value > acc ? value : acc;
    });
    final incomeBars = maxIncome <= 0
        ? List<double>.filled(12, 0.0)
        : monthlyIncome
              .map((income) => (income / maxIncome) * maxBarHeight)
              .toList();

    final expenseStats = TimingMonthlyExpenseService.computeMonthlyExpense(
      fuelLogs: fuelLogs,
      maintenanceRecords: maintenanceRecords,
      targetYear: targetYear,
      targetMonth: effectiveTargetMonth,
    );
    const financeUseCase = ComputeTimingChartFinanceUseCase();
    final annualReceivable = financeUseCase.computeAnnualSelfOwnedReceivable(
      records: records,
      devices: devices,
      rates: rates,
      writeOffs: projectWriteOffs,
      targetYear: targetYear,
    );
    final finance = financeUseCase.execute(
      monthlyIncome: monthlyIncome,
      expenseStats: expenseStats,
      annualReceivable: annualReceivable,
    );

    final expenseBars = maxIncome <= 0
        ? List<double>.filled(12, 0.0)
        : expenseStats.monthlyTotal.map((expense) {
            final height = (expense / maxIncome) * maxBarHeight;
            return height.clamp(0.0, maxBarHeight).toDouble();
          }).toList();

    return TimingChartData(
      year: targetYear,
      targetMonth: effectiveTargetMonth,
      monthLabels: monthLabels,
      incomeBars: incomeBars,
      expenseBars: expenseBars,
      totalIncomeText: FormatUtils.money(finance.chartIncome),
      netIncomeText: FormatUtils.money(finance.netIncome),
      totalExpenseText: FormatUtils.money(expenseStats.totalExpense),
    );
  }

  int resolveEffectiveTargetMonth({
    required int targetYear,
    required int targetMonth,
    required bool hasExplicitTargetMonth,
    required List<TimingRecord> records,
    required List<FuelLog> fuelLogs,
    required List<MaintenanceRecord> maintenanceRecords,
  }) {
    if (hasExplicitTargetMonth) return targetMonth;
    var maxMonth = targetMonth;
    for (final record in records) {
      final date = FormatUtils.dateFromYmd(record.startDate);
      if (date.year == targetYear && date.month > maxMonth) {
        maxMonth = date.month;
      }
    }
    for (final fuel in fuelLogs) {
      final date = FormatUtils.dateFromYmd(fuel.date);
      if (date.year == targetYear && date.month > maxMonth) {
        maxMonth = date.month;
      }
    }
    for (final maintenance in maintenanceRecords) {
      final date = FormatUtils.dateFromYmd(maintenance.ymd);
      if (date.year == targetYear && date.month > maxMonth) {
        maxMonth = date.month;
      }
    }
    return maxMonth;
  }

  List<String> contactSuggestions(List<TimingRecord> records, String query) {
    return TimingSuggestions.contactSuggestions(records, query);
  }

  List<String> siteSuggestions(List<TimingRecord> records, String query) {
    return TimingSuggestions.siteSuggestions(records, query);
  }

  String? validateMeterBounds({
    required List<TimingRecord> records,
    required int deviceId,
    required int startDate,
    required double endMeter,
    int? excludeId,
  }) {
    final lower = TimingMeterBounds.lowerBound(
      records: records,
      deviceId: deviceId,
      startDate: startDate,
      excludeId: excludeId,
    );
    if (endMeter < lower) {
      return '结束码表($endMeter) < 下界($lower)';
    }
    final upper = TimingMeterBounds.upperBound(
      records: records,
      deviceId: deviceId,
      startDate: startDate,
      excludeId: excludeId,
    );
    if (upper != double.infinity && endMeter > upper) {
      return '结束码表($endMeter) > 上界($upper)';
    }
    return null;
  }
}
