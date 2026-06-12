import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/models/device.dart';
import '../../../data/models/external_import_batch.dart';
import '../../../data/models/external_work_record.dart';
import '../../../data/models/project_device_rate.dart';
import '../../../data/models/timing_record.dart';
import '../infrastructure/timing_worklog_excel_writer.dart';
import '../models/timing_worklog_report.dart';
import '../presentation/report_file_presenter.dart';
import '../../timing/state/timing_external_work_store.dart';
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

class TimingWorklogExportScope {
  TimingWorklogExportScope._({
    required Set<String>? projectIds,
    required Set<int> deviceIds,
    required this.startDate,
    required this.endDate,
    required this.includeExternalWork,
    required String fileNamePart,
  }) : projectIds = Set.unmodifiable(projectIds ?? const <String>{}),
       _filtersProject = projectIds != null,
       deviceIds = Set.unmodifiable(deviceIds),
       fileNamePart = _sanitizeFileNamePart(fileNamePart);

  factory TimingWorklogExportScope.singleProject({
    required String projectId,
    required String fileNamePart,
    Iterable<int> deviceIds = const [],
    int? startDate,
    int? endDate,
    bool includeExternalWork = false,
  }) {
    final normalizedProjectId = projectId.trim();
    return TimingWorklogExportScope._(
      projectIds: normalizedProjectId.isEmpty
          ? const <String>{}
          : <String>{normalizedProjectId},
      deviceIds: _normalizeDeviceIds(deviceIds),
      startDate: startDate,
      endDate: endDate,
      includeExternalWork: includeExternalWork,
      fileNamePart: fileNamePart,
    );
  }

  factory TimingWorklogExportScope.mergedProject({
    required Iterable<String> memberProjectIds,
    required String fileNamePart,
    Iterable<int> deviceIds = const [],
    int? startDate,
    int? endDate,
    bool includeExternalWork = false,
  }) {
    final ids = memberProjectIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && !id.startsWith('merge:'))
        .toSet();
    return TimingWorklogExportScope._(
      projectIds: ids,
      deviceIds: _normalizeDeviceIds(deviceIds),
      startDate: startDate,
      endDate: endDate,
      includeExternalWork: includeExternalWork,
      fileNamePart: fileNamePart,
    );
  }

  factory TimingWorklogExportScope.filtered({
    required String fileNamePart,
    Iterable<String> projectIds = const [],
    Iterable<int> deviceIds = const [],
    int? startDate,
    int? endDate,
    bool includeExternalWork = false,
  }) {
    final normalizedProjectIds = projectIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && !id.startsWith('merge:'))
        .toSet();
    return TimingWorklogExportScope._(
      projectIds: normalizedProjectIds.isEmpty ? null : normalizedProjectIds,
      deviceIds: _normalizeDeviceIds(deviceIds),
      startDate: startDate,
      endDate: endDate,
      includeExternalWork: includeExternalWork,
      fileNamePart: fileNamePart,
    );
  }

  final Set<String> projectIds;
  final bool _filtersProject;
  final Set<int> deviceIds;
  final int? startDate;
  final int? endDate;
  final bool includeExternalWork;
  final String fileNamePart;

  bool includes(TimingRecord record) {
    if (_filtersProject &&
        !projectIds.contains(record.effectiveProjectId.trim())) {
      return false;
    }
    if (deviceIds.isNotEmpty && !deviceIds.contains(record.deviceId)) {
      return false;
    }
    return _containsDate(record.startDate);
  }

  bool includesExternal(TimingExternalWorkRecordItem item) {
    if (!includeExternalWork) return false;
    if (deviceIds.isNotEmpty) return false;
    final record = item.record;
    if (record.status != ExternalWorkRecordStatus.active) return false;
    if (item.batch?.status != ExternalImportBatchStatus.active) return false;
    final linkedProjectId = record.linkedProjectId?.trim() ?? '';
    if (linkedProjectId.isEmpty) return false;
    if (_filtersProject && !projectIds.contains(linkedProjectId)) {
      return false;
    }
    return _containsDate(record.workDate);
  }

  bool _containsDate(int ymd) {
    final start = startDate;
    if (start != null && ymd < start) return false;
    final end = endDate;
    if (end != null && ymd > end) return false;
    return true;
  }

  static String _sanitizeFileNamePart(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'\s*[·•]\s*'), '_')
        .replaceAll(RegExp(r'''[\\/:*?"<>|\x00-\x1F]'''), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? '项目' : cleaned;
  }

  static Set<int> _normalizeDeviceIds(Iterable<int> ids) {
    return ids.where((id) => id > 0).toSet();
  }
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
    required TimingWorklogExportScope scope,
    required List<TimingRecord> records,
    required List<Device> devices,
    List<ProjectDeviceRate> rates = const [],
    List<TimingExternalWorkRecordItem> externalWorkItems = const [],
  }) async {
    final scopedRecords = records.where(scope.includes).toList(growable: false);
    final scopedExternalWorkItems = externalWorkItems
        .where(scope.includesExternal)
        .toList(growable: false);
    if (scopedRecords.isEmpty && scopedExternalWorkItems.isEmpty) {
      return ExportTimingWorklogExcelOutcome.failure('该项目暂无可导出的工时记录');
    }
    try {
      final report = _reportBuilder.execute(
        records: scopedRecords,
        devices: devices,
        rates: rates,
        externalWorkItems: scopedExternalWorkItems,
      );
      if (report.isEmpty) {
        return ExportTimingWorklogExcelOutcome.failure('该项目暂无可导出的工时记录');
      }
      final bytes = _writer.write(report);
      final directory = await _directoryResolver();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final fileName = await _resolveFileName(
        directory,
        report,
        scope.fileNamePart,
      );
      final file = File(p.join(directory.path, fileName));
      await file.writeAsBytes(bytes, flush: true);

      try {
        await _presenter.share(
          filePath: file.path,
          fileName: fileName,
          text: '项目对账明细已生成，请查看附件 Excel 文件。',
          subject: '项目对账明细',
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
    String fileNamePart,
  ) async {
    final dateRange =
        '${_compactDate(report.startDate)}-${_compactDate(report.endDate)}';
    final stem = '项目对账明细_${fileNamePart}_$dateRange';
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
