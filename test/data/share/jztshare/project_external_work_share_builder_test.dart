import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_share_builder.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_share_payload.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_share_rich_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = ProjectExternalWorkShareBuilder();

  final deviceA = Device(
    id: 1,
    name: 'HITACHI 1#',
    brand: 'HITACHI',
    model: 'ZX200',
    defaultUnitPrice: 100.0,
    baseMeterHours: 0.0,
    equipmentType: EquipmentType.excavator,
  );
  final deviceB = Device(
    id: 2,
    name: 'SANY 2#',
    brand: 'SANY',
    defaultUnitPrice: 0.0,
    baseMeterHours: 0.0,
    equipmentType: EquipmentType.loader,
  );

  // r1/r2: hours 且 income == hours×设备单价 → 进 export_lines。
  const r1 = TimingRecord(
    id: 11,
    deviceId: 1,
    startDate: 20240101,
    contact: '张三',
    site: '工地A',
    type: TimingType.hours,
    startMeter: 100.0,
    endMeter: 108.0,
    hours: 8.0,
    income: 800.0,
  );
  const r2 = TimingRecord(
    id: 12,
    deviceId: 1,
    startDate: 20240102,
    contact: '张三',
    site: '工地A',
    type: TimingType.hours,
    startMeter: 108.0,
    endMeter: 113.0,
    hours: 5.0,
    income: 500.0,
  );
  // r3: rent/台班 → 只进 records，不进 export_lines；码表留空。
  const r3 = TimingRecord(
    id: 13,
    deviceId: 2,
    startDate: 20240103,
    contact: '张三',
    site: '工地A',
    type: TimingType.rent,
    startMeter: 0.0,
    endMeter: 0.0,
    hours: 1.0,
    income: 1200.0,
  );
  // r4: hours 但人工覆写金额，无法无损反推单价 → 只进 records。
  const r4 = TimingRecord(
    id: 14,
    deviceId: 1,
    startDate: 20240104,
    contact: '张三',
    site: '工地A',
    type: TimingType.hours,
    startMeter: 113.0,
    endMeter: 116.0,
    hours: 3.0,
    income: 333.34,
  );

  final calcHistoryMap = <int, List<TimingCalculationHistory>>{
    11: [
      TimingCalculationHistory(
        id: 'c-old',
        timingRecordId: 11,
        createdAt: DateTime.utc(2024, 1, 1, 9),
        expression: '3+4',
        result: 7.0,
        ticketCount: 1,
      ),
      TimingCalculationHistory(
        id: 'c-new',
        timingRecordId: 11,
        createdAt: DateTime.utc(2024, 1, 1, 10),
        expression: '3+5',
        result: 8.0,
        ticketCount: 2,
      ),
    ],
    // 与本次导出无关的记录，不应出现在任何 record 上。
    99: [
      TimingCalculationHistory(
        id: 'c-unrelated',
        timingRecordId: 99,
        createdAt: DateTime.utc(2024, 1, 1, 11),
        expression: '1+1',
        result: 2.0,
        ticketCount: 9,
      ),
    ],
  };

  ProjectExternalWorkShareRichPayload buildAll() => builder.build(
    shareId: 'share-1',
    senderName: '李工',
    sourceInstallationUuid: 'install-uuid',
    records: const [r4, r2, r3, r1], // 乱序输入验证稳定排序
    deviceMap: {1: deviceA, 2: deviceB},
    calcHistoryMap: calcHistoryMap,
  );

  test('summary aggregates device/record/income/hours correctly', () {
    final p = buildAll();
    expect(p.summary.deviceCount, 2);
    expect(p.summary.recordCount, 4);
    // 80000 + 50000 + 120000 + 33334
    expect(p.summary.totalIncomeFen, 283334);
    // 8000 + 5000 + 1000 + 3000
    expect(p.summary.totalHoursMilli, 17000);
  });

  test('devices aggregate recordCount/hours/income per device', () {
    final p = buildAll();
    expect(p.devices.map((d) => d.sourceDeviceId), [1, 2]);
    final d1 = p.devices.firstWhere((d) => d.sourceDeviceId == 1);
    expect(d1.recordCount, 3);
    expect(d1.totalHoursMilli, 16000);
    expect(d1.totalIncomeFen, 163334);
    expect(d1.name, 'HITACHI 1#');
    expect(d1.type, 'excavator');
    final d2 = p.devices.firstWhere((d) => d.sourceDeviceId == 2);
    expect(d2.recordCount, 1);
    expect(d2.totalHoursMilli, 1000);
    expect(d2.totalIncomeFen, 120000);
    expect(d2.type, 'loader');
  });

  test('records carry meters/hours/income/type/isBreaking, all included', () {
    final p = buildAll();
    expect(p.records.length, 4); // 富 records 必含全部
    final rec1 = p.records.firstWhere((r) => r.sourceTimingRecordId == 11);
    expect(rec1.sourceRecordUuid, 'timing:11');
    expect(rec1.type, 'hours');
    expect(rec1.startMeter, 100.0);
    expect(rec1.endMeter, 108.0);
    expect(rec1.hoursMilli, 8000);
    expect(rec1.incomeFen, 80000);
    expect(rec1.isBreaking, false);
    // 排序稳定：date 升序
    expect(p.records.map((r) => r.workDate), [
      20240101,
      20240102,
      20240103,
      20240104,
    ]);
  });

  test('filledCalculation = latest bound history; unrelated excluded', () {
    final p = buildAll();
    final rec1 = p.records.firstWhere((r) => r.sourceTimingRecordId == 11);
    expect(rec1.filledCalculation, isNotNull);
    expect(rec1.filledCalculation!.expression, '3+5');
    expect(rec1.filledCalculation!.result, 8.0);
    expect(rec1.filledCalculation!.ticketCount, 2);
    expect(rec1.filledCalculation!.resultMilliHours, 8000);
    expect(rec1.filledCalculation!.resultDisplay, '8.0 h');

    final rec2 = p.records.firstWhere((r) => r.sourceTimingRecordId == 12);
    expect(rec2.filledCalculation, isNull);
    // 无关历史(99)不出现
    final hasUnrelated = p.records.any(
      (r) => r.filledCalculation?.expression == '1+1',
    );
    expect(hasUnrelated, isFalse);
  });

  test('deviceGroups: hours span/error correct; rent leaves nulls', () {
    final p = buildAll();
    final g1 = p.deviceGroups.firstWhere((g) => g.sourceDeviceId == 1);
    expect(g1.recordIds, [11, 12, 14]);
    expect(g1.firstStartMeter, 100.0);
    expect(g1.lastEndMeter, 116.0);
    expect(g1.totalHoursMilli, 16000);
    expect(g1.meterSpanMilli, 16000);
    expect(g1.meterErrorMilli, 0);

    final g2 = p.deviceGroups.firstWhere((g) => g.sourceDeviceId == 2);
    expect(g2.firstStartMeter, isNull);
    expect(g2.lastEndMeter, isNull);
    expect(g2.meterSpanMilli, isNull); // rent 不乱填 0
    expect(g2.meterErrorMilli, isNull);
    expect(g2.totalHoursMilli, 1000);
  });

  test('rent record meters are null, not zero', () {
    final p = buildAll();
    final rec3 = p.records.firstWhere((r) => r.sourceTimingRecordId == 13);
    expect(rec3.type, 'rent');
    expect(rec3.startMeter, isNull);
    expect(rec3.endMeter, isNull);
    expect(rec3.incomeFen, 120000);
  });

  test('export_lines = importable subset; rent/override excluded', () {
    final p = buildAll();
    expect(p.exportLines.map((l) => l.exportLineUuid).toSet(), {
      'timing:11',
      'timing:12',
    });
    final l1 = p.exportLines.firstWhere((l) => l.exportLineUuid == 'timing:11');
    expect(l1.hoursMilli, 8000);
    expect(l1.sourceUnitPriceFen, 10000);
    expect(l1.amountFen, 80000); // == 真实 incomeFen，未伪造
    expect(l1.equipmentBrand, 'HITACHI');
    expect(l1.equipmentType, 'excavator');
  });

  test('project_snapshot keeps contact for tracing only', () {
    final p = buildAll();
    expect(p.projectSnapshot.contactSnapshot, '张三');
    expect(p.projectSnapshot.siteSnapshot, '工地A');
    expect(p.toMap()['project_snapshot'], isA<Map<String, Object?>>());
    final snap = p.toMap()['project_snapshot'] as Map<String, Object?>;
    expect(snap.containsKey('project_status_snapshot'), isFalse);
  });

  test('toMap stays parseable by legacy import payload parser', () {
    final map = buildAll().toMap();
    final legacy = ProjectExternalWorkSharePayload.fromMap(map);
    expect(legacy.shareId, 'share-1');
    expect(legacy.senderName, '李工');
    expect(legacy.sourceInstallationUuid, 'install-uuid');
    expect(legacy.exportLines.length, 2);
    expect(legacy.exportLines.first.amountFen, 80000);
  });

  test('originFingerprint is deterministic and 64-hex', () {
    final a = buildAll();
    final b = buildAll();
    final fa = a.records.firstWhere((r) => r.sourceTimingRecordId == 11);
    final fb = b.records.firstWhere((r) => r.sourceTimingRecordId == 11);
    expect(fa.originFingerprint, fb.originFingerprint);
    expect(fa.originFingerprint, matches(RegExp(r'^[0-9a-f]{64}$')));
    final fa2 = a.records.firstWhere((r) => r.sourceTimingRecordId == 12);
    expect(fa.originFingerprint, isNot(fa2.originFingerprint));
  });

  test('blank required inputs and empty records are rejected', () {
    expect(
      () => builder.build(
        shareId: '  ',
        senderName: '李工',
        sourceInstallationUuid: 'u',
        records: const [r1],
        deviceMap: {1: deviceA},
        calcHistoryMap: const {},
      ),
      throwsArgumentError,
    );
    expect(
      () => builder.build(
        shareId: 's',
        senderName: '李工',
        sourceInstallationUuid: 'u',
        records: const [],
        deviceMap: const {},
        calcHistoryMap: const {},
      ),
      throwsArgumentError,
    );
  });

  test(
    'records spanning multiple projects are rejected (no silent filter)',
    () {
      const other = TimingRecord(
        id: 21,
        deviceId: 1,
        startDate: 20240105,
        contact: '王五', // 不同项目
        site: '工地B',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 1,
        hours: 1,
        income: 100,
      );
      expect(
        () => builder.build(
          shareId: 's',
          senderName: '李工',
          sourceInstallationUuid: 'u',
          records: const [r1, other],
          deviceMap: {1: deviceA},
          calcHistoryMap: const {},
        ),
        throwsArgumentError,
      );
    },
  );

  test('expectedProjectId mismatch is rejected', () {
    expect(
      () => builder.build(
        shareId: 's',
        senderName: '李工',
        sourceInstallationUuid: 'u',
        records: const [r1],
        deviceMap: {1: deviceA},
        calcHistoryMap: const {},
        expectedProjectId: 'some-other-project',
      ),
      throwsArgumentError,
    );
  });

  test('rent originFingerprint ignores internal meter (exported null)', () {
    const rentZero = TimingRecord(
      id: 31,
      deviceId: 2,
      startDate: 20240106,
      contact: '赵六',
      site: '工地C',
      type: TimingType.rent,
      startMeter: 0.0,
      endMeter: 0.0,
      hours: 1.0,
      income: 600.0,
    );
    const rentNoisyMeter = TimingRecord(
      id: 31,
      deviceId: 2,
      startDate: 20240106,
      contact: '赵六',
      site: '工地C',
      type: TimingType.rent,
      startMeter: 88.0, // 内部噪声码表
      endMeter: 99.0,
      hours: 1.0,
      income: 600.0,
    );
    String fp(TimingRecord r) => builder
        .build(
          shareId: 's',
          senderName: '李工',
          sourceInstallationUuid: 'u',
          records: [r],
          deviceMap: const {},
          calcHistoryMap: const {},
        )
        .records
        .single
        .originFingerprint;
    expect(fp(rentZero), fp(rentNoisyMeter));
  });
}
