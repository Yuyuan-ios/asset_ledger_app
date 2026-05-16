import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/timing_monthly_expense_service.dart';
import 'package:asset_ledger/features/timing/use_cases/compute_timing_chart_finance_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComputeTimingChartFinanceUseCase.execute', () {
    test('uses account receivable minus timing expense as display income', () {
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
        timingRecords: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260301,
            contact: '测试联系人',
            site: '测试工地',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 40866,
            hours: 40866,
            income: 0,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'HITACHI 1#',
            brand: 'HITACHI',
            defaultUnitPrice: 1,
            baseMeterHours: 0,
          ),
        ],
        rates: const <ProjectDeviceRate>[],
        expenseStats: expenseStats,
      );

      expect(result.totalReceivable, 40866);
      expect(result.totalExpense, 3276);
      expect(result.displayIncome, 37590);
    });
  });
}
