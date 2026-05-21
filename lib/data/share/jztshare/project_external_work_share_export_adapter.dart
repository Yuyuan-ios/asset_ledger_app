import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../models/account_payment.dart';
import '../../models/device.dart';
import '../../models/project_device_rate.dart';
import '../../models/timing_calculation_history.dart';
import '../../models/timing_record.dart';
import '../../repositories/timing_calculation_history_repository.dart';
import 'project_external_work_share_builder.dart';
import 'project_external_work_share_export_service.dart';
import 'share_envelope.dart';

/// 项目外协分享导出的业务异常（给 UI 展示友好文案）。
class ProjectShareExportException implements Exception {
  const ProjectShareExportException(this.code, this.message);

  static const String noRecords = 'no_records';
  static const String invalidRecords = 'invalid_records';

  final String code;
  final String message;

  @override
  String toString() => 'ProjectShareExportException($code): $message';
}

/// 把“当前项目”的计时数据组装成 .jzt 分享文件的协调层。
///
/// 集中放置：项目记录过滤、deviceMap/calcHistoryMap 组装、id 派生、
/// builder + export service 调用、错误归一。Widget 不做这些。
///
/// 注意：shareId / sourceInstallationUuid 仅作来源追踪标识，
/// 不是本机真实 project_id / 设备 id，导入端不得复用为本机 id。
class ProjectExternalWorkShareExportAdapter {
  const ProjectExternalWorkShareExportAdapter({
    ProjectExternalWorkShareBuilder builder =
        const ProjectExternalWorkShareBuilder(),
    ProjectExternalWorkShareExportService exportService =
        const ProjectExternalWorkShareExportService(),
  }) : _builder = builder,
       _exportService = exportService;

  final ProjectExternalWorkShareBuilder _builder;
  final ProjectExternalWorkShareExportService _exportService;

  /// [projectId] 应为详情页的 effectiveProjectId；[projectKey] 为 legacy key。
  /// [allRecords]/[allDevices] 是全量数据，方法内只挑当前项目。
  Future<ProjectExternalWorkShareExportResult> export({
    required String projectId,
    required String projectKey,
    required String senderName,
    required List<TimingRecord> allRecords,
    required List<Device> allDevices,
    required TimingCalculationHistoryRepository calcHistoryRepository,
    required JztShareProducer producer,
    required DateTime createdAt,
    required Future<Directory> Function() directoryResolver,
    List<ProjectDeviceRate> allRates = const [],
    List<AccountPayment> allPayments = const [],
  }) async {
    final trimmedSender = senderName.trim();
    if (trimmedSender.isEmpty) {
      throw const ProjectShareExportException(
        ProjectShareExportException.invalidRecords,
        '请先填写分享人姓名或包名',
      );
    }
    final trimmedProjectId = projectId.trim();

    // 有明确 projectId：仅按 effectiveProjectId 严格匹配，不再 fallback 到
    // legacyProjectKey——否则同联系人同地址但不同 projectId 的旧项目记录
    // 会混入候选，再被 builder 跨项目防御拦成“分享数据异常”。
    // 仅当无明确 projectId 的 legacy 场景，才用 legacyProjectKey 兼容匹配。
    bool belongsToProject(TimingRecord r) {
      if (trimmedProjectId.isNotEmpty) {
        return r.effectiveProjectId == trimmedProjectId;
      }
      return r.legacyProjectKey == projectKey;
    }

    final projectRecords = allRecords
        .where(belongsToProject)
        .toList(growable: false);
    if (projectRecords.isEmpty) {
      throw const ProjectShareExportException(
        ProjectShareExportException.noRecords,
        '当前项目暂无可分享记录',
      );
    }

    final deviceMap = <int, Device>{
      for (final d in allDevices)
        if (d.id != null) d.id!: d,
    };

    final calcHistoryMap = <int, List<TimingCalculationHistory>>{};
    for (final record in projectRecords) {
      final id = record.id;
      if (id == null) continue;
      calcHistoryMap[id] = await calcHistoryRepository.findByTimingRecordId(id);
    }

    final effectiveProjectId = trimmedProjectId.isNotEmpty
        ? trimmedProjectId
        : projectRecords.first.effectiveProjectId;

    try {
      final payload = _builder.build(
        shareId: _shareId(effectiveProjectId, trimmedSender, createdAt),
        senderName: trimmedSender,
        sourceInstallationUuid: _installationUuid(effectiveProjectId),
        records: projectRecords,
        deviceMap: deviceMap,
        calcHistoryMap: calcHistoryMap,
        projectDeviceRates: allRates,
        expectedProjectId: effectiveProjectId,
        projectReceivedFen: _projectReceivedFen(
          projectId: effectiveProjectId,
          payments: allPayments,
        ),
      );
      return _exportService.exportToDirectory(
        payload: payload,
        producer: producer,
        createdAt: createdAt,
        directory: await directoryResolver(),
      );
    } on ArgumentError catch (e) {
      throw ProjectShareExportException(
        ProjectShareExportException.invalidRecords,
        '分享数据异常：${e.message ?? e}',
      );
    }
  }

  // 来源追踪标识（非本机真实 id）：
  // - shareId：每次导出唯一（含时间戳），用于导入端防重复。
  // - installationUuid：按项目稳定，仅作来源归属展示/追踪。
  static String _shareId(
    String projectId,
    String senderName,
    DateTime createdAt,
  ) {
    final seed =
        '$projectId|$senderName|${createdAt.toUtc().microsecondsSinceEpoch}';
    return 'pews-${_shortHash(seed, 24)}';
  }

  static String _installationUuid(String projectId) {
    return 'inst-${_shortHash('project:$projectId', 16)}';
  }

  static int _projectReceivedFen({
    required String projectId,
    required List<AccountPayment> payments,
  }) {
    return payments.fold<int>(0, (sum, payment) {
      if (payment.effectiveProjectId != projectId) return sum;
      return sum + payment.amountFen;
    });
  }

  static String _shortHash(String input, int length) {
    final hex = sha256.convert(utf8.encode(input)).toString();
    return hex.substring(0, length);
  }
}
