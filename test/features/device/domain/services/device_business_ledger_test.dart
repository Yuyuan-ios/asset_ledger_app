import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/account_project_merge_group.dart';
import 'package:asset_ledger/data/models/account_project_merge_group_with_members.dart';
import 'package:asset_ledger/data/models/account_project_merge_member.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/account/use_cases/compute_account_summary_use_case.dart';
import 'package:asset_ledger/features/device/domain/services/device_business_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceBusinessLedgerUseCase', () {
    test(
      'uses account summary device income and keeps unit totals separate',
      () {
        const devices = [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
          Device(
            id: 2,
            name: 'HITACHI 2#',
            brand: 'HITACHI',
            defaultUnitPrice: 120,
            baseMeterHours: 0,
          ),
        ];
        const timingRecords = [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260103,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 102.5,
            hours: 2.5,
            income: 0,
            unit: MeasureUnit.hour,
            quantityScaled: 2500,
          ),
          TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260104,
            contact: '李洋',
            site: '万达',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 0,
            hours: 0,
            income: 0,
            unit: MeasureUnit.trip,
            quantityScaled: 3000,
          ),
          TimingRecord(
            id: 3,
            deviceId: 1,
            startDate: 20260201,
            contact: '张扬',
            site: '药山',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 0,
            hours: 0,
            income: 0,
            unit: MeasureUnit.mu,
            quantityScaled: 12500,
          ),
        ];
        const rates = [
          ProjectDeviceRate(projectKey: '张扬||药山', deviceId: 1, rate: 80),
        ];
        const payments = [
          AccountPayment(
            id: 1,
            projectKey: '李洋||万达',
            ymd: 20260110,
            amount: 100,
          ),
          AccountPayment(
            id: 2,
            projectKey: '张扬||药山',
            ymd: 20260210,
            amount: 1000,
          ),
        ];

        const accountUseCase = ComputeAccountSummaryUseCase();
        const useCase = DeviceBusinessLedgerUseCase(
          accountSummaryUseCase: accountUseCase,
        );

        final accountSummary = accountUseCase.execute(
          timingRecords: timingRecords,
          devices: devices,
          rates: rates,
          payments: payments,
        );
        final ledgers = useCase.execute(
          timingRecords: timingRecords,
          devices: devices,
          rates: rates,
          payments: payments,
        );

        final deviceOne = ledgers.firstWhere((ledger) => ledger.deviceId == 1);
        final accountDeviceOne = accountSummary.deviceReceivables.firstWhere(
          (item) => item.deviceId == 1,
        );

        expect(deviceOne.incomeFen, accountDeviceOne.amountFen);
        expect(deviceOne.incomeFen, 155000);
        expect(deviceOne.unitTotals.map((total) => total.unit), [
          MeasureUnit.hour,
          MeasureUnit.mu,
          MeasureUnit.trip,
        ]);
        expect(deviceOne.unitTotals.map((total) => total.quantityScaled), [
          2500,
          12500,
          3000,
        ]);

        expect(deviceOne.projects.map((project) => project.projectName), [
          '张扬 · 药山',
          '李洋 · 万达',
        ]);
        expect(
          deviceOne.projects.first.paymentStatus,
          DeviceBusinessPaymentStatus.settled,
        );
        expect(
          deviceOne.projects.last.paymentStatus,
          DeviceBusinessPaymentStatus.partial,
        );
        expect(deviceOne.projects.last.remainingFen, 45000);

        final deviceTwo = ledgers.firstWhere((ledger) => ledger.deviceId == 2);
        expect(deviceTwo.incomeFen, 0);
        expect(deviceTwo.unitTotals, isEmpty);
        expect(deviceTwo.projects, isEmpty);
      },
    );

    test('filters ledgers to the same summary year as the account page', () {
      const devices = [
        Device(
          id: 1,
          name: 'SANY 1#',
          brand: 'SANY',
          defaultUnitPrice: 100,
          baseMeterHours: 0,
        ),
      ];
      const timingRecords = [
        TimingRecord(
          id: 1,
          deviceId: 1,
          startDate: 20250103,
          contact: '旧项目',
          site: 'A',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 1,
          hours: 1,
          income: 0,
          unit: MeasureUnit.hour,
          quantityScaled: 1000,
        ),
        TimingRecord(
          id: 2,
          deviceId: 1,
          startDate: 20260103,
          contact: '新项目',
          site: 'B',
          type: TimingType.hours,
          startMeter: 1,
          endMeter: 3,
          hours: 2,
          income: 0,
          unit: MeasureUnit.hour,
          quantityScaled: 2000,
        ),
      ];

      const useCase = DeviceBusinessLedgerUseCase();
      final ledger = useCase
          .execute(
            timingRecords: timingRecords,
            devices: devices,
            rates: const [],
            payments: const [],
            summaryYear: 2026,
          )
          .single;

      expect(ledger.incomeFen, 20000);
      expect(ledger.unitTotals.single.quantityScaled, 2000);
      expect(ledger.projects.single.projectName, '新项目 · B');
    });

    test(
      'merged account project name does not pass through member worker names',
      () {
        const devices = [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ];
        const timingRecords = [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260103,
            contact: '外协工人A',
            site: '一号线',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 2,
            hours: 2,
            income: 0,
            unit: MeasureUnit.hour,
            quantityScaled: 2000,
          ),
          TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260104,
            contact: '外协工人B',
            site: '二号线',
            type: TimingType.hours,
            startMeter: 2,
            endMeter: 5,
            hours: 3,
            income: 0,
            unit: MeasureUnit.hour,
            quantityScaled: 3000,
          ),
        ];
        const activeMergeGroups = [
          AccountProjectMergeGroupWithMembers(
            group: AccountProjectMergeGroup(
              id: 9,
              contact: '业主甲',
              createdAt: '2026-01-10T00:00:00.000Z',
            ),
            members: [
              AccountProjectMergeMember(
                groupId: 9,
                projectKey: '外协工人A||一号线',
                contact: '外协工人A',
                site: '一号线',
                sortOrder: 0,
                createdAt: '2026-01-10T00:00:00.000Z',
              ),
              AccountProjectMergeMember(
                groupId: 9,
                projectKey: '外协工人B||二号线',
                contact: '外协工人B',
                site: '二号线',
                sortOrder: 1,
                createdAt: '2026-01-10T00:00:00.000Z',
              ),
            ],
          ),
        ];

        const useCase = DeviceBusinessLedgerUseCase();
        final ledger = useCase
            .execute(
              timingRecords: timingRecords,
              devices: devices,
              rates: const [],
              payments: const [],
              activeMergeGroups: activeMergeGroups,
            )
            .single;

        expect(ledger.projects, hasLength(1));
        expect(ledger.projects.single.projectName, '业主甲 · 合并2项目');
        expect(ledger.projects.single.projectName, isNot(contains('外协工人')));
        expect(ledger.projects.single.unitTotals.single.quantityScaled, 5000);
      },
    );
  });
}
