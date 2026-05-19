import 'dart:io';

import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';
import 'package:asset_ledger/features/account/use_cases/project_share_export_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCalcRepo implements TimingCalculationHistoryRepository {
  @override
  Future<List<TimingCalculationHistory>> findByTimingRecordId(int id) async =>
      const [];
  @override
  Future<void> insertMany(int a, List<TimingCalculationHistory> b) async {}
  @override
  Future<void> deleteByTimingRecordId(int a) async {}
}

void main() {
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
  final devices = [
    const Device(
      id: 1,
      name: 'HITACHI 1#',
      brand: 'HITACHI',
      defaultUnitPrice: 100,
      baseMeterHours: 0,
    ),
  ];

  test('success outcome carries generated file name', () async {
    final dir = await Directory.systemTemp.createTemp('jztshare_uc_');
    addTearDown(() => dir.delete(recursive: true));
    final useCase = ProjectShareExportUseCase(
      _FakeCalcRepo(),
      directoryResolver: () async => dir,
    );

    final outcome = await useCase.execute(
      projectId: a1.effectiveProjectId,
      projectKey: a1.legacyProjectKey,
      senderName: '老王',
      allRecords: const [a1],
      allDevices: devices,
      now: DateTime.utc(2026, 5, 19, 8),
    );

    expect(outcome.ok, isTrue);
    expect(outcome.fileName, isNotNull);
    expect(outcome.message, contains('分享包已生成'));
    expect(await File('${dir.path}/${outcome.fileName}').exists(), isTrue);
  });

  test('no records yields a friendly failure outcome', () async {
    final useCase = ProjectShareExportUseCase(
      _FakeCalcRepo(),
      directoryResolver: () async =>
          Directory.systemTemp.createTemp('jztshare_uc_'),
    );

    final outcome = await useCase.execute(
      projectId: 'missing',
      projectKey: '不存在||项目',
      senderName: '老王',
      allRecords: const [a1],
      allDevices: devices,
    );

    expect(outcome.ok, isFalse);
    expect(outcome.message, '当前项目暂无可分享记录');
  });
}
