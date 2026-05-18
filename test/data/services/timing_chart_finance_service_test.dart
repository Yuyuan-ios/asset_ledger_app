import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:asset_ledger/data/services/timing_monthly_expense_service.dart';
import 'package:asset_ledger/features/timing/use_cases/compute_timing_chart_finance_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComputeTimingChartFinanceUseCase.execute', () {
    test('uses monthly bar net income as display income', () {
      final expenseStats = TimingMonthlyExpenseService.computeMonthlyExpense(
        fuelLogs: const [
          FuelLog(
            id: 1,
            deviceId: 1,
            date: 20260310,
            supplier: '测试供应商',
            liters: 1,
            cost: 3276,
          ),
        ],
        maintenanceRecords: const <MaintenanceRecord>[],
        targetYear: 2026,
        targetMonth: 3,
        asOfDate: DateTime(2026, 3, 31),
      );

      final result = const ComputeTimingChartFinanceUseCase().execute(
        monthlyIncome: const [1200, 0, 39666, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        expenseStats: expenseStats,
      );

      expect(result.totalReceivable, 40866);
      expect(result.totalExpense, 3276);
      expect(result.displayIncome, 40866);
    });

    test(
      'keeps legend income consistent with monthly bar sum after write-off',
      () {
        const monthlyIncomeAfterWriteOff = [
          0.0,
          0.0,
          0.0,
          0.0,
          952.380952,
          247.619048,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
          0.0,
        ];
        final expenseStats = TimingMonthlyExpenseService.computeMonthlyExpense(
          fuelLogs: const [
            FuelLog(
              id: 1,
              deviceId: 1,
              date: 20260510,
              supplier: '测试供应商',
              liters: 1,
              cost: 100,
            ),
          ],
          maintenanceRecords: [
            MaintenanceRecord(
              id: 1,
              deviceId: 1,
              ymd: 20260511,
              item: '测试保养',
              amount: 20,
              note: '测试保养',
            ),
          ],
          targetYear: 2026,
          targetMonth: 5,
          asOfDate: DateTime(2026, 5, 31),
        );

        final result = const ComputeTimingChartFinanceUseCase().execute(
          monthlyIncome: monthlyIncomeAfterWriteOff,
          expenseStats: expenseStats,
        );

        expect(result.totalReceivable, closeTo(1200.0, 0.001));
        expect(result.totalExpense, 120);
        expect(result.displayIncome, closeTo(1200.0, 0.001));
      },
    );
  });
}
