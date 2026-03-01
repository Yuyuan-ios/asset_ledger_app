import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/features/account/use_cases/compute_account_summary_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComputeAccountSummaryUseCase edge cases', () {
    test('returns empty summaries and a null total ratio when there is no receivable', () {
      const useCase = ComputeAccountSummaryUseCase();

      final result = useCase.execute(
        timingRecords: const [],
        devices: const [],
        rates: const [],
        payments: const [],
      );

      expect(result.projects, isEmpty);
      expect(result.totalReceivable, 0);
      expect(result.totalReceived, 0);
      expect(result.totalRemaining, 0);
      expect(result.totalRatio, isNull);
      expect(result.deviceReceivables, isEmpty);
    });

    test('creates fallback device names for unknown ids and sorts them by name length', () {
      const useCase = ComputeAccountSummaryUseCase();

      final result = useCase.execute(
        timingRecords: const [
          TimingRecord(
            id: 1,
            deviceId: 12,
            startDate: 20260301,
            contact: 'Alice',
            site: 'Yard A',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 1,
            hours: 1,
            income: 0,
          ),
          TimingRecord(
            id: 2,
            deviceId: 3,
            startDate: 20260302,
            contact: 'Alice',
            site: 'Yard A',
            type: TimingType.hours,
            startMeter: 1,
            endMeter: 2,
            hours: 1,
            income: 0,
          ),
        ],
        devices: const [],
        rates: const [
          ProjectDeviceRate(
            projectKey: 'Alice||Yard A',
            deviceId: 12,
            rate: 120,
          ),
          ProjectDeviceRate(
            projectKey: 'Alice||Yard A',
            deviceId: 3,
            rate: 90,
          ),
        ],
        payments: const [],
      );

      expect(
        result.deviceReceivables.map((item) => item.name).toList(),
        ['设备#3', '设备#12'],
      );
      expect(result.deviceReceivables.map((item) => item.amount).toList(), [
        90.0,
        120.0,
      ]);
    });
  });
}
