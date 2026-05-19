import 'dart:io';

import '../../../data/models/device.dart';
import '../../../data/models/timing_record.dart';
import '../../../data/repositories/timing_calculation_history_repository.dart';
import '../../../data/services/project_share_file_presenter.dart';
import '../../../data/share/jztshare/jztshare_export_directory.dart';
import '../../../data/share/jztshare/project_external_work_share_export_adapter.dart';
import '../../../data/share/jztshare/share_envelope.dart';

/// 视图层友好的导出结果（视图不直接接触 lib/data 类型/异常）。
class ProjectShareExportOutcome {
  const ProjectShareExportOutcome._({
    required this.ok,
    required this.message,
    this.fileName,
  });

  factory ProjectShareExportOutcome.success(String fileName) =>
      ProjectShareExportOutcome._(
        ok: true,
        message: '分享包已生成：$fileName',
        fileName: fileName,
      );

  factory ProjectShareExportOutcome.failure(String message) =>
      ProjectShareExportOutcome._(ok: false, message: message);

  final bool ok;
  final String message;
  final String? fileName;
}

/// 项目外协分享导出用例：承接视图层意图，组装数据并生成 .jztshare 文件。
/// 视图只调用本用例，不直接 import lib/data（架构约束）。
class ProjectShareExportUseCase {
  ProjectShareExportUseCase(
    this._calcHistoryRepository, {
    ProjectExternalWorkShareExportAdapter adapter =
        const ProjectExternalWorkShareExportAdapter(),
    Future<Directory> Function() directoryResolver =
        JztShareExportDirectory.resolve,
    ProjectShareFilePresenter sharePresenter =
        const SystemProjectShareFilePresenter(),
  }) : _adapter = adapter,
       _directoryResolver = directoryResolver,
       _sharePresenter = sharePresenter;

  final TimingCalculationHistoryRepository _calcHistoryRepository;
  final ProjectExternalWorkShareExportAdapter _adapter;
  final Future<Directory> Function() _directoryResolver;
  final ProjectShareFilePresenter _sharePresenter;

  /// 与 pubspec.yaml version 对齐；升级版本号时同步修改。
  static const String appVersion = '1.0.1+3';

  static const String shareSubject = '分享项目外协记录';

  // TODO(5H/落地页): 有正式下载链接后，在文案末尾追加下载地址；当前不伪造链接。
  static const String shareText =
      '我通过机账通给你分享了一个项目外协记录包。\n'
      '如果已安装机账通，请打开附件 .jztshare 导入。\n'
      '如果未安装，请先下载机账通，再打开该文件。';

  Future<ProjectShareExportOutcome> execute({
    required String projectId,
    required String projectKey,
    required String senderName,
    required List<TimingRecord> allRecords,
    required List<Device> allDevices,
    DateTime? now,
  }) async {
    try {
      final result = await _adapter.export(
        projectId: projectId,
        projectKey: projectKey,
        senderName: senderName,
        allRecords: allRecords,
        allDevices: allDevices,
        calcHistoryRepository: _calcHistoryRepository,
        producer: JztShareProducer(
          appName: '机账通',
          appVersion: appVersion,
          platform: Platform.operatingSystem,
        ),
        createdAt: now ?? DateTime.now(),
        directoryResolver: _directoryResolver,
      );

      final filePath = result.filePath;
      if (filePath == null) {
        // 正常路径下 exportToDirectory 必返回 filePath；防御兜底。
        return ProjectShareExportOutcome.success(result.fileName);
      }

      try {
        await _sharePresenter.share(
          filePath: filePath,
          fileName: result.fileName,
          text: shareText,
          subject: shareSubject,
        );
      } on ProjectShareSheetException catch (e) {
        // 文件已生成并保留在 jztshare_exports/，仅分享面板未打开。
        return ProjectShareExportOutcome.failure(e.message);
      } catch (_) {
        return ProjectShareExportOutcome.failure('分享面板打开失败，可稍后重试');
      }
      return ProjectShareExportOutcome.success(result.fileName);
    } on ProjectShareExportException catch (e) {
      return ProjectShareExportOutcome.failure(e.message);
    } catch (_) {
      return ProjectShareExportOutcome.failure('生成分享包失败');
    }
  }
}
