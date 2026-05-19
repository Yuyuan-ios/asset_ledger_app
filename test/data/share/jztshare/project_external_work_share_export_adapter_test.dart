import 'dart:io';

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
    return _byRecord[id] ?? const [];
  }

  @override
  Future<void> insertMany(int a, List<TimingCalculationHistory> b) async {}

  @override
  Future<void> deleteByTimingRecordId(int a) async {}
}

void main() {
  const adapter = ProjectExternalWorkShareExportAdapter();
  const producer = JztShareProducer(
    appName: '机账通',
    appVersion: '1.0.1+3',
    platform: 'ios',
  );
  const parser = JztShareEnvelopeParser();
  final createdAt = DateTime.utc(2026, 5, 19, 8);

  final devices = [
    const Device(
      id: 1,
      name: 'HITACHI 1#',
      brand: 'HITACHI',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
    ),
  ];

  // 项目 A：李杰/尚义
  const a1 = TimingRecord(
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
  const a2 = TimingRecord(
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
  const b1 = TimingRecord(
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
      allRecords: const [a1, b1, a2],
      allDevices: devices,
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
  });

  test('empty project throws noRecords', () async {
    expect(
      () => adapter.export(
        projectId: 'nope',
        projectKey: '不存在||项目',
        senderName: '老王',
        allRecords: const [a1, a2],
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
        allRecords: const [a1],
        allDevices: devices,
        calcHistoryRepository: _FakeCalcRepo(const {}),
        producer: producer,
        createdAt: createdAt,
        directoryResolver: tempResolver,
      ),
      throwsA(isA<ProjectShareExportException>()),
    );
  });
}
