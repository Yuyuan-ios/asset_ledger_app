import 'dart:io';
import 'dart:ui';

import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_calculation_history.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/data/repositories/timing_calculation_history_repository.dart';
import 'package:asset_ledger/data/services/project_share_file_presenter.dart';
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

class _FakeSharePresenter implements ProjectShareFilePresenter {
  _FakeSharePresenter({this.throwError});
  final Object? throwError;
  int calls = 0;
  String? filePath;
  String? fileName;
  String? text;
  String? subject;
  Rect? sharePositionOrigin;

  @override
  Future<void> share({
    required String filePath,
    required String fileName,
    required String text,
    required String subject,
    Rect? sharePositionOrigin,
  }) async {
    calls++;
    this.filePath = filePath;
    this.fileName = fileName;
    this.text = text;
    this.subject = subject;
    this.sharePositionOrigin = sharePositionOrigin;
    final err = throwError;
    if (err != null) throw err;
  }
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

  test('success opens share sheet with the .jzt file', () async {
    final dir = await Directory.systemTemp.createTemp('jztshare_uc_');
    addTearDown(() => dir.delete(recursive: true));
    final presenter = _FakeSharePresenter();
    final useCase = ProjectShareExportUseCase(
      _FakeCalcRepo(),
      directoryResolver: () async => dir,
      sharePresenter: presenter,
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
    expect(outcome.message, '分享包已生成，已打开分享面板');
    expect(presenter.calls, 1);
    expect(presenter.filePath, endsWith('.jzt'));
    expect(presenter.filePath, isNot(contains('.jztshare')));
    expect(presenter.fileName, outcome.fileName);
    expect(presenter.fileName, endsWith('.jzt'));
    expect(presenter.subject, '分享项目外协记录');
    expect(presenter.text, contains('FleetLedger'));
    expect(presenter.text, contains('项目外协记录'));
    expect(presenter.text, contains('.jzt'));
    expect(presenter.text, isNot(contains('.jztshare')));
    expect(presenter.sharePositionOrigin, isNull); // 暂不传，默认透传 null
    expect(await File('${dir.path}/${outcome.fileName}').exists(), isTrue);
  });

  test(
    'share sheet failure keeps the file and reports friendly error',
    () async {
      final dir = await Directory.systemTemp.createTemp('jztshare_uc_');
      addTearDown(() => dir.delete(recursive: true));
      final presenter = _FakeSharePresenter(
        throwError: const ProjectShareSheetException('分享面板打开失败，可稍后重试'),
      );
      final useCase = ProjectShareExportUseCase(
        _FakeCalcRepo(),
        directoryResolver: () async => dir,
        sharePresenter: presenter,
      );

      final outcome = await useCase.execute(
        projectId: a1.effectiveProjectId,
        projectKey: a1.legacyProjectKey,
        senderName: '老王',
        allRecords: const [a1],
        allDevices: devices,
        now: DateTime.utc(2026, 5, 19, 8),
      );

      expect(outcome.ok, isFalse);
      expect(outcome.message, '分享面板打开失败，分享包已保留，可稍后重试');
      // 文件仍保留在导出目录，不删除
      final files = dir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.jzt'),
      );
      expect(files.length, 1);
    },
  );

  test('generation failure does not call the share sheet', () async {
    final presenter = _FakeSharePresenter();
    final useCase = ProjectShareExportUseCase(
      _FakeCalcRepo(),
      directoryResolver: () async =>
          Directory.systemTemp.createTemp('jztshare_uc_'),
      sharePresenter: presenter,
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
    expect(presenter.calls, 0);
  });
}
