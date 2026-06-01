import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/reports/infrastructure/timing_worklog_excel_writer.dart';
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
    brand: 'HITACHI',
    defaultUnitPrice: 100,
    baseMeterHours: 0,
  );

  test('report builder maps timing detail records and totals hours', () {
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
    expect(report.rows.first.deviceName, 'HITACHI 1#');
    expect(report.rows.first.startMeter, 100);
    expect(report.rows.first.endMeter, 108);
    expect(report.rows.first.hours, 8);
    expect(report.totalHours, 13.5);
    expect(report.deviceFileNamePart, 'HITACHI1号');
  });

  test(
    'excel writer creates xlsx with title headers totals signatures and page break',
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

      expect(writer.paginate(report), hasLength(2));
      expect(sheet, contains('挖机工时打卡汇总'));
      expect(sheet, contains('上午开始'));
      expect(sheet, contains('下午结束'));
      expect(sheet, contains('HITACHI 1#'));
      expect(sheet, contains(TimingWorklogExcelWriter.signatureText));
      expect(
        TimingWorklogExcelWriter.signatureText.allMatches(sheet),
        hasLength(2),
      );
      expect(sheet, contains('<rowBreaks count="1" manualBreakCount="1">'));
      expect(
        sheet,
        contains('<pageSetup paperSize="9" orientation="landscape"'),
      );
      expect(workbook, contains('_xlnm.Print_Area'));
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
      records: const [
        TimingRecord(
          id: 1,
          deviceId: 1,
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
      devices: const [hitachi],
    );

    expect(outcome.ok, isTrue);
    expect(presenter.calls, 1);
    expect(presenter.fileName, '挖机工时打卡汇总_HITACHI1号_20260526-20260526.xlsx');
    expect(await File(presenter.filePath!).exists(), isTrue);
  });

  test('export use case reports empty and share failure friendly', () async {
    final presenter = _FakePresenter();
    final useCase = ExportTimingWorklogExcelUseCase(presenter: presenter);
    final empty = await useCase.execute(records: const [], devices: const []);
    expect(empty.ok, isFalse);
    expect(empty.message, '暂无可导出的计时记录');
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
      records: const [
        TimingRecord(
          id: 1,
          deviceId: 1,
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
      devices: const [hitachi],
    );
    expect(result.ok, isFalse);
    expect(result.message, '分享面板打开失败，工时表已保留，可稍后重试');
    expect(dir.listSync().whereType<File>().single.path, endsWith('.xlsx'));
  });
}
