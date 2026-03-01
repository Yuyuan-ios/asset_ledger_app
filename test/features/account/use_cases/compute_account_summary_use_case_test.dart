import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/account/use_cases/compute_account_summary_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComputeAccountSummaryUseCase', () {
    test('builds project summaries with correct sorting and money totals', () {
      const useCase = ComputeAccountSummaryUseCase();

      final result = useCase.execute(
        timingRecords: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260103,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 102,
            hours: 2,
            income: 0,
          ),
          TimingRecord(
            id: 2,
            deviceId: 2,
            startDate: 20260105,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 200,
            endMeter: 203,
            hours: 3,
            income: 0,
          ),
          TimingRecord(
            id: 3,
            deviceId: 2,
            startDate: 20260106,
            contact: '李洋',
            site: '万达',
            type: TimingType.rent,
            startMeter: 203,
            endMeter: 203,
            hours: 0,
            income: 500,
          ),
          TimingRecord(
            id: 4,
            deviceId: 3,
            startDate: 20260110,
            contact: '张扬',
            site: '修文水厂',
            type: TimingType.hours,
            startMeter: 50,
            endMeter: 51,
            hours: 1,
            income: 0,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
          Device(
            id: 2,
            name: 'HITACHI 1#',
            brand: 'HITACHI',
            defaultUnitPrice: 120,
            baseMeterHours: 0,
          ),
          Device(
            id: 3,
            name: 'SUNWARD 3#',
            brand: 'SUNWARD',
            defaultUnitPrice: 200,
            baseMeterHours: 0,
          ),
        ],
        rates: const [
          ProjectDeviceRate(
            projectKey: '李洋||万达',
            deviceId: 2,
            rate: 150,
          ),
        ],
        payments: const [
          AccountPayment(
            id: 1,
            projectKey: '李洋||万达',
            ymd: 20260120,
            amount: 200,
          ),
          AccountPayment(
            id: 2,
            projectKey: '李洋||万达',
            ymd: 20260118,
            amount: 100,
          ),
          AccountPayment(
            id: 3,
            projectKey: '张扬||修文水厂',
            ymd: 20260112,
            amount: 50,
          ),
        ],
      );

      expect(result.projects, hasLength(2));
      expect(result.projects.first.displayName, '张扬 + 修文水厂');
      expect(result.projects.last.displayName, '李洋 + 万达');

      final wanda = result.projects.last;
      expect(wanda.receivable, 1150);
      expect(wanda.received, 300);
      expect(wanda.remaining, 850);
      expect(wanda.ratio, closeTo(300 / 1150, 0.000001));
      expect(wanda.minRate, 100);
      expect(wanda.isMultiDevice, isTrue);
      expect(wanda.payments.map((payment) => payment.ymd).toList(), [
        20260120,
        20260118,
      ]);

      expect(result.totalReceivable, 1350);
      expect(result.totalReceived, 350);
      expect(result.totalRemaining, 1000);
      expect(result.totalRatio, closeTo(350 / 1350, 0.000001));

      expect(
        result.deviceReceivables.any(
          (device) => device.deviceId == 2 && device.amount == 450,
        ),
        isTrue,
      );
      expect(
        result.deviceReceivables.any(
          (device) => device.deviceId == 3 && device.amount == 200,
        ),
        isTrue,
      );
    });
  });
}
