import 'dart:convert';
import 'dart:io';

import 'project_external_work_share_rich_payload.dart';
import 'share_envelope.dart';
import 'share_envelope_validator.dart';

/// 5C 导出结果。
///
/// 注意：[packageId] 来自 payload.shareId（=分享包/批次标识），
/// 不是本机项目 id；payload 内的 source_project_id 仅作来源追踪，
/// 导入端禁止复用为本机项目 id。
class ProjectExternalWorkShareExportResult {
  const ProjectExternalWorkShareExportResult({
    required this.content,
    required this.fileName,
    required this.packageId,
    required this.payloadSha256,
    required this.recordCount,
    required this.deviceCount,
    required this.totalIncomeFen,
    this.filePath,
  });

  /// 完整 .jzt 文件内容（合法 JSON envelope）。
  final String content;
  final String fileName;

  /// == payload.shareId（分享包标识，非本机项目 id）。
  final String packageId;
  final String payloadSha256;
  final int recordCount;
  final int deviceCount;
  final int totalIncomeFen;

  /// 写盘后才有；仅生成内容时为 null。
  final String? filePath;

  ProjectExternalWorkShareExportResult withFile({
    required String fileName,
    required String filePath,
  }) {
    return ProjectExternalWorkShareExportResult(
      content: content,
      fileName: fileName,
      packageId: packageId,
      payloadSha256: payloadSha256,
      recordCount: recordCount,
      deviceCount: deviceCount,
      totalIncomeFen: totalIncomeFen,
      filePath: filePath,
    );
  }
}

/// 把 5B 富 payload 包成合法 JSON envelope（对外 .jzt 文件），并写入指定目录。
///
/// - 复用既有 [JztShareEnvelope] 常量与 [JztShareEnvelopeValidator] 的
///   规范化 sha256，保证现有 parser/validator 能识别、且与 backup 包不混淆。
/// - 纯逻辑 + 注入式 IO（目录由调用方传入），不依赖 path_provider，
///   不接系统分享面板（5D）。
class ProjectExternalWorkShareExportService {
  const ProjectExternalWorkShareExportService();

  // 分享包对外文件扩展名统一为 .jzt；envelope/payload 结构不变。
  static const String fileExtension = '.jzt';

  /// 仅生成 envelope 内容，不写盘（纯函数，便于测试）。
  /// [createdAt] 由调用方注入以保证可测/确定。
  ProjectExternalWorkShareExportResult buildEnvelope({
    required ProjectExternalWorkShareRichPayload payload,
    required JztShareProducer producer,
    required DateTime createdAt,
  }) {
    final payloadMap = payload.toMap();
    final sha256 = JztShareEnvelopeValidator.payloadSha256(payloadMap);
    final createdAtIso = createdAt.toUtc().toIso8601String();

    final envelope = <String, Object?>{
      'magic': JztShareEnvelope.magicValue,
      'format_version': JztShareEnvelope.supportedFormatVersion,
      'package_type': JztShareEnvelope.projectExternalWorkShareType,
      'producer': {
        'app_name': producer.appName,
        'app_version': producer.appVersion,
        'platform': producer.platform,
      },
      'created_at': createdAtIso,
      'share_id': payload.shareId,
      'integrity': {
        'payload_encoding': JztShareEnvelope.jsonPayloadEncoding,
        'payload_sha256': sha256,
      },
      'payload': payloadMap,
    };

    return ProjectExternalWorkShareExportResult(
      content: jsonEncode(envelope),
      fileName: _buildFileName(payload.senderName, createdAt),
      packageId: payload.shareId,
      payloadSha256: sha256,
      recordCount: payload.summary.recordCount,
      deviceCount: payload.summary.deviceCount,
      totalIncomeFen: payload.summary.totalIncomeFen,
    );
  }

  /// 生成内容并写入 [directory]，返回带 filePath 的结果。
  Future<ProjectExternalWorkShareExportResult> exportToDirectory({
    required ProjectExternalWorkShareRichPayload payload,
    required JztShareProducer producer,
    required DateTime createdAt,
    required Directory directory,
  }) async {
    final result = buildEnvelope(
      payload: payload,
      producer: producer,
      createdAt: createdAt,
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    // 避免同名文件被静默覆盖：冲突时追加 _2 / _3 …，保留历史导出。
    final uniqueName = await _resolveNonCollidingName(
      directory,
      result.fileName,
    );
    final path = '${directory.path}${Platform.pathSeparator}$uniqueName';
    final file = File(path);
    await file.writeAsString(result.content, flush: true);
    return result.withFile(fileName: uniqueName, filePath: file.path);
  }

  static Future<String> _resolveNonCollidingName(
    Directory directory,
    String fileName,
  ) async {
    final stem = fileName.endsWith(fileExtension)
        ? fileName.substring(0, fileName.length - fileExtension.length)
        : fileName;
    var candidate = fileName;
    var seq = 1;
    while (await File(
      '${directory.path}${Platform.pathSeparator}$candidate',
    ).exists()) {
      seq += 1;
      candidate = '${stem}_$seq$fileExtension';
    }
    return candidate;
  }

  static String _buildFileName(String senderName, DateTime createdAt) {
    final base = _sanitizeBaseName(senderName);
    final d = createdAt.toUtc();
    final datePart =
        '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
    return '${base}_$datePart$fileExtension';
  }

  // 去掉路径分隔符与文件系统非法字符/控制字符；保留中英文与数字。
  static String _sanitizeBaseName(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'''[\\/:*?"<>|\x00-\x1F]'''), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final trimmed = cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
    return trimmed.isEmpty ? 'project_external_work_share' : trimmed;
  }
}
