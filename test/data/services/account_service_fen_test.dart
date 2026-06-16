import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// R2：财务 fen 收口。锁定 [AccountService.calcMoneyFen] 与配套 fen 汇总
/// helper 的整数分口径，确保账户应收/实收/核销不再经 double 中转。
void main() {
  group('AccountService.calcMoneyFen', () {
    test('computes hours receivable in exact fen (no yuan round-trip)', () {
      const agg = ProjectAgg(
        projectKey: 'Alpha||Site X',
        contact: 'Alpha',
        site: 'Site X',
        minYmd: 20260301,
        deviceIds: [1],
        hoursByDevice: {1: 0.333},
        normalHoursByDevice: {1: 0.333},
        breakingHoursByDevice: {},
        rentIncomeTotal: 0,
      );

      final money = AccountService.calcMoneyFen(
        agg: agg,
        devices: [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        payments: const [],
      );

      // 0.333h * 100 元/h = 33.30 元 = 3330 分。
      expect(money.receivableFen, 3330);
      expect(money.receivedFen, 0);
      expect(money.writeOffFen, 0);
    });

    test('uses breaking effective rate for breaking hours', () {
      const agg = ProjectAgg(
        projectKey: 'Alpha||Site X',
        contact: 'Alpha',
        site: 'Site X',
        minYmd: 20260301,
        deviceIds: [1],
        hoursByDevice: {1: 13},
        normalHoursByDevice: {1: 10},
        breakingHoursByDevice: {1: 3},
        rentIncomeTotal: 0,
      );

      final money = AccountService.calcMoneyFen(
        agg: agg,
        devices: [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            breakingUnitPrice: 180,
            baseMeterHours: 0,
          ),
        ],
        rates: const [
          ProjectDeviceRate(
            projectKey: 'Alpha||Site X',
            deviceId: 1,
            rate: 120,
            isBreaking: false,
          ),
          ProjectDeviceRate(
            projectKey: 'Alpha||Site X',
            deviceId: 1,
            rate: 260,
            isBreaking: true,
          ),
        ],
        payments: const [],
      );

      // (10h * 120) + (3h * 260) = 1200 + 780 = 1980 元 = 198000 分。
      expect(money.receivableFen, 198000);
    });

    test('receivedFen sums AccountPayment.amountFen, not amount double', () {
      const agg = ProjectAgg(
        projectKey: 'Alpha||Site X',
        contact: 'Alpha',
        site: 'Site X',
        minYmd: 20260301,
        deviceIds: [1],
        hoursByDevice: {1: 10},
        normalHoursByDevice: {1: 10},
        breakingHoursByDevice: {},
        rentIncomeTotal: 0,
      );

      final money = AccountService.calcMoneyFen(
        agg: agg,
        devices: [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        payments: const [
          AccountPayment(
            id: 1,
            projectKey: 'Alpha||Site X',
            ymd: 20260310,
            amount: 12.34,
          ),
          AccountPayment(
            id: 2,
            projectKey: 'Alpha||Site X',
            ymd: 20260311,
            amount: 56.78,
          ),
          // 其它项目的收款不应计入。
          AccountPayment(
            id: 3,
            projectKey: 'Other||Site',
            ymd: 20260312,
            amount: 999,
          ),
        ],
      );

      expect(money.receivedFen, 1234 + 5678);
    });

    test('writeOffFen sums ProjectWriteOff.amountFen for the project', () {
      final projectId = ProjectId.legacyFromKey('Alpha||Site X');
      final agg = ProjectAgg(
        projectKey: 'Alpha||Site X',
        contact: 'Alpha',
        site: 'Site X',
        minYmd: 20260301,
        deviceIds: const [1],
        hoursByDevice: const {1: 10},
        normalHoursByDevice: const {1: 10},
        breakingHoursByDevice: const {},
        rentIncomeTotal: 0,
      );

      final money = AccountService.calcMoneyFen(
        agg: agg,
        devices: [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        payments: const [],
        writeOffs: [
          ProjectWriteOff(
            id: 'w1',
            projectId: projectId,
            amount: 60.50,
            reason: ProjectWriteOffReason.rounding.dbValue,
            writeOffDate: '2026-03-10',
            createdAt: '2026-03-10T00:00:00.000Z',
            updatedAt: '2026-03-10T00:00:00.000Z',
          ),
          ProjectWriteOff(
            id: 'w2',
            projectId: 'other-project',
            amount: 1000,
            reason: ProjectWriteOffReason.rounding.dbValue,
            writeOffDate: '2026-03-10',
            createdAt: '2026-03-10T00:00:00.000Z',
            updatedAt: '2026-03-10T00:00:00.000Z',
          ),
        ],
      );

      expect(money.writeOffFen, 6050);
    });

    test('multi-device + rent mix totals project receivable in fen', () {
      const agg = ProjectAgg(
        projectKey: 'Alpha||Site X',
        contact: 'Alpha',
        site: 'Site X',
        minYmd: 20260301,
        deviceIds: [1, 2],
        hoursByDevice: {1: 10, 2: 5},
        normalHoursByDevice: {1: 10, 2: 5},
        breakingHoursByDevice: {},
        rentIncomeTotal: 500,
        rentIncomeFen: 50000,
      );

      final money = AccountService.calcMoneyFen(
        agg: agg,
        devices: [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
          Device(
            id: 2,
            name: 'CAT 1#',
            brand: 'CAT',
            defaultUnitPrice: 80,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        payments: const [],
      );

      // (10*100) + (5*80) + rent 500 = 1000 + 400 + 500 = 1900 元 = 190000 分。
      expect(money.receivableFen, 190000);
    });
  });

  group('AccountService fen sum helpers', () {
    test('sumReceivedFenByProject can exclude one payment id', () {
      const payments = [
        AccountPayment(
          id: 1,
          projectKey: 'Alpha||Site X',
          ymd: 20260310,
          amount: 12.34,
        ),
        AccountPayment(
          id: 2,
          projectKey: 'Alpha||Site X',
          ymd: 20260311,
          amount: 56.78,
        ),
      ];

      expect(
        AccountService.sumReceivedFenByProject(
          projectKey: 'Alpha||Site X',
          payments: payments,
        ),
        1234 + 5678,
      );
      expect(
        AccountService.sumReceivedFenByProject(
          projectKey: 'Alpha||Site X',
          payments: payments,
          excludePaymentId: 2,
        ),
        1234,
      );
    });

    test('fen accumulation stays exact across many small payments', () {
      final payments = [
        for (var i = 0; i < 1000; i += 1)
          AccountPayment(
            id: i + 1,
            projectKey: 'Alpha||Site X',
            ymd: 20260310,
            amount: 0.01,
          ),
      ];

      // 1000 笔 0.01 元 = 1000 分，整数累加不产生浮点漂移。
      expect(
        AccountService.sumReceivedFenByProject(
          projectKey: 'Alpha||Site X',
          payments: payments,
        ),
        1000,
      );
    });
  });

  group('AccountService.buildProjects rentIncomeFen', () {
    test('accumulates rent income per record in fen', () {
      final projects = AccountService.buildProjects(
        timingRecords: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260301,
            contact: 'Alice',
            site: 'Yard A',
            type: TimingType.rent,
            startMeter: 0,
            endMeter: 0,
            hours: 0,
            income: 800,
          ),
          TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260302,
            contact: 'Alice',
            site: 'Yard A',
            type: TimingType.rent,
            startMeter: 0,
            endMeter: 0,
            hours: 0,
            income: 200.5,
          ),
          TimingRecord(
            id: 3,
            deviceId: 1,
            startDate: 20260303,
            contact: 'Alice',
            site: 'Yard A',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 4,
            hours: 4,
            income: 0,
          ),
        ],
      );

      final projectId = ProjectId.legacyFromParts(
        contact: 'Alice',
        site: 'Yard A',
      );
      final agg = projects[projectId]!;

      // 800.00 + 200.50 = 1000.50 元 = 100050 分（逐记录 round 后累加）。
      expect(agg.rentIncomeFen, 100050);
      expect(agg.rentIncomeTotal, closeTo(1000.5, 0.000001));
    });
  });
}
