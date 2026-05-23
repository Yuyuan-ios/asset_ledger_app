import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/timing_monthly_expense_service.dart';
import 'package:asset_ledger/features/timing/use_cases/compute_timing_chart_finance_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComputeTimingChartFinanceUseCase.execute', () {
    test('keeps chart income separate from net income summary', () {
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
        annualReceivable: 42294,
      );

      expect(result.chartIncome, 40866);
      expect(result.totalReceivable, 42294);
      expect(result.totalExpense, 3276);
      expect(result.netIncome, 39018);
    });

    test('calculates net income from annual receivable minus expense', () {
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
        annualReceivable: 1260,
      );

      expect(result.chartIncome, closeTo(1200.0, 0.001));
      expect(result.totalReceivable, 1260);
      expect(result.totalExpense, 120);
      expect(result.netIncome, 1140);
    });

    test(
      'computes annual self-owned receivable after calendar-year write-off',
      () {
        final projectId = ProjectId.legacyFromKey('刘锐||五里山');
        final annualReceivable = const ComputeTimingChartFinanceUseCase()
            .computeAnnualSelfOwnedReceivable(
              records: [
                TimingRecord(
                  id: 1,
                  deviceId: 1,
                  startDate: 20260501,
                  projectId: projectId,
                  contact: '刘锐',
                  site: '五里山',
                  type: TimingType.hours,
                  startMeter: 0,
                  endMeter: 7,
                  hours: 7,
                  income: 0,
                ),
                const TimingRecord(
                  id: 2,
                  deviceId: 1,
                  startDate: 20270101,
                  contact: '刘锐',
                  site: '五里山',
                  type: TimingType.hours,
                  startMeter: 7,
                  endMeter: 10,
                  hours: 3,
                  income: 0,
                ),
              ],
              devices: const [
                Device(
                  id: 1,
                  name: 'SANY 1#',
                  brand: 'SANY',
                  defaultUnitPrice: 180,
                  baseMeterHours: 0,
                ),
              ],
              rates: const <ProjectDeviceRate>[],
              writeOffs: [
                ProjectWriteOff(
                  id: 'write-off-2026',
                  projectId: projectId,
                  amount: 60,
                  reason: ProjectWriteOffReason.rounding.dbValue,
                  writeOffDate: '2026-12-31',
                  createdAt: '2026-12-31T00:00:00.000Z',
                  updatedAt: '2026-12-31T00:00:00.000Z',
                ),
                ProjectWriteOff(
                  id: 'write-off-2027',
                  projectId: projectId,
                  amount: 50,
                  reason: ProjectWriteOffReason.rounding.dbValue,
                  writeOffDate: '2027-01-01',
                  createdAt: '2027-01-01T00:00:00.000Z',
                  updatedAt: '2027-01-01T00:00:00.000Z',
                ),
              ],
              targetYear: 2026,
            );

        expect(annualReceivable, 1200);
      },
    );
  });
}
