import '../../../../data/share/jztshare/jztshare_errors.dart';
import '../../../../data/share/jztshare/project_external_work_import_result.dart';
import '../../../../data/share/jztshare/project_external_work_importer.dart';
import '../../../../data/share/jztshare/share_envelope_parser.dart';
import 'external_work_import_preview_session.dart';

abstract class ExternalWorkImportPreviewPreparer {
  Future<ExternalWorkImportPreviewSession> execute(String content);
}

class ExternalWorkImportPreviewFailure implements Exception {
  const ExternalWorkImportPreviewFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ExternalWorkImportPreviewFailure($code): $message';
}

class PrepareExternalWorkImportPreviewUseCase
    implements ExternalWorkImportPreviewPreparer {
  const PrepareExternalWorkImportPreviewUseCase({
    JztShareEnvelopeParser parser = const JztShareEnvelopeParser(),
    ProjectExternalWorkImporter importer = const ProjectExternalWorkImporter(),
  }) : _parser = parser,
       _importer = importer;

  final JztShareEnvelopeParser _parser;
  final ProjectExternalWorkImporter _importer;

  @override
  Future<ExternalWorkImportPreviewSession> execute(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const ExternalWorkImportPreviewFailure(
        'empty_content',
        '请先选择或粘贴 .jztshare 内容',
      );
    }

    try {
      final parsed = _parser.parseProjectExternalWorkShare(trimmed);
      final preview = await _importer.buildPreview(parsed);
      return ExternalWorkImportPreviewSession(parsed: parsed, preview: preview);
    } on JztShareParseException catch (error) {
      throw ExternalWorkImportPreviewFailure(
        error.code,
        _messageForJztShareCode(error.code),
      );
    } on ProjectExternalWorkImportException catch (error) {
      throw ExternalWorkImportPreviewFailure(error.code, error.message);
    } on FormatException {
      throw const ExternalWorkImportPreviewFailure(
        JztShareErrorCodes.invalidJson,
        '分享包不是有效的 JSON 内容',
      );
    }
  }

  static String _messageForJztShareCode(String code) {
    switch (code) {
      case JztShareErrorCodes.invalidJson:
        return '分享包不是有效的 JSON 内容';
      case JztShareErrorCodes.missingMagic:
      case JztShareErrorCodes.invalidMagic:
        return '这不是有效的机账通分享包';
      case JztShareErrorCodes.missingFormatVersion:
      case JztShareErrorCodes.unsupportedFormatVersion:
        return '分享包版本暂不支持';
      case JztShareErrorCodes.missingPackageType:
      case JztShareErrorCodes.unsupportedPackageType:
        return '暂不支持这种分享包';
      case JztShareErrorCodes.missingPayloadSha256:
      case JztShareErrorCodes.invalidPayloadSha256:
        return '分享包完整性信息不完整';
      case JztShareErrorCodes.payloadHashMismatch:
        return '分享包内容校验失败，请重新获取分享包';
      case JztShareErrorCodes.missingPayload:
      case JztShareErrorCodes.invalidExportLines:
      case JztShareErrorCodes.exportLinesTooMany:
      case JztShareErrorCodes.invalidLine:
      case JztShareErrorCodes.invalidPayload:
        return '分享包记录内容不完整或格式异常';
      case JztShareErrorCodes.invalidProducer:
      case JztShareErrorCodes.invalidIntegrity:
      case JztShareErrorCodes.unsupportedPayloadEncoding:
        return '分享包基础信息不完整或格式异常';
      default:
        return '分享包无法解析';
    }
  }
}
