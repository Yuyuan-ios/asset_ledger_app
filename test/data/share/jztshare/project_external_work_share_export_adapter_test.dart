import 'dart:io';

import 'package:asset_ledger/data/models/account_payment.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';
import 'package:asset_ledger/data/share/jztshare/project_external_work_share_export_adapter.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope.dart';
import 'package:asset_ledger/data/share/jztshare/share_envelope_parser.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCalcRepo implements TimingCalculationHistoryRepository {
  _FakeCalcRepo(this._byRecord);
  final Map<int, List<TimingCalculationHistory>> _byRecord;
  final List<int> queried = [];

  @override
  Future<List<TimingCalculationHistory>> findByTimingRecordId(int id) async {
    queried.add(id);
    return _byRecord[id] ?? [];
  }

  @override
  Future<void> insertMany(int a, List<TimingCalculationHistory> b) async {}

  @override
  Future<void> deleteByTimingRecordId(int a) async {}
}

void main() {
  const adapter = ProjectExternalWorkShareExportAdapter();
  const producer = JztShareProducer(
    appName: 'FleetLedger',
    appVersion: '1.0.1+3',
    platform: 'ios',
  );
  const parser = JztShareEnvelopeParser();
  final createdAt = DateTime.utc(2026, 5, 19, 8);

  final devices = [
    Device(
      id: 1,
      name: 'HITACHI 1#',
      brand: 'HITACHI',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
    ),
  ];

  // 项目 A：李杰/尚义
  final a1 = TimingRecord(
    id: 11,
    deviceId: 1,
    startDate: 20260501,
    contact: '李杰',
    site: '尚义',
    type: TimingType.hours,
    startMeter: 0,
    endMeter: 8,
    hours: 8,
    income: 800,
  );
  final a2 = TimingRecord(
    id: 12,
    deviceId: 1,
    startDate: 20260502,
    contact: '李杰',
    site: '尚义',
    type: TimingType.hours,
    startMeter: 8,
    endMeter: 13,
    hours: 5,
    income: 500,
  );
  // 项目 B：王五/工地B（不应出现在 A 的分享包里）
  final b1 = TimingRecord(
    id: 21,
    deviceId: 1,
    startDate: 20260503,
    contact: '王五',
    site: '工地B',
    type: TimingType.hours,
    startMeter: 0,
    endMeter: 3,
    hours: 3,
    income: 300,
  );

  Future<Directory> tempResolver() =>
      Directory.systemTemp.createTemp('jztshare_adapter_');

  test('assembles only current project records and writes file', () async {
    final dir = await Directory.systemTemp.createTemp('jztshare_adapter_');
    addTearDown(() => dir.delete(recursive: true));
    final calcRepo = _FakeCalcRepo({
      11: [
        TimingCalculationHistory(
          id: 'h1',
          timingRecordId: 11,
          createdAt: DateTime.utc(2026, 5, 1, 9),
          expression: '4+4',
          result: 8,
          ticketCount: 1,
        ),
      ],
    });

    final result = await adapter.export(
      projectId: a1.effectiveProjectId,
      projectKey: a1.legacyProjectKey,
      senderName: '  老王外协  ',
      allRecords: [a1, b1, a2],
      allDevices: devices,
      allPayments: [
        AccountPayment(
          projectId: a1.effectiveProjectId,
          projectKey: a1.legacyProjectKey,
          ymd: 20260504,
          amount: 321.09,
        ),
        AccountPayment(
          projectId: b1.effectiveProjectId,
          projectKey: b1.legacyProjectKey,
          ymd: 20260504,
          amount: 999,
        ),
      ],
      calcHistoryRepository: calcRepo,
      producer: producer,
      createdAt: createdAt,
      directoryResolver: () async => dir,
    );

    expect(result.recordCount, 2); // 只含 A 的两条
    expect(result.deviceCount, 1);
    expect(result.totalIncomeFen, 130000);
    expect(result.fileName, startsWith('老王外协_20260519'));
    expect(await File(result.filePath!).exists(), isTrue);

    // calc history 只查询了 A 的记录
    expect(calcRepo.queried.toSet(), {11, 12});

    final parsed = parser.parseProjectExternalWorkShare(
      await File(result.filePath!).readAsString(),
    );
    expect(parsed.payload.senderName, '老王外协'); // 已 trim
    // 富 records 全部属于 A
    final records =
        parser
                .parseProjectExternalWorkShare(
                  await File(result.filePath!).readAsString(),
                )
                .envelope
                .payload['records']
            as List<Object?>;
    expect(records.length, 2);
    final projectSnapshot =
        parsed.envelope.payload['project_snapshot'] as Map<String, Object?>;
    expect(projectSnapshot['project_received_fen'], 32109);
  });

  test('empty project throws noRecords', () async {
    expect(
      () => adapter.export(
        projectId: 'nope',
        projectKey: '不存在||项目',
        senderName: '老王',
        allRecords: [a1, a2],
        allDevices: devices,
        calcHistoryRepository: _FakeCalcRepo(const {}),
        producer: producer,
        createdAt: createdAt,
        directoryResolver: tempResolver,
      ),
      throwsA(
        isA<ProjectShareExportException>().having(
          (e) => e.code,
          'code',
          ProjectShareExportException.noRecords,
        ),
      ),
    );
  });

  test('blank sender name is rejected', () async {
    expect(
      () => adapter.export(
        projectId: a1.effectiveProjectId,
        projectKey: a1.legacyProjectKey,
        senderName: '   ',
        allRecords: [a1],
        allDevices: devices,
        calcHistoryRepository: _FakeCalcRepo(const {}),
        producer: producer,
        createdAt: createdAt,
        directoryResolver: tempResolver,
      ),
      throwsA(isA<ProjectShareExportException>()),
    );
  });

  test(
    'explicit projectId does not legacy-fallback into old project',
    () async {
      final dir = await Directory.systemTemp.createTemp('jztshare_adapter_');
      addTearDown(() => dir.delete(recursive: true));

      // 同联系人/同地址 → legacyProjectKey 相同，但 projectId 不同。
      final current = TimingRecord(
        id: 41,
        deviceId: 1,
        startDate: 20260601,
        projectId: 'P-NEW',
        contact: '李杰',
        site: '尚义',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 8,
        hours: 8,
        income: 800,
      );
      final old = TimingRecord(
        id: 42,
        deviceId: 1,
        startDate: 20260101,
        projectId: 'P-OLD',
        contact: '李杰',
        site: '尚义',
        type: TimingType.hours,
        startMeter: 0,
        endMeter: 5,
        hours: 5,
        income: 500,
      );
      expect(current.legacyProjectKey, old.legacyProjectKey);
      expect(current.effectiveProjectId, isNot(old.effectiveProjectId));

      final result = await adapter.export(
        projectId: current.effectiveProjectId,
        projectKey: current.legacyProjectKey,
        senderName: '老王',
        allRecords: [current, old],
        allDevices: devices,
        calcHistoryRepository: _FakeCalcRepo(const {}),
        producer: producer,
        createdAt: createdAt,
        directoryResolver: () async => dir,
      );

      // 只含当前 projectId 的一条；不被 builder 拦成“分享数据异常”。
      expect(result.recordCount, 1);
      final parsed = parser.parseProjectExternalWorkShare(
        await File(result.filePath!).readAsString(),
      );
      final records = parsed.envelope.payload['records'] as List<Object?>;
      expect(records.length, 1);
      expect(
        (records.single as Map<String, Object?>)['source_timing_record_id'],
        41,
      );
    },
  );

  test(
    'legacy project without projectId still matches by projectKey',
    () async {
      final dir = await Directory.systemTemp.createTemp('jztshare_adapter_');
      addTearDown(() => dir.delete(recursive: true));

      // a1/a2 的 projectId 为空 → effectiveProjectId 由 legacyProjectKey 派生。
      final result = await adapter.export(
        projectId: '', // legacy 场景：无明确 projectId
        projectKey: a1.legacyProjectKey,
        senderName: '老王',
        allRecords: [a1, a2, b1],
        allDevices: devices,
        calcHistoryRepository: _FakeCalcRepo(const {}),
        producer: producer,
        createdAt: createdAt,
        directoryResolver: () async => dir,
      );
      expect(result.recordCount, 2); // 只 A 的两条，B 不混入
    },
  );

  test('repacking regenerates package-local source identifiers', () async {
    final dir = await Directory.systemTemp.createTemp('jztshare_adapter_');
    addTearDown(() => dir.delete(recursive: true));
    final localDevice = Device(
      id: 9876,
      name: 'CAT 9876',
      brand: 'CAT',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
    );
    final record = TimingRecord(
      id: 9001,
      deviceId: 9876,
      startDate: 20260601,
      projectId: 'project-private',
      contact: '李杰',
      site: '尚义',
      type: TimingType.hours,
      startMeter: 0,
      endMeter: 8,
      hours: 8,
      income: 800,
    );

    Future<String> exportOnce() async {
      final result = await adapter.export(
        projectId: record.effectiveProjectId,
        projectKey: record.legacyProjectKey,
        senderName: '老王',
        allRecords: [record],
        allDevices: [localDevice],
        calcHistoryRepository: _FakeCalcRepo(const {}),
        producer: producer,
        createdAt: createdAt,
        directoryResolver: () async => dir,
      );
      return File(result.filePath!).readAsString();
    }

    final first = parser.parseProjectExternalWorkShare(await exportOnce());
    final second = parser.parseProjectExternalWorkShare(await exportOnce());

    expect(first.envelope.shareId, isNot(second.envelope.shareId));
    expect(
      first.payload.sourceInstallationUuid,
      isNot(second.payload.sourceInstallationUuid),
    );
    expect(first.payload.sourceInstallationUuid, startsWith('pkg-'));
    expect(first.payload.sourceInstallationUuid, isNot(contains('project')));

    final firstRecord = first.payload.richRecords!.single;
    final secondRecord = second.payload.richRecords!.single;
    expect(firstRecord.sourceRecordUuid, isNot(secondRecord.sourceRecordUuid));
    expect(
      firstRecord.sourceRecordUuid,
      matches(RegExp(r'^rec-[0-9a-f]{24}$')),
    );
    expect(firstRecord.sourceDeviceId, 1);
    expect(firstRecord.sourceDeviceId, isNot(9876));
    expect(
      first.payload.exportLines.single.exportLineUuid,
      isNot(second.payload.exportLines.single.exportLineUuid),
    );
    expect(
      first.envelope.integrity.payloadSha256,
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
    expect(
      second.envelope.integrity.payloadSha256,
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
  });
}
