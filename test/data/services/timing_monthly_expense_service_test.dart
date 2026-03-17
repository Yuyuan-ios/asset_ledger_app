import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:asset_ledger/data/services/timing_monthly_expense_service.dart';
import 'package:flutter_test/flutter_test.dart';

FuelLog _fuel({
  required int date,
  required double cost,
  int id = 1,
  int deviceId = 1,
}) {
  return FuelLog(
    id: id,
    deviceId: deviceId,
    date: date,
    supplier: '测试供应商',
    liters: 1,
    cost: cost,
  );
}

MaintenanceRecord _maintenance({
  required int ymd,
  required double amount,
  int id = 1,
  int? deviceId = 1,
}) {
  return MaintenanceRecord(
    id: id,
    deviceId: deviceId,
    ymd: ymd,
    item: '测试事项',
    amount: amount,
    note: null,
  );
}

void main() {
  group('TimingMonthlyExpenseService.computeMonthlyExpense', () {
    test('aggregates fuel and maintenance in same month', () {
      final stats = TimingMonthlyExpenseService.computeMonthlyExpense(
        fuelLogs: [
          _fuel(id: 1, date: 20260310, cost: 300),
          _fuel(id: 2, date: 20260320, cost: 200),
        ],
        maintenanceRecords: [
          _maintenance(id: 1, ymd: 20260315, amount: 500),
        ],
        targetYear: 2026,
        targetMonth: 3,
        asOfDate: DateTime(2026, 3, 31),
      );

      expect(stats.monthlyFuel[2], 500);
      expect(stats.monthlyMaintenance[2], 500);
      expect(stats.monthlyTotal[2], 1000);
      expect(stats.totalFuel, 500);
      expect(stats.totalMaintenance, 500);
      expect(stats.totalExpense, 1000);
    });

    test('applies cutoffDate as min(asOfDate, targetMonthEnd)', () {
      final stats = TimingMonthlyExpenseService.computeMonthlyExpense(
        fuelLogs: [
          _fuel(id: 1, date: 20260210, cost: 100),
          _fuel(id: 2, date: 20260220, cost: 200),
          _fuel(id: 3, date: 20260301, cost: 300),
        ],
        maintenanceRecords: [
          _maintenance(id: 1, ymd: 20260214, amount: 50),
          _maintenance(id: 2, ymd: 20260216, amount: 70),
        ],
        targetYear: 2026,
        targetMonth: 3,
        asOfDate: DateTime(2026, 2, 15),
      );

      expect(stats.monthlyFuel[1], 100);
      expect(stats.monthlyMaintenance[1], 50);
      expect(stats.monthlyTotal[2], 0);
      expect(stats.totalExpense, 150);
    });

    test('skips future records after targetMonth end', () {
      final stats = TimingMonthlyExpenseService.computeMonthlyExpense(
        fuelLogs: [
          _fuel(id: 1, date: 20260331, cost: 400),
          _fuel(id: 2, date: 20260401, cost: 500),
        ],
        maintenanceRecords: [
          _maintenance(id: 1, ymd: 20260320, amount: 100),
          _maintenance(id: 2, ymd: 20260501, amount: 600),
        ],
        targetYear: 2026,
        targetMonth: 3,
        asOfDate: DateTime(2026, 5, 10),
      );

      expect(stats.monthlyTotal[2], 500);
      expect(stats.monthlyTotal[3], 0);
      expect(stats.monthlyTotal[4], 0);
      expect(stats.totalExpense, 500);
    });

    test('filters non-positive fuel cost and maintenance amount', () {
      final stats = TimingMonthlyExpenseService.computeMonthlyExpense(
        fuelLogs: [
          _fuel(id: 1, date: 20260110, cost: -10),
          _fuel(id: 2, date: 20260111, cost: 0),
          _fuel(id: 3, date: 20260112, cost: 120),
        ],
        maintenanceRecords: [
          _maintenance(id: 1, ymd: 20260115, amount: -1),
          _maintenance(id: 2, ymd: 20260116, amount: 0),
          _maintenance(id: 3, ymd: 20260117, amount: 80),
        ],
        targetYear: 2026,
        targetMonth: 1,
        asOfDate: DateTime(2026, 1, 31),
      );

      expect(stats.monthlyFuel[0], 120);
      expect(stats.monthlyMaintenance[0], 80);
      expect(stats.monthlyTotal[0], 200);
      expect(stats.totalExpense, 200);
    });

    test('keeps monthly and total expense sums consistent', () {
      final stats = TimingMonthlyExpenseService.computeMonthlyExpense(
        fuelLogs: [
          _fuel(id: 1, date: 20260105, cost: 100),
          _fuel(id: 2, date: 20260210, cost: 250),
          _fuel(id: 3, date: 20260320, cost: 150),
        ],
        maintenanceRecords: [
          _maintenance(id: 1, ymd: 20260108, amount: 40),
          _maintenance(id: 2, ymd: 20260218, amount: 60),
          _maintenance(id: 3, ymd: 20260328, amount: 90),
        ],
        targetYear: 2026,
        targetMonth: 3,
        asOfDate: DateTime(2026, 3, 31),
      );

      for (var i = 0; i < 12; i++) {
        expect(stats.monthlyTotal[i], stats.monthlyFuel[i] + stats.monthlyMaintenance[i]);
      }

      final fuelSum = stats.monthlyFuel.fold<double>(0, (sum, value) => sum + value);
      final maintenanceSum = stats.monthlyMaintenance.fold<double>(0, (sum, value) => sum + value);
      final totalSum = stats.monthlyTotal.fold<double>(0, (sum, value) => sum + value);

      expect(fuelSum, stats.totalFuel);
      expect(maintenanceSum, stats.totalMaintenance);
      expect(totalSum, stats.totalExpense);
    });
  });
}
