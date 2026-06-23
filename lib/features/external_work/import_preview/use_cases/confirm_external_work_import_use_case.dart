import '../../../../data/share/jztshare/project_external_work_import_result.dart';
import '../../../../data/share/jztshare/project_external_work_importer.dart';
import 'external_work_import_preview_session.dart';
import 'prepare_external_work_import_preview_use_case.dart';

abstract class ExternalWorkImportConfirmer {
  Future<ProjectExternalWorkImportResult> execute(
    ExternalWorkImportPreviewSession session,
  );
}

class ConfirmExternalWorkImportUseCase implements ExternalWorkImportConfirmer {
  const ConfirmExternalWorkImportUseCase({
    ProjectExternalWorkImporter importer = const ProjectExternalWorkImporter(),
  }) : _importer = importer;

  final ProjectExternalWorkImporter _importer;

  @override
  Future<ProjectExternalWorkImportResult> execute(
    ExternalWorkImportPreviewSession session,
  ) async {
    final result = await _importer.importParsed(session.parsed);
    if (result.status == ProjectExternalWorkImportStatus.rejectedDuplicate) {
      throw const ExternalWorkImportPreviewFailure('duplicate_rejected');
    }
    return result;
  }
}
