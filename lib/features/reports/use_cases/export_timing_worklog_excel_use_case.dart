import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/models/device.dart';
import '../../../data/models/timing_record.dart';
import '../infrastructure/timing_worklog_excel_writer.dart';
import '../models/timing_worklog_report.dart';
import '../presentation/report_file_presenter.dart';
import 'build_timing_worklog_report_use_case.dart';

class ExportTimingWorklogExcelOutcome {
  const ExportTimingWorklogExcelOutcome._({
    required this.ok,
    required this.message,
    this.fileName,
    this.filePath,
  });

  factory ExportTimingWorklogExcelOutcome.shared({
    required String fileName,
    required String filePath,
  }) {
    return ExportTimingWorklogExcelOutcome._(
      ok: true,
      message: '工时表已生成，已打开分享面板',
      fileName: fileName,
      filePath: filePath,
    );
  }

  factory ExportTimingWorklogExcelOutcome.failure(String message) {
    return ExportTimingWorklogExcelOutcome._(ok: false, message: message);
  }

  final bool ok;
  final String message;
  final String? fileName;
  final String? filePath;
}

class ExportTimingWorklogExcelUseCase {
  ExportTimingWorklogExcelUseCase({
    BuildTimingWorklogReportUseCase reportBuilder =
        const BuildTimingWorklogReportUseCase(),
    TimingWorklogExcelWriter writer = const TimingWorklogExcelWriter(),
    Future<Directory> Function() directoryResolver =
        _defaultReportDirectoryResolver,
    ReportFilePresenter presenter = const SystemReportFilePresenter(),
  }) : _reportBuilder = reportBuilder,
       _writer = writer,
       _directoryResolver = directoryResolver,
       _presenter = presenter;

  final BuildTimingWorklogReportUseCase _reportBuilder;
  final TimingWorklogExcelWriter _writer;
  final Future<Directory> Function() _directoryResolver;
  final ReportFilePresenter _presenter;

  Future<ExportTimingWorklogExcelOutcome> execute({
    required List<TimingRecord> records,
    required List<Device> devices,
  }) async {
    if (records.isEmpty) {
      return ExportTimingWorklogExcelOutcome.failure('暂无可导出的计时记录');
    }
    try {
      final report = _reportBuilder.execute(records: records, devices: devices);
      if (report.isEmpty) {
        return ExportTimingWorklogExcelOutcome.failure('暂无可导出的计时记录');
      }
      final bytes = _writer.write(report);
      final directory = await _directoryResolver();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final fileName = await _resolveFileName(directory, report);
      final file = File(p.join(directory.path, fileName));
      await file.writeAsBytes(bytes, flush: true);

      try {
        await _presenter.share(
          filePath: file.path,
          fileName: fileName,
          text: '挖机工时打卡汇总已生成，请查看附件 Excel 文件。',
          subject: '挖机工时打卡汇总',
        );
      } catch (_) {
        return ExportTimingWorklogExcelOutcome.failure('分享面板打开失败，工时表已保留，可稍后重试');
      }
      return ExportTimingWorklogExcelOutcome.shared(
        fileName: fileName,
        filePath: file.path,
      );
    } catch (_) {
      return ExportTimingWorklogExcelOutcome.failure('生成工时表失败');
    }
  }

  static Future<String> _resolveFileName(
    Directory directory,
    TimingWorklogReport report,
  ) async {
    final dateRange =
        '${_compactDate(report.startDate)}-${_compactDate(report.endDate)}';
    final stem = '挖机工时打卡汇总_${report.deviceFileNamePart}_$dateRange';
    var candidate = '$stem.xlsx';
    var seq = 1;
    while (await File(p.join(directory.path, candidate)).exists()) {
      seq += 1;
      candidate = '${stem}_$seq.xlsx';
    }
    return candidate;
  }

  static String _compactDate(int ymd) => ymd.toString().padLeft(8, '0');
}

Future<Directory> _defaultReportDirectoryResolver() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  return Directory(p.join(documentsDir.path, 'report_exports'));
}
