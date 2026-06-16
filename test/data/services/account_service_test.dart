import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_id.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/account_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountService.buildProjects', () {
    test(
      'groups by trimmed project key and separates rent income from hours',
      () {
        final projects = AccountService.buildProjects(
          timingRecords: [
            TimingRecord(
              id: 1,
              deviceId: 2,
              startDate: 20260303,
              contact: ' Alice ',
              site: ' Yard A ',
              type: TimingType.hours,
              startMeter: 10,
              endMeter: 14,
              hours: 4,
              income: 0,
            ),
            TimingRecord(
              id: 2,
              deviceId: 2,
              startDate: 20260301,
              contact: 'Alice',
              site: 'Yard A',
              type: TimingType.rent,
              startMeter: 14,
              endMeter: 14,
              hours: 0,
              income: 800,
            ),
            TimingRecord(
              id: 3,
              deviceId: 3,
              startDate: 20260302,
              contact: '',
              site: 'Ignored',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 1,
              hours: 1,
              income: 100,
            ),
          ],
        );

        final projectId = ProjectId.legacyFromParts(
          contact: 'Alice',
          site: 'Yard A',
        );
        final project = projects[projectId]!;

        expect(projects.keys, [projectId]);
        expect(project.projectKey, 'Alice||Yard A');
        expect(project.minYmd, 20260301);
        expect(project.deviceIds, [2]);
        expect(project.hoursByDevice[2], 4);
        expect(project.rentIncomeTotal, 800);
      },
    );

    test(
      'rent displayEndDate does not affect account receivable or incomeFen',
      () {
        final baseRecord = TimingRecord(
          id: 4,
          deviceId: 2,
          startDate: 20260301,
          contact: 'Alice',
          site: 'Yard A',
          type: TimingType.rent,
          startMeter: 14,
          endMeter: 14,
          hours: 0,
          income: 800.25,
        );
        final displayRecord = baseRecord.copyWith(displayEndDate: 20260430);
        final devices = [
          Device(
            id: 2,
            name: 'SANY 2#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ];

        final baseProject = AccountService.buildProjects(
          timingRecords: [baseRecord],
        ).values.single;
        final displayProject = AccountService.buildProjects(
          timingRecords: [displayRecord],
        ).values.single;
        final baseMoney = AccountService.calcMoney(
          agg: baseProject,
          devices: devices,
          rates: [],
          payments: [],
        );
        final displayMoney = AccountService.calcMoney(
          agg: displayProject,
          devices: devices,
          rates: [],
          payments: [],
        );
        final baseMoneyFen = AccountService.calcMoneyFen(
          agg: baseProject,
          devices: devices,
          rates: [],
          payments: [],
        );
        final displayMoneyFen = AccountService.calcMoneyFen(
          agg: displayProject,
          devices: devices,
          rates: [],
          payments: [],
        );

        expect(displayRecord.incomeFen, baseRecord.incomeFen);
        expect(displayProject.rentIncomeTotal, baseProject.rentIncomeTotal);
        expect(displayProject.rentIncomeFen, baseProject.rentIncomeFen);
        expect(displayMoney.receivable, baseMoney.receivable);
        expect(displayMoney.remaining, baseMoney.remaining);
        expect(displayMoneyFen.receivableFen, baseMoneyFen.receivableFen);
        expect(displayMoneyFen.receivedFen, baseMoneyFen.receivedFen);
        expect(displayMoneyFen.writeOffFen, baseMoneyFen.writeOffFen);
      },
    );

    test(
      'aggregates multi-device multi-mode hours with interleaved dates and correct minYmd',
      () {
        final projects = AccountService.buildProjects(
          timingRecords: [
            TimingRecord(
              id: 11,
              deviceId: 2,
              startDate: 20260305,
              contact: 'Mix',
              site: 'Site',
              type: TimingType.hours,
              startMeter: 10,
              endMeter: 14,
              hours: 4,
              income: 0,
            ),
            TimingRecord(
              id: 12,
              deviceId: 1,
              startDate: 20260301,
              contact: 'Mix',
              site: 'Site',
              type: TimingType.hours,
              isBreaking: true,
              startMeter: 20,
              endMeter: 21.5,
              hours: 1.5,
              income: 0,
            ),
            TimingRecord(
              id: 13,
              deviceId: 1,
              startDate: 20260303,
              contact: 'Mix',
              site: 'Site',
              type: TimingType.hours,
              startMeter: 21.5,
              endMeter: 23.5,
              hours: 2,
              income: 0,
            ),
            TimingRecord(
              id: 14,
              deviceId: 2,
              startDate: 20260302,
              contact: 'Mix',
              site: 'Site',
              type: TimingType.hours,
              isBreaking: true,
              startMeter: 14,
              endMeter: 17,
              hours: 3,
              income: 0,
            ),
            TimingRecord(
              id: 15,
              deviceId: 2,
              startDate: 20260228,
              contact: 'Mix',
              site: 'Site',
              type: TimingType.rent,
              startMeter: 17,
              endMeter: 17,
              hours: 0,
              income: 900,
            ),
          ],
        );

        final project =
            projects[ProjectId.legacyFromParts(contact: 'Mix', site: 'Site')]!;

        expect(project.deviceIds, [1, 2]);
        expect(project.minYmd, 20260228);
        expect(project.hoursByDevice, {1: 3.5, 2: 7.0});
        expect(project.normalHoursByDevice, {1: 2.0, 2: 4.0});
        expect(project.breakingHoursByDevice, {1: 1.5, 2: 3.0});
        expect(project.rentIncomeTotal, 900);
      },
    );
  });

  group('AccountService money helpers', () {
    test(
      'uses project overrides and can exclude a payment from received total',
      () {
        const agg = ProjectAgg(
          projectKey: 'Alice||Yard A',
          contact: 'Alice',
          site: 'Yard A',
          minYmd: 20260301,
          deviceIds: [1, 2],
          hoursByDevice: {1: 2, 2: 3},
          normalHoursByDevice: {1: 2, 2: 3},
          breakingHoursByDevice: {},
          rentIncomeTotal: 500,
        );

        final money = AccountService.calcMoney(
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
              defaultUnitPrice: 200,
              baseMeterHours: 0,
            ),
          ],
          rates: [
            ProjectDeviceRate(
              projectKey: 'Alice||Yard A',
              deviceId: 2,
              rate: 250,
            ),
          ],
          payments: [
            AccountPayment(
              id: 1,
              projectKey: 'Alice||Yard A',
              ymd: 20260310,
              amount: 300,
            ),
            AccountPayment(
              id: 2,
              projectKey: 'Alice||Yard A',
              ymd: 20260311,
              amount: 100,
            ),
          ],
        );

        final receivedExcluding = AccountService.sumReceivedByProject(
          projectKey: 'Alice||Yard A',
          payments: [
            AccountPayment(
              id: 1,
              projectKey: 'Alice||Yard A',
              ymd: 20260310,
              amount: 300,
            ),
            AccountPayment(
              id: 2,
              projectKey: 'Alice||Yard A',
              ymd: 20260311,
              amount: 100,
            ),
          ],
          excludePaymentId: 2,
        );

        final rateInfo = AccountService.calcRateInfo(
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
              defaultUnitPrice: 200,
              baseMeterHours: 0,
            ),
          ],
          rates: [
            ProjectDeviceRate(
              projectKey: 'Alice||Yard A',
              deviceId: 2,
              rate: 250,
            ),
          ],
        );

        expect(money.receivable, 1450);
        expect(money.received, 400);
        expect(money.writeOff, 0);
        expect(money.remaining, 1050);
        expect(money.ratio, closeTo(400 / 1450, 0.000001));
        expect(money.settlementRatio, closeTo(400 / 1450, 0.000001));
        expect(receivedExcluding, 300);
        expect(rateInfo.minRate, 100);
        expect(rateInfo.isMultiDevice, isTrue);
      },
    );

    test(
      'deducts write-offs from remaining but not received or receivable',
      () {
        const agg = ProjectAgg(
          projectKey: 'Alice||Yard A',
          contact: 'Alice',
          site: 'Yard A',
          minYmd: 20260301,
          deviceIds: [],
          hoursByDevice: {},
          normalHoursByDevice: {},
          breakingHoursByDevice: {},
          rentIncomeTotal: 1260,
        );

        final money = AccountService.calcMoney(
          agg: agg,
          devices: [],
          rates: [],
          payments: [
            AccountPayment(
              id: 1,
              projectKey: 'Alice||Yard A',
              ymd: 20260310,
              amount: 1200,
            ),
          ],
          writeOffs: [
            ProjectWriteOff(
              id: 'write-off-1',
              projectId: ProjectId.legacyFromKey('Alice||Yard A'),
              amount: 60,
              reason: ProjectWriteOffReason.rounding.dbValue,
              writeOffDate: '2026-03-10',
              createdAt: '2026-03-10T00:00:00.000Z',
              updatedAt: '2026-03-10T00:00:00.000Z',
            ),
          ],
        );

        expect(money.receivable, 1260);
        expect(money.received, 1200);
        expect(money.writeOff, 60);
        expect(money.remaining, 0);
        expect(money.ratio, closeTo(1200 / 1260, 0.000001));
        expect(money.settlementRatio, 1.0);
      },
    );

    test(
      'calcMoney computes receivable/remaining/ratio with normal+breaking+rent mix',
      () {
        const agg = ProjectAgg(
          projectKey: 'Alpha||Site X',
          contact: 'Alpha',
          site: 'Site X',
          minYmd: 20260301,
          deviceIds: [1, 2],
          hoursByDevice: {1: 13, 2: 2},
          normalHoursByDevice: {1: 10},
          breakingHoursByDevice: {1: 3, 2: 2},
          rentIncomeTotal: 500,
        );

        final money = AccountService.calcMoney(
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
            Device(
              id: 2,
              name: 'CAT 1#',
              brand: 'CAT',
              defaultUnitPrice: 80,
              baseMeterHours: 0,
            ),
          ],
          rates: [
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
          payments: [
            AccountPayment(
              id: 1,
              projectKey: 'Alpha||Site X',
              ymd: 20260310,
              amount: 300,
            ),
            AccountPayment(
              id: 2,
              projectKey: 'Alpha||Site X',
              ymd: 20260311,
              amount: 500,
            ),
          ],
        );

        // receivable = (10*120) + (3*260) + (2*80) + 500 = 2640
        expect(money.receivable, 2640);
        expect(money.received, 800);
        expect(money.remaining, 1840);
        expect(money.ratio, closeTo(800 / 2640, 0.000001));
      },
    );

    test(
      'buildEffectiveRateMap in breaking mode uses override first, then breaking fallback/default',
      () {
        final result = AccountService.buildEffectiveRateMap(
          projectKey: 'Alpha||Site X',
          devices: [
            Device(
              id: 1,
              name: 'SANY 1#',
              brand: 'SANY',
              defaultUnitPrice: 100,
              breakingUnitPrice: 160,
              baseMeterHours: 0,
            ),
            Device(
              id: 2,
              name: 'CAT 1#',
              brand: 'CAT',
              defaultUnitPrice: 90,
              baseMeterHours: 0,
            ),
          ],
          rates: [
            ProjectDeviceRate(
              projectKey: 'Alpha||Site X',
              deviceId: 1,
              rate: 130,
              isBreaking: false,
            ),
            ProjectDeviceRate(
              projectKey: 'Alpha||Site X',
              deviceId: 1,
              rate: 240,
              isBreaking: true,
            ),
            ProjectDeviceRate(
              projectKey: 'Other||Site',
              deviceId: 2,
              rate: 300,
              isBreaking: true,
            ),
          ],
          isBreaking: true,
        );

        expect(result.length, 2);
        expect(result[1], 240); // project breaking override wins
        expect(result[2], 90); // no breaking price -> fallback to default
      },
    );

    test(
      'calcRateInfo marks same-device normal+breaking hours as multi-mode',
      () {
        const agg = ProjectAgg(
          projectKey: 'Alpha||Site X',
          contact: 'Alpha',
          site: 'Site X',
          minYmd: 20260301,
          deviceIds: [1],
          hoursByDevice: {1: 7},
          normalHoursByDevice: {1: 5},
          breakingHoursByDevice: {1: 2},
          rentIncomeTotal: 0,
        );

        final info = AccountService.calcRateInfo(
          agg: agg,
          devices: [
            Device(
              id: 1,
              name: 'SANY 1#',
              brand: 'SANY',
              defaultUnitPrice: 100,
              breakingUnitPrice: 150,
              baseMeterHours: 0,
            ),
          ],
          rates: [],
        );

        expect(info.isMultiMode, isTrue);
        expect(info.isMultiDevice, isFalse);
        expect(info.minRate, 100);
      },
    );

    test(
      'calcRateInfo uses breaking rate when a project only has breaking hours',
      () {
        const agg = ProjectAgg(
          projectKey: 'Zhao||Shangyi',
          contact: '赵六',
          site: '尚义',
          minYmd: 20260317,
          deviceIds: [1],
          hoursByDevice: {1: 9},
          normalHoursByDevice: {},
          breakingHoursByDevice: {1: 9},
          rentIncomeTotal: 0,
        );

        final info = AccountService.calcRateInfo(
          agg: agg,
          devices: [
            Device(
              id: 1,
              name: 'SANY 1#',
              brand: 'SANY',
              defaultUnitPrice: 120,
              breakingUnitPrice: 200,
              baseMeterHours: 0,
            ),
          ],
          rates: [],
        );

        expect(info.isMultiMode, isFalse);
        expect(info.isMultiDevice, isFalse);
        expect(info.minRate, 200);
      },
    );

    test(
      'calcReceivableByDevice aggregates same device across projects with per-project overrides',
      () {
        final totals = AccountService.calcReceivableByDevice(
          timingRecords: [
            // Project A: device 1
            TimingRecord(
              id: 21,
              deviceId: 1,
              startDate: 20260301,
              contact: 'A',
              site: 'X',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 10,
              hours: 10,
              income: 0,
            ),
            TimingRecord(
              id: 22,
              deviceId: 1,
              startDate: 20260302,
              contact: 'A',
              site: 'X',
              type: TimingType.hours,
              isBreaking: true,
              startMeter: 10,
              endMeter: 12,
              hours: 2,
              income: 0,
            ),
            // rent is fixed income and belongs to the bound device.
            TimingRecord(
              id: 23,
              deviceId: 1,
              startDate: 20260303,
              contact: 'A',
              site: 'X',
              type: TimingType.rent,
              startMeter: 12,
              endMeter: 12,
              hours: 0,
              income: 700,
            ),
            // Project B: device 1 + device 2
            TimingRecord(
              id: 24,
              deviceId: 1,
              startDate: 20260304,
              contact: 'B',
              site: 'Y',
              type: TimingType.hours,
              startMeter: 100,
              endMeter: 103,
              hours: 3,
              income: 0,
            ),
            TimingRecord(
              id: 25,
              deviceId: 1,
              startDate: 20260305,
              contact: 'B',
              site: 'Y',
              type: TimingType.hours,
              isBreaking: true,
              startMeter: 103,
              endMeter: 104,
              hours: 1,
              income: 0,
            ),
            TimingRecord(
              id: 26,
              deviceId: 2,
              startDate: 20260306,
              contact: 'B',
              site: 'Y',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 4,
              hours: 4,
              income: 0,
            ),
          ],
          devices: [
            Device(
              id: 1,
              name: 'SANY 1#',
              brand: 'SANY',
              defaultUnitPrice: 100,
              breakingUnitPrice: 150,
              baseMeterHours: 0,
            ),
            Device(
              id: 2,
              name: 'LIUGONG 1#',
              brand: 'LIUGONG',
              defaultUnitPrice: 200,
              baseMeterHours: 0,
            ),
          ],
          rates: [
            // Project A override
            ProjectDeviceRate(
              projectKey: 'A||X',
              deviceId: 1,
              rate: 120,
              isBreaking: false,
            ),
            // Project B overrides
            ProjectDeviceRate(
              projectKey: 'B||Y',
              deviceId: 1,
              rate: 180,
              isBreaking: false,
            ),
            ProjectDeviceRate(
              projectKey: 'B||Y',
              deviceId: 1,
              rate: 260,
              isBreaking: true,
            ),
            ProjectDeviceRate(
              projectKey: 'B||Y',
              deviceId: 2,
              rate: 250,
              isBreaking: false,
            ),
          ],
        );

        // device 1 total: 10*120 + 2*150 + 700 rent + 3*180 + 1*260 = 3000
        // device 2 total: 4*250 = 1000
        expect(totals.length, 2);
        expect(totals[1], 3000);
        expect(totals[2], 1000);
      },
    );

    test(
      'calcReceivableByDevice counts rent income once for the bound device',
      () {
        final totals = AccountService.calcReceivableByDevice(
          timingRecords: [
            TimingRecord(
              id: 31,
              deviceId: 1,
              startDate: 20260516,
              contact: '周亮',
              site: '成都',
              type: TimingType.rent,
              startMeter: 6180.7,
              endMeter: 6180.7,
              hours: 0,
              income: 22000,
            ),
            TimingRecord(
              id: 32,
              deviceId: 1,
              startDate: 20260517,
              contact: '周亮',
              site: '成都',
              type: TimingType.rent,
              startMeter: 6180.7,
              endMeter: 6184.7,
              hours: 4,
              income: 5000,
            ),
          ],
          devices: [
            Device(
              id: 1,
              name: 'HITACHI 1#',
              brand: 'HITACHI',
              defaultUnitPrice: 100,
              baseMeterHours: 0,
            ),
          ],
          rates: [],
        );

        expect(totals[1], 27000);
      },
    );
  });
}
