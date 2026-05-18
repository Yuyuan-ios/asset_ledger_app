import '../../models/external_work_parse.dart';
import 'jztshare_errors.dart';
import 'project_external_work_share_line.dart';

class ProjectExternalWorkSharePayload {
  const ProjectExternalWorkSharePayload({
    required this.shareId,
    required this.senderName,
    required this.sourceInstallationUuid,
    required this.exportLines,
  });

  static const maxExportLines = 1000;

  final String shareId;
  final String senderName;
  final String sourceInstallationUuid;
  final List<ProjectExternalWorkShareLine> exportLines;

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

    try {
      return ProjectExternalWorkSharePayload(
        shareId: reader.requiredString('share_id'),
        senderName: reader.requiredString('sender_name'),
        sourceInstallationUuid: reader.requiredString(
          'source_installation_uuid',
        ),
        exportLines: rawLines.map(_parseLine).toList(growable: false),
      );
    } on ExternalDataParseException catch (error) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidPayload,
        error.message,
        map,
      );
    }
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
