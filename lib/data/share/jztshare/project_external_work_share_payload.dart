import '../../models/external_work_parse.dart';
import 'jztshare_errors.dart';
import 'project_external_work_share_line.dart';
import 'project_external_work_share_rich_payload.dart';

/// 导入端 payload 模型。
///
/// 加法式升级（6+）：在保留 legacy `export_lines[]` 的同时，可选解析富事实层
/// `records[]` / `project_snapshot` / `devices[]` / `summary`。
/// 当 `records[]` 非空时导入端应优先消费 rich 记录（见 hasRichRecords），
/// 否则 fallback 到 legacy `export_lines[]`。legacy payload
/// 不含富键，richRecords 为 null，行为与升级前一致。
class ProjectExternalWorkSharePayload {
  const ProjectExternalWorkSharePayload({
    required this.shareId,
    required this.senderName,
    required this.sourceInstallationUuid,
    required this.exportLines,
    this.richRecords,
    this.projectSnapshot,
    this.devices = const [],
    this.summary,
  });

  static const maxExportLines = 1000;
  static const maxRichRecords = 5000;

  final String shareId;
  final String senderName;
  final String sourceInstallationUuid;
  final List<ProjectExternalWorkShareLine> exportLines;

  /// 富事实层记录；payload 无 `records[]` 或为空时为 null。
  final List<ProjectExternalWorkShareRecord>? richRecords;

  /// 富 records 的来源项目快照（contact/site 等）；rich 路径必有。
  final ProjectExternalWorkShareProjectSnapshot? projectSnapshot;

  /// 设备快照，按 source_device_id 供 rich 记录映射设备品牌/型号/类型。
  final List<ProjectExternalWorkShareDeviceSnapshot> devices;

  /// 导出端聚合摘要；导入端以 records 计算值为准，summary 仅作参考。
  final ProjectExternalWorkShareSummary? summary;

  /// 是否存在可消费的富事实层记录。
  bool get hasRichRecords => richRecords != null && richRecords!.isNotEmpty;

  Map<int, ProjectExternalWorkShareDeviceSnapshot> get deviceById {
    return {for (final device in devices) device.sourceDeviceId: device};
  }

  static ProjectExternalWorkSharePayload fromMap(Map<String, Object?> map) {
    final reader = ExternalFieldReader(map);
    final rawLines = map['export_lines'];
    if (rawLines is! List<Object?>) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidExportLines,
        'payload.export_lines must be an array',
        map,
      );
    }
    if (rawLines.length > maxExportLines) {
      throw JztShareParseException(
        JztShareErrorCodes.exportLinesTooMany,
        'payload.export_lines exceeds $maxExportLines items',
        map,
      );
    }

    final richRecords = _parseRichRecords(map);
    final projectSnapshot = _parseProjectSnapshot(map, richRecords);
    final devices = _parseDevices(map);
    final summary = _parseSummary(map);

    try {
      return ProjectExternalWorkSharePayload(
        shareId: reader.requiredString('share_id'),
        senderName: reader.requiredString('sender_name'),
        sourceInstallationUuid: reader.requiredString(
          'source_installation_uuid',
        ),
        exportLines: rawLines.map(_parseLine).toList(growable: false),
        richRecords: richRecords,
        projectSnapshot: projectSnapshot,
        devices: devices,
        summary: summary,
      );
    } on ExternalDataParseException catch (error) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidPayload,
        error.message,
        map,
      );
    }
  }

  static List<ProjectExternalWorkShareRecord>? _parseRichRecords(
    Map<String, Object?> map,
  ) {
    final raw = map['records'];
    if (raw == null) return null;
    if (raw is! List<Object?>) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidPayload,
        'payload.records must be an array',
        map,
      );
    }
    if (raw.isEmpty) return null;
    if (raw.length > maxRichRecords) {
      throw JztShareParseException(
        JztShareErrorCodes.exportLinesTooMany,
        'payload.records exceeds $maxRichRecords items',
        map,
      );
    }
    return raw
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw JztShareParseException(
              JztShareErrorCodes.invalidPayload,
              'records item must be an object',
              item,
            );
          }
          return ProjectExternalWorkShareRecord.fromMap(item);
        })
        .toList(growable: false);
  }

  static ProjectExternalWorkShareProjectSnapshot? _parseProjectSnapshot(
    Map<String, Object?> map,
    List<ProjectExternalWorkShareRecord>? richRecords,
  ) {
    final raw = map['project_snapshot'];
    if (raw == null) {
      if (richRecords != null) {
        throw JztShareParseException(
          JztShareErrorCodes.invalidPayload,
          'payload.project_snapshot is required when records[] is present',
          map,
        );
      }
      return null;
    }
    if (raw is! Map<String, Object?>) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidPayload,
        'payload.project_snapshot must be an object',
        raw,
      );
    }
    return ProjectExternalWorkShareProjectSnapshot.fromMap(raw);
  }

  static List<ProjectExternalWorkShareDeviceSnapshot> _parseDevices(
    Map<String, Object?> map,
  ) {
    final raw = map['devices'];
    if (raw == null) return const [];
    if (raw is! List<Object?>) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidPayload,
        'payload.devices must be an array',
        raw,
      );
    }
    return raw
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw JztShareParseException(
              JztShareErrorCodes.invalidPayload,
              'devices item must be an object',
              item,
            );
          }
          return ProjectExternalWorkShareDeviceSnapshot.fromMap(item);
        })
        .toList(growable: false);
  }

  static ProjectExternalWorkShareSummary? _parseSummary(
    Map<String, Object?> map,
  ) {
    final raw = map['summary'];
    if (raw == null) return null;
    if (raw is! Map<String, Object?>) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidPayload,
        'payload.summary must be an object',
        raw,
      );
    }
    return ProjectExternalWorkShareSummary.fromMap(raw);
  }

  static ProjectExternalWorkShareLine _parseLine(Object? rawLine) {
    if (rawLine is! Map<String, Object?>) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidLine,
        'export_lines item must be an object',
        rawLine,
      );
    }
    return ProjectExternalWorkShareLine.fromMap(rawLine);
  }
}
