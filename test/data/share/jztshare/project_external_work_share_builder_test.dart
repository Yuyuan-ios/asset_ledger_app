import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/share/jztshare/jztshare_errors.dart';
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

  test('share payload uses timing incomeFen as source amount', () {
    const driftRent = TimingRecord(
      id: 91,
      deviceId: 2,
      startDate: 20240105,
      contact: '张三',
      site: '工地A',
      type: TimingType.rent,
      startMeter: 0,
      endMeter: 0,
      hours: 1,
      income: 9999,
      incomeFen: 12345,
    );

    final p = builder.build(
      shareId: 'income-fen-share',
      senderName: '李工',
      sourceInstallationUuid: 'install-uuid',
      records: const [driftRent],
      deviceMap: {2: deviceB},
      calcHistoryMap: const {},
    );

    expect(p.summary.totalIncomeFen, 12345);
    expect(p.records.single.incomeFen, 12345);
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
    expect(rec1.sourceRecordUuid, matches(RegExp(r'^rec-[0-9a-f]{24}$')));
    expect(rec1.sourceRecordUuid, isNot('timing:11'));
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
    expect(
      p.exportLines.map((l) => l.exportLineUuid),
      everyElement(matches(RegExp(r'^rec-[0-9a-f]{24}$'))),
    );
    expect(
      p.exportLines.map((l) => l.exportLineUuid),
      isNot(contains('timing:11')),
    );
    expect(p.exportLines.toSet(), hasLength(2));
    final l1 = p.exportLines.firstWhere((l) => l.amountFen == 80000);
    expect(l1.hoursMilli, 8000);
    expect(l1.sourceUnitPriceFen, 10000);
    expect(l1.amountFen, 80000); // == 真实 incomeFen，未伪造
    expect(l1.equipmentBrand, 'HITACHI');
    expect(l1.equipmentType, 'excavator');
  });

  group('rich record source_unit_price_fen (v1+)', () {
    test('hours record with device-confirmed unit price → trusted fen', () {
      final p = buildAll();
      final rec1 = p.records.firstWhere((r) => r.sourceTimingRecordId == 11);
      expect(rec1.type, 'hours');
      // HITACHI defaultUnitPrice = 100.0 yuan/h → 10000 fen/h; 8000 * 10000 / 1000 = 80000 == incomeFen.
      expect(rec1.sourceUnitPriceFen, 10000);
      expect(rec1.toMap()['source_unit_price_fen'], 10000);
    });

    test('rent record source_unit_price_fen is null (not 0, not derived)', () {
      final p = buildAll();
      final rec3 = p.records.firstWhere((r) => r.sourceTimingRecordId == 13);
      expect(rec3.type, 'rent');
      expect(rec3.sourceUnitPriceFen, isNull);
      // JSON 必须显式输出 null（与 startMeter/endMeter 同样口径），
      // 因为加法式 fromMap 用 containsKey 判定"未提供" vs "显式 null"。
      final json = rec3.toMap();
      expect(json.containsKey('source_unit_price_fen'), isTrue);
      expect(json['source_unit_price_fen'], isNull);
    });

    test('hours record with manual-override amount → null '
        '(导出端不允许 income÷hours 反推)', () {
      final p = buildAll();
      // r4: hours=3.0, income=333.34, defaultUnitPrice=100 → 30000≠33334。
      // 旧 export_lines 路径会反推 (33334/3=11111.33 → 11111)，但仍因
      // AmountPolicy 不一致被排除。富 records 必须直接为 null。
      final rec4 = p.records.firstWhere((r) => r.sourceTimingRecordId == 14);
      expect(rec4.sourceUnitPriceFen, isNull);
    });

    test('hours record with missing device → null', () {
      // 单条 hours 记录，但 deviceMap 不含该设备。
      const orphan = TimingRecord(
        id: 91,
        deviceId: 999, // 不存在
        startDate: 20240105,
        contact: '张三',
        site: '工地A',
        type: TimingType.hours,
        startMeter: 0.0,
        endMeter: 5.0,
        hours: 5.0,
        income: 500.0,
      );
      final p = builder.build(
        shareId: 's',
        senderName: 's',
        sourceInstallationUuid: 'u',
        records: const [orphan],
        deviceMap: const {},
        calcHistoryMap: const {},
      );
      final rec = p.records.single;
      expect(rec.type, 'hours');
      expect(rec.sourceUnitPriceFen, isNull);
    });

    test('rich-record fromMap rejects negative source_unit_price_fen '
        '(no silent coerce to 0)', () {
      final map = buildAll().records.first.toMap();
      map['source_unit_price_fen'] = -1;
      expect(
        () => ProjectExternalWorkShareRecord.fromMap(map),
        throwsA(isA<JztShareParseException>()),
      );
    });

    test(
      'rich-record fromMap treats missing key as null (additive compat)',
      () {
        final map = buildAll().records.first.toMap();
        map.remove('source_unit_price_fen');
        final round = ProjectExternalWorkShareRecord.fromMap(map);
        expect(round.sourceUnitPriceFen, isNull);
      },
    );

    test(
      'project rate override beats device default in source_unit_price_fen',
      () {
        // 关键场景：
        // - 设备默认单价 180（=18000 fen）
        // - 当前项目覆盖单价 200（=20000 fen）
        // - 这条 hours 记录金额按 200 生成（hours=7, income=1400）
        // → rich record 必须写 20000，而不是因为 deviceFen(18000) 与 income 不
        //   一致就回退到 null。
        final deviceX = Device(
          id: 7,
          name: '挖机 7#',
          brand: 'CAT',
          defaultUnitPrice: 180.0,
          baseMeterHours: 0.0,
          equipmentType: EquipmentType.excavator,
        );
        const overrideRecord = TimingRecord(
          id: 71,
          deviceId: 7,
          startDate: 20240301,
          contact: '王总',
          site: '工地B',
          type: TimingType.hours,
          startMeter: 0.0,
          endMeter: 7.0,
          hours: 7.0,
          income: 1400.0,
        );
        final rate = ProjectDeviceRate(
          projectId: overrideRecord.effectiveProjectId,
          projectKey: overrideRecord.legacyProjectKey,
          deviceId: 7,
          rate: 200.0,
        );

        final p = builder.build(
          shareId: 'override-share',
          senderName: '李工',
          sourceInstallationUuid: 'install',
          records: const [overrideRecord],
          deviceMap: {7: deviceX},
          calcHistoryMap: const {},
          projectDeviceRates: [rate],
        );
        final rec = p.records.single;
        expect(rec.type, 'hours');
        expect(rec.incomeFen, 140000);
        expect(rec.sourceUnitPriceFen, 20000);
      },
    );

    test(
      'no project rate override → uses device default and confirms via policy '
      '(180 yuan/h, 7h → 1260 → 18000 fen)',
      () {
        final deviceX = Device(
          id: 7,
          name: '挖机 7#',
          brand: 'CAT',
          defaultUnitPrice: 180.0,
          baseMeterHours: 0.0,
          equipmentType: EquipmentType.excavator,
        );
        const rec = TimingRecord(
          id: 72,
          deviceId: 7,
          startDate: 20240302,
          contact: '王总',
          site: '工地B',
          type: TimingType.hours,
          startMeter: 0.0,
          endMeter: 7.0,
          hours: 7.0,
          income: 1260.0,
        );
        final p = builder.build(
          shareId: 'no-override',
          senderName: '李工',
          sourceInstallationUuid: 'install',
          records: const [rec],
          deviceMap: {7: deviceX},
          calcHistoryMap: const {},
          projectDeviceRates: const [],
        );
        expect(p.records.single.sourceUnitPriceFen, 18000);
      },
    );

    test(
      'manual override amount on hours record → null (no income÷hours derive)',
      () {
        // 设备默认 180 yuan/h，但 income 被人工改成 1200（≠ 180×7=1260），
        // 也不等于任何覆盖价。绝不能反推 (1200/7=171.4) 后伪造写入。
        final deviceX = Device(
          id: 7,
          name: '挖机 7#',
          brand: 'CAT',
          defaultUnitPrice: 180.0,
          baseMeterHours: 0.0,
          equipmentType: EquipmentType.excavator,
        );
        const rec = TimingRecord(
          id: 73,
          deviceId: 7,
          startDate: 20240303,
          contact: '王总',
          site: '工地B',
          type: TimingType.hours,
          startMeter: 0.0,
          endMeter: 7.0,
          hours: 7.0,
          income: 1200.0, // manual override
        );
        final p = builder.build(
          shareId: 'manual-override',
          senderName: '李工',
          sourceInstallationUuid: 'install',
          records: const [rec],
          deviceMap: {7: deviceX},
          calcHistoryMap: const {},
          projectDeviceRates: const [],
        );
        expect(p.records.single.sourceUnitPriceFen, isNull);
      },
    );
  });

  test('project_snapshot keeps contact for tracing only', () {
    final p = buildAll();
    expect(p.projectSnapshot.contactSnapshot, '张三');
    expect(p.projectSnapshot.siteSnapshot, '工地A');
    expect(p.projectSnapshot.projectReceivedFen, 0);
    expect(p.toMap()['project_snapshot'], isA<Map<String, Object?>>());
    final snap = p.toMap()['project_snapshot'] as Map<String, Object?>;
    expect(snap['project_received_fen'], 0);
    expect(snap.containsKey('project_status_snapshot'), isFalse);
  });

  test('project_snapshot carries cumulative project received amount', () {
    final p = builder.build(
      shareId: 'share-with-paid',
      senderName: '李工',
      sourceInstallationUuid: 'install-uuid',
      records: const [r1],
      deviceMap: {1: deviceA},
      calcHistoryMap: const {},
      projectReceivedFen: 123456,
    );

    expect(p.projectSnapshot.projectReceivedFen, 123456);
    final snap = p.toMap()['project_snapshot'] as Map<String, Object?>;
    expect(snap['project_received_fen'], 123456);
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

  test('source fingerprint whitelist excludes private identifiers', () {
    expect(ProjectExternalWorkShareRichPayload.currentFingerprintVersion, 2);
    expect(
      ProjectExternalWorkShareBuilder.sourceFingerprintWhitelistV2,
      containsAll(<String>[
        'fingerprint_version',
        'package_source_device_id',
        'work_date',
        'hours_milli',
        'income_fen',
        'record_type',
        'is_breaking',
      ]),
    );
    for (final forbidden in const [
      'contact',
      'phone',
      'source_project_key',
      'local_device_id',
      'device_id',
      'auto_device_number',
    ]) {
      expect(
        ProjectExternalWorkShareBuilder.sourceFingerprintWhitelistV2,
        isNot(contains(forbidden)),
      );
    }
  });

  test('source_device_id is package-local, not the local device table id', () {
    final localDevice = Device(
      id: 9876,
      name: '设备9876',
      brand: 'CAT',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
    );
    const rec = TimingRecord(
      id: 9001,
      deviceId: 9876,
      startDate: 20240501,
      contact: '张三',
      site: '工地A',
      type: TimingType.hours,
      startMeter: 0,
      endMeter: 1,
      hours: 1,
      income: 100,
    );

    final p = builder.build(
      shareId: 'privacy-share',
      senderName: '李工',
      sourceInstallationUuid: 'pkg-source',
      records: const [rec],
      deviceMap: {9876: localDevice},
      calcHistoryMap: const {},
    );

    expect(p.devices.single.sourceDeviceId, 1);
    expect(p.records.single.sourceDeviceId, 1);
    expect(p.deviceGroups.single.sourceDeviceId, 1);
    expect(p.records.single.sourceDeviceId, isNot(9876));
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

  group('merged share (memberProjectIds)', () {
    // 两个成员项目：同联系人「余远」，工地「鲜滩」「尚义」。
    const memberRecordA = TimingRecord(
      id: 101,
      deviceId: 1,
      startDate: 20240201,
      contact: '余远',
      site: '鲜滩',
      type: TimingType.hours,
      startMeter: 0,
      endMeter: 8,
      hours: 8.0,
      income: 800.0, // deviceA 默认 100 → 一致
    );
    const memberRecordB = TimingRecord(
      id: 102,
      deviceId: 1,
      startDate: 20240202,
      contact: '余远',
      site: '尚义',
      type: TimingType.hours,
      startMeter: 8,
      endMeter: 13,
      hours: 5.0,
      income: 500.0,
    );

    test('aggregates records across member projects without span error', () {
      final p = builder.build(
        shareId: 'merge-share',
        senderName: '余远',
        sourceInstallationUuid: 'install',
        records: const [memberRecordB, memberRecordA], // 乱序
        deviceMap: {1: deviceA},
        calcHistoryMap: const {},
        expectedProjectId: 'merge:9',
        memberProjectIds: {
          memberRecordA.effectiveProjectId,
          memberRecordB.effectiveProjectId,
        },
      );

      // 跨成员项目不再被「records span multiple projects」拦截。
      expect(p.records.length, 2);
      // 每条 record 保留自己的成员项目来源（溯源）。
      final recA = p.records.firstWhere((r) => r.sourceTimingRecordId == 101);
      final recB = p.records.firstWhere((r) => r.sourceTimingRecordId == 102);
      expect(recA.sourceProjectId, memberRecordA.effectiveProjectId);
      expect(recB.sourceProjectId, memberRecordB.effectiveProjectId);
    });

    test('payload carries member_projects[] structure', () {
      final p = builder.build(
        shareId: 'merge-share',
        senderName: '余远',
        sourceInstallationUuid: 'install',
        records: const [memberRecordA, memberRecordB],
        deviceMap: {1: deviceA},
        calcHistoryMap: const {},
        expectedProjectId: 'merge:9',
        memberProjectIds: {
          memberRecordA.effectiveProjectId,
          memberRecordB.effectiveProjectId,
        },
      );

      expect(p.memberProjects, hasLength(2));
      final mA = p.memberProjects.firstWhere(
        (m) => m.sourceProjectId == memberRecordA.effectiveProjectId,
      );
      expect(mA.contactSnapshot, '余远');
      expect(mA.siteSnapshot, '鲜滩');
      expect(mA.displayName, '余远 · 鲜滩');
      expect(mA.recordIds, [101]);
      final mB = p.memberProjects.firstWhere(
        (m) => m.sourceProjectId == memberRecordB.effectiveProjectId,
      );
      expect(mB.recordIds, [102]);

      // 聚合展示名「分享人 · 地址摘要」。
      expect(p.projectSnapshot.displayName, '余远 · 鲜滩+尚义');
      expect(p.projectSnapshot.sourceProjectId, 'merge:9');
      expect(p.projectSnapshot.siteSnapshot, '鲜滩+尚义');

      // member_projects 经 toMap 输出，且 round-trip 可解析。
      final json = p.toMap();
      expect(json.containsKey('member_projects'), isTrue);
      final parsed = ProjectExternalWorkSharePayload.fromMap(json);
      expect(parsed.isMergedShare, isTrue);
      expect(parsed.memberProjects, hasLength(2));
      expect(parsed.projectSnapshot?.displayName, '余远 · 鲜滩+尚义');
    });

    test('still defends against truly unrelated (non-member) projects', () {
      const intruder = TimingRecord(
        id: 103,
        deviceId: 1,
        startDate: 20240203,
        contact: '陌生人',
        site: '无关工地',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 1,
        hours: 1,
        income: 100,
      );
      expect(
        () => builder.build(
          shareId: 'merge-share',
          senderName: '余远',
          sourceInstallationUuid: 'install',
          records: const [memberRecordA, intruder],
          deviceMap: {1: deviceA},
          calcHistoryMap: const {},
          expectedProjectId: 'merge:9',
          memberProjectIds: {
            memberRecordA.effectiveProjectId,
            memberRecordB.effectiveProjectId,
          },
        ),
        throwsArgumentError,
      );
    });

    test('single-project share has empty member_projects (additive)', () {
      final p = buildAll();
      expect(p.memberProjects, isEmpty);
      expect(p.projectSnapshot.displayName, isNull);
      expect(p.toMap().containsKey('member_projects'), isFalse);
    });
  });

  test('stale income from old device default + project override → '
      'trusts current override price and recomputes income (no "未知")', () {
    // 复刻 Bug 2：设备默认 180，项目覆盖价改为 100，但 income 仍是 180 旧口径。
    final deviceX = Device(
      id: 7,
      name: '挖机 7#',
      brand: 'CAT',
      defaultUnitPrice: 180.0,
      baseMeterHours: 0.0,
      equipmentType: EquipmentType.excavator,
    );
    const staleRecord = TimingRecord(
      id: 74,
      deviceId: 7,
      startDate: 20240305,
      contact: '余远',
      site: '鲜滩',
      type: TimingType.hours,
      startMeter: 0.0,
      endMeter: 70.1,
      hours: 70.1,
      income: 12618.0, // = 70.1 × 180（旧口径，未回写）
    );
    final override = ProjectDeviceRate(
      projectId: staleRecord.effectiveProjectId,
      projectKey: staleRecord.legacyProjectKey,
      deviceId: 7,
      rate: 100.0, // 当前有效项目单价 ¥100
    );

    final p = builder.build(
      shareId: 'stale-share',
      senderName: '余远',
      sourceInstallationUuid: 'install',
      records: const [staleRecord],
      deviceMap: {7: deviceX},
      calcHistoryMap: const {},
      projectDeviceRates: [override],
    );
    final rec = p.records.single;
    // source_unit_price_fen 用当前有效项目单价 ¥100 = 10000 fen。
    expect(rec.sourceUnitPriceFen, 10000);
    // income_fen = AmountPolicy(70.1h, 10000) = 701000，按当前单价口径重算。
    expect(rec.incomeFen, 701000);
  });
}
