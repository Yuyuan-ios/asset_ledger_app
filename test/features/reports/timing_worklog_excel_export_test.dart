import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/reports/infrastructure/timing_worklog_excel_writer.dart';
import 'package:asset_ledger/features/reports/models/timing_worklog_report.dart';
import 'package:asset_ledger/features/reports/presentation/report_file_presenter.dart';
import 'package:asset_ledger/features/reports/use_cases/build_timing_worklog_report_use_case.dart';
import 'package:asset_ledger/features/reports/use_cases/export_timing_worklog_excel_use_case.dart';
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
  const hitachi = Device(
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
      devices: const [hitachi],
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
        devices: const [
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
      devices: const [hitachi],
    );
    final sheet = _sheetXml(report);
    final cells = _cells(sheet);

    expect(cells['A1'], '挖机工时打卡汇总');
    expect(sheet, contains('<mergeCell ref="E2:F2"/>'));
    expect(cells['E2'], '施工地点');
    expect(cells['E3'], '地点');
    expect(cells['F3'], '项目名称');
    expect(cells['H2'], '上午');
    expect(cells['I2'], '中午');
    expect(cells['J2'], '中午');
    expect(cells['K2'], '下午');
    expect(sheet, contains('<mergeCell ref="L2:N2"/>'));
    expect(cells['L2'], '合计时间（时）');
    expect(cells['L3'], '上午');
    expect(cells['M3'], '下午');
    expect(cells['N3'], '全天');
    expect(cells['O2'], '负责人');
    expect(cells['P2'], '备注');
  });

  test('excel writer maps meters only into total-time columns', () {
    final report = const BuildTimingWorklogReportUseCase().execute(
      records: const [_record],
      devices: const [hitachi],
    );
    final cells = _cells(_sheetXml(report));

    expect(cells['C4'], '日立150');
    expect(cells['H4'], '');
    expect(cells['I4'], '');
    expect(cells['J4'], '');
    expect(cells['K4'], '');
    expect(cells['L4'], '100.5');
    expect(cells['M4'], '108');
    expect(cells['N4'], '7.5');
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
        devices: const [hitachi],
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
      expect('合计时间（时）'.allMatches(sheet), hasLength(2));
      expect(
        TimingWorklogExcelWriter.signatureText.allMatches(sheet),
        hasLength(2),
      );
      expect(cells['N24'], '20');
      expect(cells['N49'], '21');
      expect(sheet, contains('<rowBreaks count="1" manualBreakCount="1">'));
      expect(
        sheet,
        contains('<pageSetup paperSize="9" orientation="landscape"'),
      );
      expect(workbook, contains('_xlnm.Print_Area'));
      expect(workbook, contains('\$A\$1:\$P\$50'));
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
      devices: const [hitachi],
    );

    expect(outcome.ok, isTrue);
    expect(presenter.calls, 1);
    expect(presenter.fileName, '挖机工时打卡汇总_李洋_天眉乐_20260526-20260526.xlsx');
    expect(await File(presenter.filePath!).exists(), isTrue);
  });

  test('export use case filters normal project records', () async {
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
          projectId: 'project-a',
          startDate: 20260526,
          startMeter: 20,
          endMeter: 23,
          hours: 3,
        ),
      ],
      devices: const [hitachi],
    );
    final cells = _cells(_sheetXmlFromFile(presenter.filePath!));

    expect(outcome.ok, isTrue);
    expect(presenter.fileName, '挖机工时打卡汇总_李洋_天眉乐_20260521-20260526.xlsx');
    expect(cells['A4'], '1');
    expect(cells['B4'], '2026.05.21');
    expect(cells['L4'], '10');
    expect(cells['M4'], '12');
    expect(cells['N4'], '2');
    expect(cells['A5'], '2');
    expect(cells['B5'], '2026.05.26');
    expect(cells['L5'], '20');
    expect(cells['M5'], '23');
    expect(cells['N5'], '3');
    expect(cells['B6'], '');
    expect(cells['N24'], '5');
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
      devices: const [hitachi],
    );
    final cells = _cells(_sheetXmlFromFile(presenter.filePath!));

    expect(outcome.ok, isTrue);
    expect(presenter.fileName, '挖机工时打卡汇总_李杰_合并2项目_20260312-20260601.xlsx');
    expect(cells['B4'], '2026.03.12');
    expect(cells['B5'], '2026.06.01');
    expect(cells['B6'], '');
    expect(cells['N24'], '6');
  });

  test('export use case reports empty and share failure friendly', () async {
    final presenter = _FakePresenter();
    final useCase = ExportTimingWorklogExcelUseCase(presenter: presenter);
    final empty = await useCase.execute(
      scope: TimingWorklogExportScope.singleProject(
        projectId: 'project-a',
        fileNamePart: '李洋 · 天眉乐',
      ),
      records: const [],
      devices: const [],
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
      devices: const [hitachi],
    );
    expect(result.ok, isFalse);
    expect(result.message, '分享面板打开失败，工时表已保留，可稍后重试');
    expect(dir.listSync().whereType<File>().single.path, endsWith('.xlsx'));
  });
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
