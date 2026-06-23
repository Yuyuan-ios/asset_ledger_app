import '../../../../data/share/jztshare/jztshare_errors.dart';
import '../../../../data/share/jztshare/project_external_work_import_result.dart';
import '../../../../data/share/jztshare/project_external_work_importer.dart';
import '../../../../data/share/jztshare/share_envelope_parser.dart';
import 'external_work_import_preview_session.dart';

abstract class ExternalWorkImportPreviewPreparer {
  Future<ExternalWorkImportPreviewSession> execute(String content);
}

class ExternalWorkImportPreviewFailure implements Exception {
  const ExternalWorkImportPreviewFailure(this.code);

  final String code;

  @override
  String toString() => 'ExternalWorkImportPreviewFailure($code)';
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
      throw const ExternalWorkImportPreviewFailure('empty_content');
    }

    try {
      final parsed = _parser.parseProjectExternalWorkShare(trimmed);
      final preview = await _importer.buildPreview(parsed);
      return ExternalWorkImportPreviewSession(parsed: parsed, preview: preview);
    } on JztShareParseException catch (error) {
      throw ExternalWorkImportPreviewFailure(error.code);
    } on ProjectExternalWorkImportException catch (error) {
      throw ExternalWorkImportPreviewFailure(error.code);
    } on FormatException {
      throw const ExternalWorkImportPreviewFailure(
        JztShareErrorCodes.invalidJson,
      );
    }
  }
}
