import 'project_external_work_import_preview.dart';

class ProjectExternalWorkImportException implements Exception {
  const ProjectExternalWorkImportException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ProjectExternalWorkImportException($code): $message';
}

class ProjectExternalWorkImportErrorCodes {
  const ProjectExternalWorkImportErrorCodes._();

  static const amountMismatch = 'amount_mismatch';
}

enum ProjectExternalWorkImportStatus { imported, rejectedDuplicate }

class ProjectExternalWorkImportResult {
  const ProjectExternalWorkImportResult({
    required this.status,
    required this.preview,
    required this.insertedRecordCount,
  });

  factory ProjectExternalWorkImportResult.imported({
    required ExternalWorkImportPreview preview,
  }) {
    return ProjectExternalWorkImportResult(
      status: ProjectExternalWorkImportStatus.imported,
      preview: preview,
      insertedRecordCount: preview.recordCount,
    );
  }

  factory ProjectExternalWorkImportResult.rejectedDuplicate({
    required ExternalWorkImportPreview preview,
  }) {
    return ProjectExternalWorkImportResult(
      status: ProjectExternalWorkImportStatus.rejectedDuplicate,
      preview: preview,
      insertedRecordCount: 0,
    );
  }

  final ProjectExternalWorkImportStatus status;
  final ExternalWorkImportPreview preview;
  final int insertedRecordCount;
}
