import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/external_import_batch.dart';
import 'package:asset_ledger/data/models/external_work_record.dart';
import 'package:asset_ledger/data/models/project_device_rate.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/reports/infrastructure/timing_worklog_excel_writer.dart';
import 'package:asset_ledger/features/reports/models/timing_worklog_report.dart';
import 'package:asset_ledger/features/reports/presentation/report_file_presenter.dart';
import 'package:asset_ledger/features/reports/use_cases/build_timing_worklog_report_use_case.dart';
import 'package:asset_ledger/features/reports/use_cases/export_timing_worklog_excel_use_case.dart';
import 'package:asset_ledger/features/timing/state/timing_external_work_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePresenter implements ReportFilePresenter {
  _FakePresenter({this.throwError});
  final Object? throwError;
  int calls = 0;
  String? fileName;
  String? filePath;

  @override
  Future<void> share({
    required String filePath,
    required String fileName,
    required String text,
    required String subject,
    Rect? sharePositionOrigin,
  }) async {
    calls += 1;
    this.fileName = fileName;
    this.filePath = filePath;
    final error = throwError;
    if (error != null) throw error;
  }
}

void main() {
  final hitachi = Device(
    id: 1,
    name: 'HITACHI 1#',
    brand: '日立',
    model: '150',
    defaultUnitPrice: 100,
    baseMeterHours: 0,
  );

  test('report builder uses brand and model for machine type', () {
    final report = const BuildTimingWorklogReportUseCase().execute(
      records: const [
        TimingRecord(
          id: 2,
          deviceId: 1,
          startDate: 20260527,
          contact: '张三',
          site: '工地B',
          type: TimingType.hours,
          startMeter: 108,
          endMeter: 113.5,
          hours: 5.5,
          income: 550,
        ),
        TimingRecord(
          id: 1,
          deviceId: 1,
          startDate: 20260526,
          contact: '张三',
          site: '工地A',
          type: TimingType.hours,
          startMeter: 100,
          endMeter: 108,
          hours: 8,
          income: 800,
        ),
      ],
      devices: [hitachi],
    );

    expect(report.rows, hasLength(2));
    expect(report.rows.first.sequence, 1);
    expect(report.rows.first.date, 20260526);
    expect(report.rows.first.deviceName, '日立150');
    expect(report.rows.first.startMeter, 100);
    expect(report.rows.first.endMeter, 108);
    expect(report.rows.first.hours, 8);
    expect(report.totalHours, 13.5);
    expect(report.deviceFileNamePart, '日立150');
  });

  test('report builder maps linked external work rows', () {
    final report = const BuildTimingWorklogReportUseCase().execute(
      records: const [],
      devices: [],
      externalWorkItems: [
        _externalItem(
          id: 'external-a',
          linkedProjectId: 'project-a',
          workDate: 20260527,
          hours: 4.5,
          equipmentBrand: '卡特',
          equipmentModel: '320',
        ),
      ],
    );

    expect(report.rows, hasLength(1));
    expect(report.rows.single.sequence, 1);
    expect(report.rows.single.date, 20260527);
    expect(report.rows.single.deviceName, '卡特320');
    expect(report.rows.single.startMeter, isNull);
    expect(report.rows.single.endMeter, isNull);
    expect(report.rows.single.hours, 4.5);
    expect(report.totalHours, 4.5);
  });

  test('report builder keeps multi-unit quantities and fen amounts', () {
    final report = const BuildTimingWorklogReportUseCase().execute(
      records: [
        _recordWith(
          id: 1,
          unit: MeasureUnit.hour,
          quantityScaled: 2500,
          hours: 2.5,
        ),
        _recordWith(
          id: 2,
          unit: MeasureUnit.trip,
          quantityScaled: 3000,
          startMeter: 0,
          endMeter: 0,
          hours: 0,
        ),
      ],
      devices: [hitachi],
      rates: const [
        ProjectDeviceRate(
          projectId: 'project-a',
          projectKey: '张三||工地',
          deviceId: 1,
          rate: 80,
        ),
      ],
    );
    final sheet = _sheetXml(report);
    final cells = _cells(sheet);

    expect(report.totalHours, 2.5);
    expect(report.totalAmountFen, 44000);
    expect(report.unitTotals.map((total) => total.unit), [
      MeasureUnit.hour,
      MeasureUnit.trip,
    ]);
    expect(report.rows.last.unit, MeasureUnit.trip);
    expect(report.rows.last.amountFen, 24000);
    expect(cells['J4'], '2.5');
    expect(cells['K4'], '小时');
    expect(cells['L4'], '80');
    expect(cells['M4'], '200');
    expect(cells['H5'], '');
    expect(cells['J5'], '3');
    expect(cells['K5'], '趟');
    expect(cells['M5'], '240');
    expect(cells['J24'], '2.5小时、3趟');
    expect(cells['M24'], '440');
  });

  test(
    'report builder falls back to device name when brand and model are empty',
    () {
      final report = const BuildTimingWorklogReportUseCase().execute(
        records: const [
          TimingRecord(
            id: 1,
            deviceId: 9,
            startDate: 20260526,
            contact: '张三',
            site: '工地',
            type: TimingType.hours,
            startMeter: 100,
            endMeter: 108,
            hours: 8,
            income: 800,
          ),
        ],
        devices: [
          Device(
            id: 9,
            name: 'HITACHI 1#',
            brand: '',
            defaultUnitPrice: 100,
            baseMeterHours: 0,
          ),
        ],
      );

      expect(report.rows.single.deviceName, 'HITACHI 1#');
      expect(report.deviceFileNamePart, 'HITACHI1号');
    },
  );

  test('excel writer builds the fixed template header structure', () {
    final report = const BuildTimingWorklogReportUseCase().execute(
      records: const [_record],
      devices: [hitachi],
    );
    final sheet = _sheetXml(report);
    final cells = _cells(sheet);

    expect(cells['A1'], '项目对账明细');
    expect(cells['E2'], '施工地点');
    expect(cells['F2'], '项目名称');
    expect(cells['H2'], '码表');
    expect(cells['H3'], '起');
    expect(cells['I3'], '止');
    expect(cells['J2'], '数量');
    expect(cells['K2'], '单位');
    expect(cells['L2'], '单价（元/单位）');
    expect(cells['M2'], '金额（元）');
    expect(cells['N2'], '来源');
    expect(cells['O2'], '负责人');
    expect(cells['P2'], '备注');
    expect(sheet, contains('<mergeCell ref="H2:I2"/>'));
    expect(sheet, contains(TimingWorklogExcelWriter.invoiceText));
    expect(sheet, contains(TimingWorklogExcelWriter.basisText));
  });

  test('excel writer maps meter quantity unit price and amount columns', () {
    final report = const BuildTimingWorklogReportUseCase().execute(
      records: const [_record],
      devices: [hitachi],
    );
    final cells = _cells(_sheetXml(report));

    expect(cells['C4'], '日立150');
    expect(cells['D4'], '张三');
    expect(cells['E4'], '工地');
    expect(cells['F4'], '张三 · 工地');
    expect(cells['H4'], '100.5');
    expect(cells['I4'], '108');
    expect(cells['J4'], '7.5');
    expect(cells['K4'], '小时');
    expect(cells['L4'], '100');
    expect(cells['M4'], '750');
    expect(cells['N4'], '本机');
  });

  test(
    'excel writer keeps signatures headers page breaks and totals on every page',
    () {
      final records = List<TimingRecord>.generate(21, (i) {
        return TimingRecord(
          id: i + 1,
          deviceId: 1,
          startDate: 20260501 + i,
          contact: '张三',
          site: '工地',
          type: TimingType.hours,
          startMeter: 100 + i.toDouble(),
          endMeter: 101 + i.toDouble(),
          hours: 1,
          income: 100,
        );
      });
      final report = const BuildTimingWorklogReportUseCase().execute(
        records: records,
        devices: [hitachi],
      );
      const writer = TimingWorklogExcelWriter(recordsPerPage: 20);
      final archive = ZipDecoder().decodeBytes(writer.write(report));
      final sheet = utf8.decode(
        archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
      );
      final workbook = utf8.decode(
        archive.findFile('xl/workbook.xml')!.content as List<int>,
      );
      final cells = _cells(sheet);

      expect(writer.paginate(report), hasLength(2));
      expect(cells['J2'], '数量');
      expect(cells['J29'], '数量');
      expect(
        TimingWorklogExcelWriter.signatureText.allMatches(sheet),
        hasLength(2),
      );
      expect(
        TimingWorklogExcelWriter.invoiceText.allMatches(sheet),
        hasLength(2),
      );
      expect(
        TimingWorklogExcelWriter.basisText.allMatches(sheet),
        hasLength(2),
      );
      expect(cells['J24'], '20小时');
      expect(cells['M24'], '2000');
      expect(cells['J51'], '21小时');
      expect(cells['M51'], '2100');
      expect(sheet, contains('<rowBreaks count="1" manualBreakCount="1">'));
      expect(
        sheet,
        contains('<pageSetup paperSize="9" orientation="landscape"'),
      );
      expect(workbook, contains('_xlnm.Print_Area'));
      expect(workbook, contains('\$A\$1:\$P\$54'));
    },
  );

  test('export use case writes xlsx file and opens share presenter', () async {
    final dir = await Directory.systemTemp.createTemp('timing_worklog_');
    addTearDown(() => dir.delete(recursive: true));
    final presenter = _FakePresenter();
    final useCase = ExportTimingWorklogExcelUseCase(
      directoryResolver: () async => dir,
      presenter: presenter,
    );

    final outcome = await useCase.execute(
      scope: TimingWorklogExportScope.singleProject(
        projectId: 'project-a',
        fileNamePart: '李洋 · 天眉乐',
      ),
      records: const [_record],
      devices: [hitachi],
    );

    expect(outcome.ok, isTrue);
    expect(presenter.calls, 1);
    expect(presenter.fileName, '项目对账明细_李洋_天眉乐_20260526-20260526.xlsx');
    expect(await File(presenter.filePath!).exists(), isTrue);
  });

  test(
    'export use case filters project records and excludes external work by default',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'timing_worklog_project_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final presenter = _FakePresenter();
      final useCase = ExportTimingWorklogExcelUseCase(
        directoryResolver: () async => dir,
        presenter: presenter,
      );

      final outcome = await useCase.execute(
        scope: TimingWorklogExportScope.singleProject(
          projectId: 'project-a',
          fileNamePart: '李洋 · 天眉乐',
        ),
        records: [
          _record.copyWith(id: 1, projectId: 'project-b', startDate: 20260520),
          _record.copyWith(
            id: 2,
            projectId: 'project-a',
            startDate: 20260521,
            startMeter: 10,
            endMeter: 12,
            hours: 2,
          ),
          _record.copyWith(
            id: 3,
            projectId: 'project-b',
            startDate: 20260526,
            startMeter: 20,
            endMeter: 23,
            hours: 3,
          ),
        ],
        devices: [hitachi],
        externalWorkItems: [
          _externalItem(
            id: 'external-a',
            linkedProjectId: 'project-a',
            workDate: 20260522,
            hours: 4.5,
            equipmentBrand: '卡特',
            equipmentModel: '320',
          ),
          _externalItem(
            id: 'external-b',
            linkedProjectId: 'project-b',
            workDate: 20260523,
            hours: 9,
          ),
          _externalItem(
            id: 'external-unlinked',
            linkedProjectId: null,
            workDate: 20260524,
            hours: 8,
          ),
          _externalItem(
            id: 'external-ignored',
            linkedProjectId: 'project-a',
            workDate: 20260525,
            hours: 7,
            status: ExternalWorkRecordStatus.ignored,
          ),
          _externalItem(
            id: 'external-archived-batch',
            linkedProjectId: 'project-a',
            workDate: 20260526,
            hours: 6,
            batchStatus: ExternalImportBatchStatus.archived,
          ),
        ],
      );
      final cells = _cells(_sheetXmlFromFile(presenter.filePath!));

      expect(outcome.ok, isTrue);
      expect(presenter.fileName, '项目对账明细_李洋_天眉乐_20260521-20260521.xlsx');
      expect(cells['A4'], '1');
      expect(cells['B4'], '2026.05.21');
      expect(cells['C4'], '日立150');
      expect(cells['H4'], '10');
      expect(cells['I4'], '12');
      expect(cells['J4'], '2');
      expect(cells['K4'], '小时');
      expect(cells['L4'], '100');
      expect(cells['M4'], '200');
      expect(cells['N4'], '本机');
      expect(cells['B5'], '');
      expect(cells['J24'], '2小时');
      expect(cells['M24'], '200');
    },
  );

  test('export use case filters by project device and date range', () async {
    final dir = await Directory.systemTemp.createTemp(
      'timing_worklog_filtered_',
    );
    addTearDown(() => dir.delete(recursive: true));
    final presenter = _FakePresenter();
    final useCase = ExportTimingWorklogExcelUseCase(
      directoryResolver: () async => dir,
      presenter: presenter,
    );

    final outcome = await useCase.execute(
      scope: TimingWorklogExportScope.filtered(
        fileNamePart: '设备1_5月',
        projectIds: const ['project-a'],
        deviceIds: const [1],
        startDate: 20260521,
        endDate: 20260522,
      ),
      records: [
        _record.copyWith(
          id: 1,
          deviceId: 1,
          projectId: 'project-a',
          startDate: 20260521,
          hours: 2,
        ),
        _record.copyWith(
          id: 2,
          deviceId: 1,
          projectId: 'project-a',
          startDate: 20260523,
          hours: 3,
        ),
        _record.copyWith(
          id: 3,
          deviceId: 2,
          projectId: 'project-a',
          startDate: 20260522,
          hours: 4,
        ),
        _record.copyWith(
          id: 4,
          deviceId: 1,
          projectId: 'project-b',
          startDate: 20260522,
          hours: 5,
        ),
      ],
      devices: [hitachi, _komatsu],
    );
    final cells = _cells(_sheetXmlFromFile(presenter.filePath!));

    expect(outcome.ok, isTrue);
    expect(presenter.fileName, '项目对账明细_设备1_5月_20260521-20260521.xlsx');
    expect(cells['A4'], '1');
    expect(cells['B4'], '2026.05.21');
    expect(cells['C4'], '日立150');
    expect(cells['J4'], '2');
    expect(cells['B5'], '');
    expect(cells['J24'], '2小时');
    expect(cells['M24'], '200');
  });

  test('export use case expands merged project to member projects', () async {
    final dir = await Directory.systemTemp.createTemp('timing_worklog_merged_');
    addTearDown(() => dir.delete(recursive: true));
    final presenter = _FakePresenter();
    final useCase = ExportTimingWorklogExcelUseCase(
      directoryResolver: () async => dir,
      presenter: presenter,
    );

    final outcome = await useCase.execute(
      scope: TimingWorklogExportScope.mergedProject(
        memberProjectIds: const ['member-a', 'member-b', 'merge:2'],
        fileNamePart: '李杰 · 合并2项目',
        includeExternalWork: true,
      ),
      records: [
        _record.copyWith(
          id: 1,
          projectId: 'member-a',
          startDate: 20260312,
          hours: 2,
        ),
        _record.copyWith(
          id: 2,
          projectId: 'member-b',
          startDate: 20260601,
          hours: 4,
        ),
        _record.copyWith(id: 3, projectId: 'project-c', startDate: 20260501),
        _record.copyWith(id: 4, projectId: 'merge:2', startDate: 20260502),
      ],
      devices: [hitachi],
      externalWorkItems: [
        _externalItem(
          id: 'external-member-a',
          linkedProjectId: 'member-a',
          workDate: 20260313,
          hours: 1.5,
          equipmentBrand: '小松',
          equipmentModel: '200',
        ),
        _externalItem(
          id: 'external-member-b',
          linkedProjectId: 'member-b',
          workDate: 20260530,
          hours: 2.5,
        ),
        _externalItem(
          id: 'external-project-c',
          linkedProjectId: 'project-c',
          workDate: 20260531,
          hours: 8,
        ),
        _externalItem(
          id: 'external-merge-id',
          linkedProjectId: 'merge:2',
          workDate: 20260602,
          hours: 16,
        ),
      ],
    );
    final cells = _cells(_sheetXmlFromFile(presenter.filePath!));

    expect(outcome.ok, isTrue);
    expect(presenter.fileName, '项目对账明细_李杰_合并2项目_20260312-20260601.xlsx');
    expect(cells['B4'], '2026.03.12');
    expect(cells['B5'], '2026.03.13');
    expect(cells['C5'], '小松200');
    expect(cells['H5'], '');
    expect(cells['I5'], '');
    expect(cells['J5'], '1.5');
    expect(cells['N5'], '外协');
    expect(cells['B6'], '2026.05.30');
    expect(cells['J6'], '2.5');
    expect(cells['N6'], '外协');
    expect(cells['B7'], '2026.06.01');
    expect(cells['J7'], '4');
    expect(cells['N7'], '本机');
    expect(cells['B8'], '');
    expect(cells['J24'], '10小时');
    expect(cells['M24'], '602');
  });

  test(
    'export use case allows project with only linked external work',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'timing_worklog_external_only_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final presenter = _FakePresenter();
      final useCase = ExportTimingWorklogExcelUseCase(
        directoryResolver: () async => dir,
        presenter: presenter,
      );

      final outcome = await useCase.execute(
        scope: TimingWorklogExportScope.singleProject(
          projectId: 'project-a',
          fileNamePart: '李洋 · 天眉乐',
          includeExternalWork: true,
        ),
        records: const [],
        devices: [hitachi],
        externalWorkItems: [
          _externalItem(
            id: 'external-only',
            linkedProjectId: 'project-a',
            workDate: 20260528,
            hours: 3.5,
            equipmentModel: '神钢75',
          ),
        ],
      );
      final cells = _cells(_sheetXmlFromFile(presenter.filePath!));

      expect(outcome.ok, isTrue);
      expect(presenter.calls, 1);
      expect(presenter.fileName, '项目对账明细_李洋_天眉乐_20260528-20260528.xlsx');
      expect(cells['B4'], '2026.05.28');
      expect(cells['C4'], '神钢75');
      expect(cells['H4'], '');
      expect(cells['I4'], '');
      expect(cells['J4'], '3.5');
      expect(cells['K4'], '小时');
      expect(cells['M4'], '1');
      expect(cells['N4'], '外协');
      expect(cells['J24'], '3.5小时');
      expect(cells['M24'], '1');
    },
  );

  test('export use case reports empty and share failure friendly', () async {
    final presenter = _FakePresenter();
    final useCase = ExportTimingWorklogExcelUseCase(presenter: presenter);
    final empty = await useCase.execute(
      scope: TimingWorklogExportScope.singleProject(
        projectId: 'project-a',
        fileNamePart: '李洋 · 天眉乐',
      ),
      records: const [],
      devices: [],
      externalWorkItems: [
        _externalItem(
          id: 'empty-linked-default',
          linkedProjectId: 'project-a',
          workDate: 20260526,
          hours: 1,
        ),
        _externalItem(
          id: 'empty-unlinked',
          linkedProjectId: null,
          workDate: 20260526,
          hours: 1,
        ),
        _externalItem(
          id: 'empty-ignored',
          linkedProjectId: 'project-a',
          workDate: 20260526,
          hours: 1,
          status: ExternalWorkRecordStatus.ignored,
        ),
        _externalItem(
          id: 'empty-voided-batch',
          linkedProjectId: 'project-a',
          workDate: 20260526,
          hours: 1,
          batchStatus: ExternalImportBatchStatus.voided,
        ),
      ],
    );
    expect(empty.ok, isFalse);
    expect(empty.message, '该项目暂无可导出的工时记录');
    expect(presenter.calls, 0);

    final dir = await Directory.systemTemp.createTemp('timing_worklog_fail_');
    addTearDown(() => dir.delete(recursive: true));
    final failing = ExportTimingWorklogExcelUseCase(
      directoryResolver: () async => dir,
      presenter: _FakePresenter(
        throwError: const ReportShareSheetException('x'),
      ),
    );
    final result = await failing.execute(
      scope: TimingWorklogExportScope.singleProject(
        projectId: 'project-a',
        fileNamePart: '李洋 · 天眉乐',
      ),
      records: const [_record],
      devices: [hitachi],
    );
    expect(result.ok, isFalse);
    expect(result.message, '分享面板打开失败，工时表已保留，可稍后重试');
    expect(dir.listSync().whereType<File>().single.path, endsWith('.xlsx'));
  });
}

TimingExternalWorkRecordItem _externalItem({
  required String id,
  required String? linkedProjectId,
  required int workDate,
  required double hours,
  String? equipmentBrand,
  String? equipmentModel,
  String? equipmentType,
  ExternalWorkRecordStatus status = ExternalWorkRecordStatus.active,
  ExternalImportBatchStatus batchStatus = ExternalImportBatchStatus.active,
}) {
  final batchId = 'batch-$id';
  const createdAt = '2026-05-01T00:00:00Z';
  return TimingExternalWorkRecordItem(
    record: ExternalWorkRecord.imported(
      id: id,
      importBatchId: batchId,
      sourceShareId: 'share-$id',
      sourceRecordUuid: 'record-$id',
      sourceInstallationUuid: 'installation-$id',
      originFingerprint: 'fingerprint-$id',
      collaboratorName: '外协人',
      contactSnapshot: '联系人',
      siteSnapshot: '工地',
      equipmentBrand: equipmentBrand,
      equipmentModel: equipmentModel,
      equipmentType: equipmentType,
      workDate: workDate,
      hoursMilli: (hours * 1000).round(),
      amountFen: 100,
      linkedProjectId: linkedProjectId,
      status: status,
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
    batch: ExternalImportBatch(
      id: batchId,
      sourceShareId: 'share-$id',
      sourceDisplayName: '外协包',
      recordCount: 1,
      totalHoursMilli: (hours * 1000).round(),
      totalAmountFen: 100,
      siteSummary: '工地',
      importedAt: createdAt,
      status: batchStatus,
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
}

const _record = TimingRecord(
  id: 1,
  deviceId: 1,
  startDate: 20260526,
  projectId: 'project-a',
  contact: '张三',
  site: '工地',
  type: TimingType.hours,
  startMeter: 100.5,
  endMeter: 108,
  hours: 7.5,
  income: 750,
);

final _komatsu = Device(
  id: 2,
  name: 'KOMATSU 2#',
  brand: '小松',
  model: '200',
  defaultUnitPrice: 120,
  baseMeterHours: 0,
);

TimingRecord _recordWith({
  required int id,
  required MeasureUnit unit,
  required int quantityScaled,
  double startMeter = 100,
  double endMeter = 102.5,
  double hours = 2.5,
}) {
  return TimingRecord(
    id: id,
    deviceId: 1,
    startDate: 20260526,
    projectId: 'project-a',
    contact: '张三',
    site: '工地',
    type: TimingType.hours,
    startMeter: startMeter,
    endMeter: endMeter,
    hours: hours,
    income: 0,
    unit: unit,
    quantityScaled: quantityScaled,
  );
}

String _sheetXml(TimingWorklogReport report) {
  final archive = ZipDecoder().decodeBytes(
    const TimingWorklogExcelWriter().write(report),
  );
  return utf8.decode(
    archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
  );
}

String _sheetXmlFromFile(String path) {
  final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
  return utf8.decode(
    archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
  );
}

Map<String, String> _cells(String sheetXml) {
  final cells = <String, String>{};
  final cellPattern = RegExp(r'<c r="([A-Z]+\d+)"[^>]*>(.*?)</c>');
  for (final match in cellPattern.allMatches(sheetXml)) {
    final ref = match.group(1)!;
    final body = match.group(2)!;
    final text = RegExp(r'<t>(.*?)</t>').firstMatch(body)?.group(1);
    final number = RegExp(r'<v>(.*?)</v>').firstMatch(body)?.group(1);
    cells[ref] = _unescapeXml(text ?? number ?? '');
  }
  return cells;
}

String _unescapeXml(String value) {
  return value
      .replaceAll('&apos;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&gt;', '>')
      .replaceAll('&lt;', '<')
      .replaceAll('&amp;', '&');
}
