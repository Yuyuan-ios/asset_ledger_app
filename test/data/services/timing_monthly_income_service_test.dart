import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/project_key.dart';
import 'package:asset_ledger/data/models/project_write_off.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/services/timing_monthly_income_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimingMonthlyIncomeService.computeMonthlyIncomeRealtime', () {
    ProjectWriteOff writeOff(String projectId, double amount) {
      return ProjectWriteOff(
        id: 'wo-$projectId-$amount',
        projectId: projectId,
        amount: amount,
        reason: ProjectWriteOffReason.settlement.dbValue,
        writeOffDate: '2026-05-31',
        createdAt: '2026-05-31T10:00:00.000',
        updatedAt: '2026-05-31T10:00:00.000',
      );
    }

    TimingRecord legacyHoursRecord({
      required int id,
      required int deviceId,
      required int startDate,
      required double hours,
      int? allocationCutoffExclusiveYmd,
      String projectId = '',
      double startMeter = 0,
      String contact = '甲方',
      String site = '工地',
    }) {
      return TimingRecord(
        id: id,
        projectId: projectId,
        deviceId: deviceId,
        startDate: startDate,
        allocationCutoffDate: allocationCutoffExclusiveYmd,
        contact: contact,
        site: site,
        type: TimingType.hours,
        startMeter: startMeter,
        endMeter: startMeter + hours,
        hours: hours,
        income: 0,
      );
    }

    Device legacyDevice({required int id, double rate = 100}) {
      return Device(
        id: id,
        name: 'Device $id',
        brand: 'Brand $id',
        defaultUnitPrice: rate,
        baseMeterHours: 0,
      );
    }

    TimingRecord rentRecord({
      required int id,
      required int deviceId,
      required int startDate,
      required double income,
      int? incomeFen,
      String projectId = '',
      String contact = '甲方',
      String site = '工地',
    }) {
      return TimingRecord(
        id: id,
        projectId: projectId,
        deviceId: deviceId,
        startDate: startDate,
        contact: contact,
        site: site,
        type: TimingType.rent,
        startMeter: 0,
        endMeter: 0,
        hours: 0,
        income: income,
        incomeFen: incomeFen,
      );
    }

    List<double> computeLegacyMonthlyIncome({
      required List<TimingRecord> records,
      required List<Device> devices,
      required int targetMonth,
      required DateTime asOfDate,
      List<ProjectWriteOff> projectWriteOffs = const [],
    }) {
      return TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: records,
        devices: devices,
        rates: const [],
        targetYear: 2026,
        targetMonth: targetMonth,
        asOfDate: asOfDate,
        projectWriteOffs: projectWriteOffs,
      );
    }

    group('implicit allocation cutoff legacy behavior', () {
      test('rent income uses incomeFen as the money authority', () {
        final monthly = computeLegacyMonthlyIncome(
          records: [
            rentRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260310,
              income: 9999,
              incomeFen: 12345,
            ),
          ],
          devices: [legacyDevice(id: 1)],
          targetMonth: 3,
          asOfDate: DateTime(2026, 3, 31),
        );

        expect(monthly[2], 123.45);
      });

      test(
        'different-day next same-device record acts as exclusive implicit cutoff',
        () {
          final monthly = computeLegacyMonthlyIncome(
            records: [
              legacyHoursRecord(
                id: 1,
                deviceId: 1,
                startDate: 20260601,
                hours: 9,
              ),
              legacyHoursRecord(
                id: 2,
                deviceId: 1,
                startDate: 20260610,
                startMeter: 9,
                hours: 31,
              ),
            ],
            devices: [legacyDevice(id: 1)],
            targetMonth: 7,
            asOfDate: DateTime(2026, 7, 10),
          );

          // A: Jun 1-Jun 9, 9 days at 100/day = 900.
          // B has no next same-device record, so its open segment defaults to
          // the first day of the next month instead of spilling into July.
          expect(monthly[5], closeTo(4000.0, 0.001));
          expect(monthly[6], closeTo(0.0, 0.001));
          expect(monthly.take(5).every((v) => v == 0.0), isTrue);
          expect(monthly.skip(7).every((v) => v == 0.0), isTrue);
        },
      );

      test(
        'same-day same-device records preserve one-day legacy allocation',
        () {
          final monthly = computeLegacyMonthlyIncome(
            records: [
              legacyHoursRecord(
                id: 1,
                deviceId: 1,
                startDate: 20260601,
                hours: 2,
              ),
              legacyHoursRecord(
                id: 2,
                deviceId: 1,
                startDate: 20260601,
                startMeter: 2,
                hours: 3,
              ),
            ],
            devices: [legacyDevice(id: 1)],
            targetMonth: 6,
            asOfDate: DateTime(2026, 6, 1),
          );

          // Same-day records keep the legacy one-day behavior:
          // A contributes 2h * 100, B contributes 3h * 100.
          expect(monthly[5], closeTo(500.0, 0.001));
          expect(monthly.take(5).every((v) => v == 0.0), isTrue);
          expect(monthly.skip(6).every((v) => v == 0.0), isTrue);
        },
      );

      test(
        'same-day records and later next start preserve legacy mixed allocation model',
        () {
          final records = [
            legacyHoursRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260601,
              hours: 2,
            ),
            legacyHoursRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260601,
              startMeter: 2,
              hours: 9,
            ),
            legacyHoursRecord(
              id: 3,
              deviceId: 1,
              startDate: 20260610,
              startMeter: 11,
              hours: 1,
            ),
          ];

          final beforeLaterStart = computeLegacyMonthlyIncome(
            records: records,
            devices: [legacyDevice(id: 1)],
            targetMonth: 6,
            asOfDate: DateTime(2026, 6, 9),
          );
          final atLaterStart = computeLegacyMonthlyIncome(
            records: records,
            devices: [legacyDevice(id: 1)],
            targetMonth: 6,
            asOfDate: DateTime(2026, 6, 10),
          );

          // A keeps one legacy day: 2h * 100 = 200.
          // B spans Jun 1-Jun 9 before C starts: 9h * 100 = 900.
          // C starts contributing on Jun 10: 1h * 100 = 100.
          expect(beforeLaterStart[5], closeTo(1100.0, 0.001));
          expect(atLaterStart[5], closeTo(1200.0, 0.001));
        },
      );

      test('last same-device record defaults to start month only', () {
        final monthly = computeLegacyMonthlyIncome(
          records: [
            legacyHoursRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260601,
              hours: 40,
            ),
          ],
          devices: [legacyDevice(id: 1)],
          targetMonth: 7,
          asOfDate: DateTime(2026, 7, 10),
        );

        // No next same-device record and no explicit cutoff: the full realtime
        // income is shown only in the start month using an implicit Jul 1
        // boundary.
        expect(monthly[5], closeTo(4000.0, 0.001));
        expect(monthly[6], closeTo(0.0, 0.001));
        expect(monthly.take(5).every((v) => v == 0.0), isTrue);
        expect(monthly.skip(7).every((v) => v == 0.0), isTrue);
      });

      test(
        'cross-month implicit cutoff splits income before next start date',
        () {
          final monthly = computeLegacyMonthlyIncome(
            records: [
              legacyHoursRecord(
                id: 1,
                deviceId: 1,
                startDate: 20260625,
                hours: 10,
              ),
              legacyHoursRecord(
                id: 2,
                deviceId: 1,
                startDate: 20260705,
                startMeter: 10,
                hours: 1,
              ),
            ],
            devices: [legacyDevice(id: 1)],
            targetMonth: 7,
            asOfDate: DateTime(2026, 7, 5),
          );

          // A: Jun 25-Jul 4 = 10 days at 100/day.
          // B: Jul 5 = 1 day at 100/day. Jul 5 is not allocated to A.
          expect(monthly[5], closeTo(600.0, 0.001));
          expect(monthly[6], closeTo(500.0, 0.001));
          expect(monthly.take(5).every((v) => v == 0.0), isTrue);
          expect(monthly.skip(7).every((v) => v == 0.0), isTrue);
        },
      );

      test('records from different devices do not act as implicit cutoff', () {
        final monthly = computeLegacyMonthlyIncome(
          records: [
            legacyHoursRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260601,
              hours: 40,
            ),
            legacyHoursRecord(
              id: 2,
              deviceId: 2,
              startDate: 20260610,
              hours: 1,
            ),
          ],
          devices: [legacyDevice(id: 1), legacyDevice(id: 2, rate: 0)],
          targetMonth: 7,
          asOfDate: DateTime(2026, 7, 10),
        );

        // Device 2 has zero realtime income, but its Jun 10 date must not cap
        // device 1. Device 1 remains an open segment, which now defaults to
        // the first day of the next month and keeps the full income in June.
        expect(monthly[5], closeTo(4000.0, 0.001));
        expect(monthly[6], closeTo(0.0, 0.001));
        expect(monthly.take(5).every((v) => v == 0.0), isTrue);
        expect(monthly.skip(7).every((v) => v == 0.0), isTrue);
      });
    });

    group('hours allocation exclusive cutoff priority', () {
      test(
        'priority 2 uses next same-device start when explicit cutoff is null',
        () {
          final monthly = computeLegacyMonthlyIncome(
            records: [
              legacyHoursRecord(
                id: 1,
                deviceId: 1,
                startDate: 20260601,
                hours: 9,
              ),
              legacyHoursRecord(
                id: 2,
                deviceId: 1,
                startDate: 20260610,
                startMeter: 9,
                hours: 31,
              ),
            ],
            devices: [legacyDevice(id: 1)],
            targetMonth: 7,
            asOfDate: DateTime(2026, 7, 10),
          );

          // A: [Jun 1, Jun 10) by next-start cutoff.
          // B has no next record, so it defaults to [Jun 10, Jul 1).
          expect(monthly[5], closeTo(4000.0, 0.001));
          expect(monthly[6], closeTo(0.0, 0.001));
          expect(monthly.take(5).every((v) => v == 0.0), isTrue);
          expect(monthly.skip(7).every((v) => v == 0.0), isTrue);
        },
      );

      test(
        'priority 3 defaults no-next null cutoff to first day of next month',
        () {
          final monthly = computeLegacyMonthlyIncome(
            records: [
              legacyHoursRecord(
                id: 1,
                deviceId: 1,
                startDate: 20260610,
                hours: 21,
              ),
            ],
            devices: [legacyDevice(id: 1)],
            targetMonth: 7,
            asOfDate: DateTime(2026, 7, 10),
          );

          // No explicit exclusive cutoff and no next same-device record:
          // the chart-only allocation stops at [Jun 10, Jul 1).
          expect(monthly[5], closeTo(2100.0, 0.001));
          expect(monthly[6], closeTo(0.0, 0.001));
          expect(monthly.take(5).every((v) => v == 0.0), isTrue);
          expect(monthly.skip(7).every((v) => v == 0.0), isTrue);
        },
      );

      test('cutoff equal to next start preserves first segment boundary', () {
        final monthly = computeLegacyMonthlyIncome(
          records: [
            legacyHoursRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260601,
              allocationCutoffExclusiveYmd: 20260610,
              hours: 9,
            ),
            legacyHoursRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260610,
              startMeter: 9,
              hours: 31,
            ),
          ],
          devices: [legacyDevice(id: 1)],
          targetMonth: 7,
          asOfDate: DateTime(2026, 7, 10),
        );

        // The persisted cutoff is exclusive: Jun 10 is not allocated to A.
        // B remains an open segment and defaults to [Jun 10, Jul 1).
        expect(monthly[5], closeTo(4000.0, 0.001));
        expect(monthly[6], closeTo(0.0, 0.001));
        expect(monthly.take(5).every((v) => v == 0.0), isTrue);
        expect(monthly.skip(7).every((v) => v == 0.0), isTrue);
      });

      test('priority 1 explicit exclusive cutoff wins before next start', () {
        final monthly = computeLegacyMonthlyIncome(
          records: [
            legacyHoursRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260601,
              allocationCutoffExclusiveYmd: 20260605,
              hours: 4,
            ),
            legacyHoursRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260610,
              startMeter: 4,
              hours: 1,
            ),
          ],
          devices: [legacyDevice(id: 1)],
          targetMonth: 6,
          asOfDate: DateTime(2026, 6, 10),
        );

        // The explicit UI end would be Jun 4, persisted as exclusive Jun 5.
        // It has priority over the later next same-device start on Jun 10.
        // A: [Jun 1, Jun 5) = 4 days at 100/day = 400.
        // Jun 5-Jun 9 is a gap. B starts on Jun 10 = 100.
        expect(monthly[5], closeTo(500.0, 0.001));
        expect(monthly.take(5).every((v) => v == 0.0), isTrue);
        expect(monthly.skip(6).every((v) => v == 0.0), isTrue);
      });

      test(
        'explicit no-next exclusive cutoff stops before statistics cutoff',
        () {
          final monthly = computeLegacyMonthlyIncome(
            records: [
              legacyHoursRecord(
                id: 1,
                deviceId: 1,
                startDate: 20260601,
                allocationCutoffExclusiveYmd: 20260620,
                hours: 19,
              ),
            ],
            devices: [legacyDevice(id: 1)],
            targetMonth: 7,
            asOfDate: DateTime(2026, 7, 10),
          );

          // A: [Jun 1, Jun 20) = 19 days at 100/day.
          expect(monthly[5], closeTo(1900.0, 0.001));
          expect(monthly[6], closeTo(0.0, 0.001));
          expect(monthly.take(5).every((v) => v == 0.0), isTrue);
          expect(monthly.skip(7).every((v) => v == 0.0), isTrue);
        },
      );

      test('explicit exclusive cutoff after statistics cutoff is capped', () {
        final monthly = computeLegacyMonthlyIncome(
          records: [
            legacyHoursRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260601,
              allocationCutoffExclusiveYmd: 20260720,
              hours: 10,
            ),
          ],
          devices: [legacyDevice(id: 1)],
          targetMonth: 6,
          asOfDate: DateTime(2026, 6, 10),
        );

        // Statistics cutoff is Jun 10, so the exclusive boundary is Jun 11.
        // The later explicit cutoff must not allocate after Jun 10.
        expect(monthly[5], closeTo(1000.0, 0.001));
        expect(monthly.take(5).every((v) => v == 0.0), isTrue);
        expect(monthly.skip(6).every((v) => v == 0.0), isTrue);
      });

      test(
        'cross-month explicit exclusive cutoff splits income before cutoff',
        () {
          final monthly = computeLegacyMonthlyIncome(
            records: [
              legacyHoursRecord(
                id: 1,
                deviceId: 1,
                startDate: 20260625,
                allocationCutoffExclusiveYmd: 20260705,
                hours: 10,
              ),
            ],
            devices: [legacyDevice(id: 1)],
            targetMonth: 7,
            asOfDate: DateTime(2026, 7, 5),
          );

          // A: [Jun 25, Jul 5) = 10 days at 100/day.
          // Jun has 6 days, Jul has 4 days; Jul 5 is excluded.
          expect(monthly[5], closeTo(600.0, 0.001));
          expect(monthly[6], closeTo(400.0, 0.001));
          expect(monthly.take(5).every((v) => v == 0.0), isTrue);
          expect(monthly.skip(7).every((v) => v == 0.0), isTrue);
        },
      );

      test('rent allocation cutoff is ignored by hours priority rule', () {
        final monthly = computeLegacyMonthlyIncome(
          records: const [
            TimingRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260601,
              allocationCutoffDate: 20260701,
              contact: '甲方',
              site: '台班',
              type: TimingType.rent,
              startMeter: 0,
              endMeter: 0,
              hours: 0,
              income: 1000,
            ),
          ],
          devices: [legacyDevice(id: 1)],
          targetMonth: 7,
          asOfDate: DateTime(2026, 7, 31),
        );

        // Rent remains a one-time record-month income. The cutoff does not
        // spread or move any amount into July.
        expect(monthly[5], closeTo(1000.0, 0.001));
        expect(monthly[6], closeTo(0.0, 0.001));
        expect(monthly.take(5).every((v) => v == 0.0), isTrue);
        expect(monthly.skip(7).every((v) => v == 0.0), isTrue);
      });

      test('rent display end date does not affect monthly income', () {
        final monthly = computeLegacyMonthlyIncome(
          records: const [
            TimingRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260601,
              displayEndDate: 20260731,
              contact: '甲方',
              site: '台班',
              type: TimingType.rent,
              startMeter: 0,
              endMeter: 0,
              hours: 0,
              income: 1000,
            ),
          ],
          devices: [legacyDevice(id: 1)],
          targetMonth: 7,
          asOfDate: DateTime(2026, 7, 31),
        );

        expect(monthly[5], closeTo(1000.0, 0.001));
        expect(monthly[6], closeTo(0.0, 0.001));
        expect(monthly.take(5).every((v) => v == 0.0), isTrue);
        expect(monthly.skip(7).every((v) => v == 0.0), isTrue);
      });

      test('invalid cutoff on start date falls back to legacy allocation', () {
        final monthly = computeLegacyMonthlyIncome(
          records: [
            legacyHoursRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260601,
              allocationCutoffExclusiveYmd: 20260601,
              hours: 9,
            ),
            legacyHoursRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260610,
              startMeter: 9,
              hours: 31,
            ),
          ],
          devices: [legacyDevice(id: 1)],
          targetMonth: 7,
          asOfDate: DateTime(2026, 7, 10),
        );

        // Persisted invalid cutoff <= startDate is ignored for chart safety.
        // The final open segment still defaults to the start month only.
        expect(monthly[5], closeTo(4000.0, 0.001));
        expect(monthly[6], closeTo(0.0, 0.001));
      });

      test('explicit end date equal to next start includes handoff day', () {
        final monthly = computeLegacyMonthlyIncome(
          records: [
            legacyHoursRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260625,
              allocationCutoffExclusiveYmd: 20260702,
              hours: 10,
            ),
            legacyHoursRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260701,
              startMeter: 10,
              hours: 0,
            ),
          ],
          devices: [legacyDevice(id: 1)],
          targetMonth: 7,
          asOfDate: DateTime(2026, 7, 10),
        );

        // UI end date Jul 1 persists as exclusive Jul 2. The first record
        // spans Jun 25-Jul 1, so total income is unchanged while one day moves
        // into July for same-day handoff display semantics.
        expect(monthly[5], closeTo(857.1429, 0.001));
        expect(monthly[6], closeTo(142.8571, 0.001));
        expect(monthly[5] + monthly[6], closeTo(1000.0, 0.001));
      });

      test(
        'same-day next with explicit same-day end keeps one-day allocation',
        () {
          final monthly = computeLegacyMonthlyIncome(
            records: [
              legacyHoursRecord(
                id: 1,
                deviceId: 1,
                startDate: 20260601,
                allocationCutoffExclusiveYmd: 20260602,
                hours: 2,
              ),
              legacyHoursRecord(
                id: 2,
                deviceId: 1,
                startDate: 20260601,
                startMeter: 2,
                hours: 3,
              ),
            ],
            devices: [legacyDevice(id: 1)],
            targetMonth: 6,
            asOfDate: DateTime(2026, 6, 1),
          );

          // Same-day next records preserve the legacy one-day behavior even if a
          // persisted non-null cutoff somehow bypassed the save-layer validator.
          expect(monthly[5], closeTo(500.0, 0.001));
          expect(monthly.take(5).every((v) => v == 0.0), isTrue);
          expect(monthly.skip(6).every((v) => v == 0.0), isTrue);
        },
      );

      test('same-day next with too-late explicit cutoff keeps legacy day', () {
        final monthly = computeLegacyMonthlyIncome(
          records: [
            legacyHoursRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260601,
              allocationCutoffExclusiveYmd: 20260603,
              hours: 2,
            ),
            legacyHoursRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260601,
              startMeter: 2,
              hours: 3,
            ),
          ],
          devices: [legacyDevice(id: 1)],
          targetMonth: 6,
          asOfDate: DateTime(2026, 6, 1),
        );

        expect(monthly[5], closeTo(500.0, 0.001));
        expect(monthly.take(5).every((v) => v == 0.0), isTrue);
        expect(monthly.skip(6).every((v) => v == 0.0), isTrue);
      });

      test('write-off allocation follows cutoff monthly income distribution', () {
        const projectId = 'project:cutoff-write-off';
        final monthly = computeLegacyMonthlyIncome(
          records: [
            legacyHoursRecord(
              id: 1,
              projectId: projectId,
              deviceId: 1,
              startDate: 20260625,
              allocationCutoffExclusiveYmd: 20260705,
              hours: 10,
            ),
          ],
          devices: [legacyDevice(id: 1)],
          targetMonth: 7,
          asOfDate: DateTime(2026, 7, 5),
          projectWriteOffs: [writeOff(projectId, 100)],
        );

        // Before write-off: Jun 600, Jul 400. The 100 write-off follows the
        // cutoff-created 60/40 monthly distribution, so total deduction is 100.
        expect(monthly[5], closeTo(540.0, 0.001));
        expect(monthly[6], closeTo(360.0, 0.001));
        expect(monthly[5] + monthly[6], closeTo(900.0, 0.001));
        expect(monthly.every((value) => value >= 0), isTrue);
      });
    });

    test('keeps open no-next segments in the start month by default', () {
      final monthlyAtFeb =
          TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
            records: [
              const TimingRecord(
                id: 1,
                deviceId: 1,
                startDate: 20260101,
                contact: '小朱',
                site: '永寿',
                type: TimingType.hours,
                startMeter: 0,
                endMeter: 6,
                hours: 6,
                income: 0, // 图表逻辑不再依赖该字段
              ),
              const TimingRecord(
                id: 2,
                deviceId: 1,
                startDate: 20260205,
                contact: '小朱',
                site: '永寿',
                type: TimingType.hours,
                startMeter: 6,
                endMeter: 9,
                hours: 3,
                income: 0,
                isBreaking: true,
              ),
            ],
            devices: const [
              Device(
                id: 1,
                name: 'SANY 1#',
                brand: 'SANY',
                defaultUnitPrice: 200,
                breakingUnitPrice: 250,
                baseMeterHours: 0,
              ),
            ],
            rates: const [],
            targetYear: 2026,
            targetMonth: 2,
            asOfDate: DateTime(2026, 2, 28),
          );

      expect(monthlyAtFeb[0], closeTo(1062.8571, 0.001));
      expect(monthlyAtFeb[1], closeTo(887.1429, 0.001));
      expect(monthlyAtFeb.sublist(2).every((v) => v == 0.0), isTrue);

      final monthlyAtMar =
          TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
            records: [
              const TimingRecord(
                id: 1,
                deviceId: 1,
                startDate: 20260101,
                contact: '小朱',
                site: '永寿',
                type: TimingType.hours,
                startMeter: 0,
                endMeter: 6,
                hours: 6,
                income: 0,
              ),
              const TimingRecord(
                id: 2,
                deviceId: 1,
                startDate: 20260205,
                contact: '小朱',
                site: '永寿',
                type: TimingType.hours,
                startMeter: 6,
                endMeter: 9,
                hours: 3,
                income: 0,
                isBreaking: true,
              ),
            ],
            devices: const [
              Device(
                id: 1,
                name: 'SANY 1#',
                brand: 'SANY',
                defaultUnitPrice: 200,
                breakingUnitPrice: 250,
                baseMeterHours: 0,
              ),
            ],
            rates: const [],
            targetYear: 2026,
            targetMonth: 3,
            asOfDate: DateTime(2026, 3, 31),
          );

      expect(monthlyAtMar[0], closeTo(1062.8571, 0.001));
      expect(monthlyAtMar[1], closeTo(887.1429, 0.001));
      expect(monthlyAtMar[2], closeTo(0.0, 0.001));
    });

    test('keeps same-device same-day records before segmenting', () {
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: [
          const TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260110,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 10,
            hours: 10,
            income: 9999,
          ),
          const TimingRecord(
            id: 2,
            deviceId: 1,
            startDate: 20260110,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 5,
            endMeter: 6,
            hours: 1,
            income: 9999,
          ),
          const TimingRecord(
            id: 4,
            deviceId: 1,
            startDate: 20260110,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 5,
            endMeter: 7,
            hours: 2,
            income: 9999,
          ),
          const TimingRecord(
            id: 3,
            deviceId: 1,
            startDate: 20260112,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 7,
            endMeter: 9,
            hours: 2,
            income: 9999,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'SANY 1#',
            brand: 'SANY',
            defaultUnitPrice: 200,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 1,
        asOfDate: DateTime(2026, 1, 31),
      );

      expect(monthly[0], closeTo(3000.0, 0.001));
      expect(monthly.sublist(1).every((v) => v == 0.0), isTrue);
    });

    test('adds rent income to the record month', () {
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260515,
            contact: '周亮',
            site: '成都',
            type: TimingType.rent,
            startMeter: 6180.7,
            endMeter: 6180.7,
            hours: 0,
            income: 22000,
          ),
        ],
        devices: const [
          Device(
            id: 1,
            name: 'HITACHI 1#',
            brand: 'HITACHI',
            defaultUnitPrice: 180,
            baseMeterHours: 0,
          ),
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 5,
        asOfDate: DateTime(2026, 5, 16),
      );

      expect(monthly[4], closeTo(22000.0, 0.001));
      expect(monthly.take(4).every((v) => v == 0.0), isTrue);
      expect(monthly.skip(5).every((v) => v == 0.0), isTrue);
    });

    test(
      'uses project overrides and breaking fallback/default consistently',
      () {
        final projectKey = ProjectKey.buildKey(contact: '李洋', site: '万达');
        final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
          records: const [
            TimingRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260101,
              contact: '李洋',
              site: '万达',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 2,
              hours: 2,
              income: 0,
            ),
            TimingRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260115,
              contact: '李洋',
              site: '万达',
              type: TimingType.hours,
              startMeter: 2,
              endMeter: 3,
              hours: 1,
              income: 0,
              isBreaking: true,
            ),
            TimingRecord(
              id: 3,
              deviceId: 2,
              startDate: 20260110,
              contact: '李洋',
              site: '万达',
              type: TimingType.hours,
              startMeter: 10,
              endMeter: 13,
              hours: 3,
              income: 0,
            ),
          ],
          devices: const [
            Device(
              id: 1,
              name: 'SANY 1#',
              brand: 'SANY',
              defaultUnitPrice: 200,
              breakingUnitPrice: 250,
              baseMeterHours: 0,
            ),
            Device(
              id: 2,
              name: 'LIUGONG 1#',
              brand: 'LIUGONG',
              defaultUnitPrice: 150,
              breakingUnitPrice: 170,
              baseMeterHours: 0,
            ),
          ],
          rates: [
            ProjectDeviceRate(projectKey: projectKey, deviceId: 1, rate: 180),
            ProjectDeviceRate(
              projectKey: projectKey,
              deviceId: 1,
              isBreaking: true,
              rate: 230,
            ),
          ],
          targetYear: 2026,
          targetMonth: 1,
          asOfDate: DateTime(2026, 1, 31),
        );

        // dev1 normal: 2h * 180 = 360
        // dev1 breaking: 1h * 230 = 230
        // dev2 normal(default): 3h * 150 = 450
        expect(monthly[0], closeTo(1040.0, 0.001));
      },
    );

    test(
      'skips non-positive realtime income and records beyond target month end',
      () {
        final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
          records: const [
            TimingRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260101,
              contact: 'A',
              site: 'X',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 1,
              hours: 1,
              income: 9999,
            ),
            TimingRecord(
              id: 2,
              deviceId: 3, // 设备单价为 0 -> realtimeIncome = 0
              startDate: 20260105,
              contact: 'A',
              site: 'X',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 10,
              hours: 10,
              income: 9999,
            ),
            TimingRecord(
              id: 3,
              deviceId: 1,
              startDate: 20270101, // 超出目标年/目标月末，应跳过
              contact: 'A',
              site: 'X',
              type: TimingType.hours,
              startMeter: 1,
              endMeter: 2,
              hours: 1,
              income: 9999,
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
              id: 3,
              name: 'ZERO 1#',
              brand: 'ZERO',
              defaultUnitPrice: 0,
              baseMeterHours: 0,
            ),
          ],
          rates: const [],
          targetYear: 2026,
          targetMonth: 1,
          asOfDate: DateTime(2026, 1, 31),
        );

        expect(monthly[0], closeTo(100.0, 0.001));
        expect(monthly.sublist(1).every((v) => v == 0.0), isTrue);
      },
    );

    test('keeps unfinished open segment in the start month by default', () {
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            deviceId: 1,
            startDate: 20260315,
            contact: 'A',
            site: 'Y',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 117,
            hours: 17,
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
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 5,
        asOfDate: DateTime(2026, 5, 20),
      );

      expect(monthly[2], closeTo(1700.0, 0.001)); // 3月
      expect(monthly[3], closeTo(0.0, 0.001)); // 4月
      expect(monthly[4], closeTo(0.0, 0.001)); // 5月
      expect(monthly.reduce((a, b) => a + b), closeTo(1700.0, 0.001));
    });

    test(
      'keeps april income when april records exist under realtime rules',
      () {
        final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
          records: const [
            TimingRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260101,
              contact: '小朱',
              site: '永寿',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 6,
              hours: 6,
              income: 0,
            ),
            TimingRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260205,
              contact: '小朱',
              site: '永寿',
              type: TimingType.hours,
              startMeter: 6,
              endMeter: 9,
              hours: 3,
              income: 0,
              isBreaking: true,
            ),
            TimingRecord(
              id: 3,
              deviceId: 1,
              startDate: 20260301,
              contact: '小朱',
              site: '永寿',
              type: TimingType.hours,
              startMeter: 9,
              endMeter: 27,
              hours: 18,
              income: 0,
            ),
            TimingRecord(
              id: 4,
              deviceId: 1,
              startDate: 20260430,
              contact: '小朱',
              site: '永寿',
              type: TimingType.hours,
              startMeter: 27,
              endMeter: 84,
              hours: 57,
              income: 0,
            ),
          ],
          devices: const [
            Device(
              id: 1,
              name: 'SANY 1#',
              brand: 'SANY',
              defaultUnitPrice: 200,
              breakingUnitPrice: 250,
              baseMeterHours: 0,
            ),
          ],
          rates: const [],
          targetYear: 2026,
          targetMonth: 4,
          asOfDate: DateTime(2026, 4, 30),
        );

        expect(monthly[0], closeTo(1062.8571, 0.001)); // 1月
        expect(monthly[1], closeTo(887.1429, 0.001)); // 2月
        expect(monthly[2], closeTo(1860.0, 0.001)); // 3月
        expect(monthly[3], closeTo(13140.0, 0.001)); // 4月
        expect(monthly[3], greaterThan(0.0));
      },
    );

    test('keeps same-day records instead of dropping all but the last one', () {
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 10,
            deviceId: 1,
            startDate: 20260110,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 5,
            endMeter: 15,
            hours: 10,
            income: 0,
          ),
          TimingRecord(
            id: 11,
            deviceId: 1,
            startDate: 20260110,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 5,
            endMeter: 6,
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
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 1,
        asOfDate: DateTime(2026, 1, 31),
      );

      expect(monthly[0], closeTo(1100.0, 0.001));
      expect(monthly.sublist(1).every((v) => v == 0.0), isTrue);
    });

    test('counts same-device same-day records from different projects', () {
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 20,
            deviceId: 1,
            startDate: 20260501,
            projectId: 'project-a',
            contact: '刘锐',
            site: '五里山',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 105,
            hours: 5,
            income: 0,
          ),
          TimingRecord(
            id: 21,
            deviceId: 1,
            startDate: 20260501,
            projectId: 'project-b',
            contact: '刘锐',
            site: '鲜滩',
            type: TimingType.hours,
            startMeter: 105,
            endMeter: 112,
            hours: 7,
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
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 5,
        asOfDate: DateTime(2026, 5, 31),
      );

      expect(monthly[4], closeTo(1200.0, 0.001));
      expect(
        monthly.asMap().entries.every((entry) {
          return entry.key == 4 || entry.value == 0.0;
        }),
        isTrue,
      );
    });

    test(
      'handles multi-device mixed override/default rates with cross-month segments',
      () {
        final projectKey = ProjectKey.buildKey(contact: '李洋', site: '万达');
        final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
          records: const [
            TimingRecord(
              id: 1,
              deviceId: 1,
              startDate: 20260110,
              contact: '李洋',
              site: '万达',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 10,
              hours: 10,
              income: 0,
            ),
            TimingRecord(
              id: 2,
              deviceId: 1,
              startDate: 20260210,
              contact: '李洋',
              site: '万达',
              type: TimingType.hours,
              startMeter: 10,
              endMeter: 14,
              hours: 4,
              income: 0,
            ),
            TimingRecord(
              id: 3,
              deviceId: 2,
              startDate: 20260120,
              contact: '李洋',
              site: '万达',
              type: TimingType.hours,
              startMeter: 100,
              endMeter: 105,
              hours: 5,
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
              name: 'LIUGONG 1#',
              brand: 'LIUGONG',
              defaultUnitPrice: 200,
              baseMeterHours: 0,
            ),
          ],
          rates: [
            ProjectDeviceRate(
              projectKey: projectKey,
              deviceId: 1,
              rate: 150, // dev1 使用项目覆写
            ),
            // dev2 不覆写，使用设备默认价 200
          ],
          targetYear: 2026,
          targetMonth: 2,
          asOfDate: DateTime(2026, 2, 28),
        );

        // dev1@150:
        // r1 1500 in [01-10..02-09] => Jan 22d + Feb 9d
        // r2  600 in [02-10..02-28] => Feb 19d
        // dev2@200:
        // r3 1000 has no next same-device record, so it stays in January.
        expect(monthly[0], closeTo(2064.5161, 0.001)); // 1月
        expect(monthly[1], closeTo(1035.4839, 0.001)); // 2月
        expect(monthly.sublist(2).every((v) => v == 0.0), isTrue);
      },
    );

    test('keeps monthly income unchanged when there is no write-off', () {
      const projectId = 'project:no-write-off';
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            projectId: projectId,
            deviceId: 1,
            startDate: 20260501,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 12.6,
            hours: 12.6,
            income: 9999,
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
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 5,
        asOfDate: DateTime(2026, 5, 31),
      );

      expect(monthly[4], closeTo(1260.0, 0.001));
      expect(monthly.where((value) => value > 0), hasLength(1));
    });

    test('deducts a single-month project write-off from that month', () {
      const projectId = 'project:single-month-write-off';
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            projectId: projectId,
            deviceId: 1,
            startDate: 20260501,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 12.6,
            hours: 12.6,
            income: 9999,
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
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 5,
        asOfDate: DateTime(2026, 5, 31),
        projectWriteOffs: [writeOff(projectId, 60)],
      );

      expect(monthly[4], closeTo(1200.0, 0.001));
      expect(monthly.where((value) => value > 0), hasLength(1));
    });

    test(
      'allocates cross-month project write-off by original income ratio',
      () {
        const projectId = 'project:cross-month-write-off';
        final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
          records: const [
            TimingRecord(
              id: 1,
              projectId: projectId,
              deviceId: 1,
              startDate: 20260501,
              contact: 'A',
              site: 'X',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 10,
              hours: 10,
              income: 0,
            ),
            TimingRecord(
              id: 2,
              projectId: projectId,
              deviceId: 1,
              startDate: 20260601,
              contact: 'A',
              site: 'X',
              type: TimingType.hours,
              startMeter: 10,
              endMeter: 12.6,
              hours: 2.6,
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
          ],
          rates: const [],
          targetYear: 2026,
          targetMonth: 6,
          asOfDate: DateTime(2026, 6, 30),
          projectWriteOffs: [writeOff(projectId, 60)],
        );

        final mayWriteOff = 60 * 1000 / 1260;
        final juneWriteOff = 60 * 260 / 1260;
        expect(monthly[4], closeTo(1000 - mayWriteOff, 0.001));
        expect(monthly[5], closeTo(260 - juneWriteOff, 0.001));
        expect(monthly[4] + monthly[5], closeTo(1200.0, 0.001));
      },
    );

    test('reduces annual income by a large project write-off', () {
      const projectId = 'project:large-write-off';
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            projectId: projectId,
            deviceId: 1,
            startDate: 20260501,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 200,
            hours: 200,
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
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 5,
        asOfDate: DateTime(2026, 5, 31),
        projectWriteOffs: [writeOff(projectId, 10000)],
      );

      expect(monthly[4], closeTo(10000.0, 0.001));
      expect(monthly.fold<double>(0.0, (sum, value) => sum + value), 10000);
    });

    test(
      'keeps fully cash-settled projects unchanged when write-off is zero',
      () {
        const projectId = 'project:cash-settled';
        final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
          records: const [
            TimingRecord(
              id: 1,
              projectId: projectId,
              deviceId: 1,
              startDate: 20260501,
              contact: 'A',
              site: 'X',
              type: TimingType.hours,
              startMeter: 0,
              endMeter: 12.6,
              hours: 12.6,
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
          ],
          rates: const [],
          targetYear: 2026,
          targetMonth: 5,
          asOfDate: DateTime(2026, 5, 31),
          projectWriteOffs: const [],
        );

        expect(monthly[4], closeTo(1260.0, 0.001));
      },
    );

    test('includes rent income in project write-off allocation', () {
      const projectId = 'project:rent-write-off';
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            projectId: projectId,
            deviceId: 1,
            startDate: 20260515,
            contact: 'A',
            site: 'X',
            type: TimingType.rent,
            startMeter: 0,
            endMeter: 0,
            hours: 0,
            income: 1260,
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
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 5,
        asOfDate: DateTime(2026, 5, 31),
        projectWriteOffs: [writeOff(projectId, 60)],
      );

      expect(monthly[4], closeTo(1200.0, 0.001));
    });

    test('clamps monthly income at zero when write-off exceeds income', () {
      const projectId = 'project:over-write-off';
      final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
        records: const [
          TimingRecord(
            id: 1,
            projectId: projectId,
            deviceId: 1,
            startDate: 20260501,
            contact: 'A',
            site: 'X',
            type: TimingType.hours,
            startMeter: 0,
            endMeter: 10,
            hours: 10,
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
        ],
        rates: const [],
        targetYear: 2026,
        targetMonth: 5,
        asOfDate: DateTime(2026, 5, 31),
        projectWriteOffs: [writeOff(projectId, 1500)],
      );

      expect(monthly[4], 0.0);
      expect(monthly.every((value) => value >= 0), isTrue);
    });

    test(
      'does not mutate timing records or rates while applying write-off',
      () {
        const projectId = 'project:immutable-input';
        const record = TimingRecord(
          id: 1,
          projectId: projectId,
          deviceId: 1,
          startDate: 20260501,
          contact: 'A',
          site: 'X',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 12.6,
          hours: 12.6,
          income: 9999,
        );
        const rate = ProjectDeviceRate(
          projectId: projectId,
          projectKey: 'A||X',
          deviceId: 1,
          rate: 100,
        );

        final monthly = TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
          records: const [record],
          devices: const [
            Device(
              id: 1,
              name: 'SANY 1#',
              brand: 'SANY',
              defaultUnitPrice: 200,
              baseMeterHours: 0,
            ),
          ],
          rates: const [rate],
          targetYear: 2026,
          targetMonth: 5,
          asOfDate: DateTime(2026, 5, 31),
          projectWriteOffs: [writeOff(projectId, 60)],
        );

        expect(monthly[4], closeTo(1200.0, 0.001));
        expect(record.hours, 12.6);
        expect(record.income, 9999);
        expect(rate.rate, 100);
      },
    );

    test('restores monthly income after project write-off is deleted', () {
      const projectId = 'project:delete-write-off-restore-income';
      const records = [
        TimingRecord(
          id: 1,
          projectId: projectId,
          deviceId: 1,
          startDate: 20260501,
          contact: 'A',
          site: 'X',
          type: TimingType.hours,
          startMeter: 0,
          endMeter: 12.6,
          hours: 12.6,
          income: 0,
        ),
      ];
      const devices = [
        Device(
          id: 1,
          name: 'SANY 1#',
          brand: 'SANY',
          defaultUnitPrice: 100,
          baseMeterHours: 0,
        ),
      ];

      final withWriteOff =
          TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
            records: records,
            devices: devices,
            rates: const [],
            targetYear: 2026,
            targetMonth: 5,
            asOfDate: DateTime(2026, 5, 31),
            projectWriteOffs: [writeOff(projectId, 60)],
          );
      final afterDelete =
          TimingMonthlyIncomeService.computeMonthlyIncomeRealtime(
            records: records,
            devices: devices,
            rates: const [],
            targetYear: 2026,
            targetMonth: 5,
            asOfDate: DateTime(2026, 5, 31),
            projectWriteOffs: const [],
          );

      expect(withWriteOff[4], closeTo(1200.0, 0.001));
      expect(afterDelete[4], closeTo(1260.0, 0.001));
      expect(records.single.income, 0);
      expect(devices.single.defaultUnitPrice, 100);
    });
  });
}
