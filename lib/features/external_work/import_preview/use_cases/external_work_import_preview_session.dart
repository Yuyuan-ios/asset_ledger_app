import '../../../../data/share/jztshare/project_external_work_import_preview.dart';
import '../../../../data/share/jztshare/share_envelope_parser.dart';

class ExternalWorkImportPreviewSession {
  const ExternalWorkImportPreviewSession({
    required this.parsed,
    required this.preview,
  });

  final ParsedProjectExternalWorkShare parsed;
  final ExternalWorkImportPreview preview;
}
