import '../../../../data/share/jztshare/jztshare_errors.dart';
import '../../../../data/share/jztshare/project_external_work_import_preview.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../use_cases/pick_external_work_share_file_use_case.dart';
import '../use_cases/prepare_external_work_import_preview_use_case.dart';

class ExternalWorkImportPreviewCopy {
  const ExternalWorkImportPreviewCopy({required this.l10n});

  final AppLocalizations l10n;

  String pickErrorMessage(PickShareFileError error) {
    switch (error.code) {
      case PickShareFileErrorCode.invalidType:
        return l10n.externalWorkPickInvalidType;
      case PickShareFileErrorCode.readFailure:
        return l10n.externalWorkPickReadFailure;
      case PickShareFileErrorCode.fileTooLarge:
        return l10n.externalWorkPickFileTooLarge;
    }
  }

  String prepareFailureMessage(ExternalWorkImportPreviewFailure error) {
    switch (error.code) {
      case 'empty_content':
        return l10n.externalWorkImportPreviewEmptyContent;
      case JztShareErrorCodes.invalidJson:
        return l10n.externalWorkImportPreviewInvalidJson;
      case JztShareErrorCodes.missingMagic:
      case JztShareErrorCodes.invalidMagic:
        return l10n.externalWorkImportPreviewInvalidPackage;
      case JztShareErrorCodes.missingFormatVersion:
      case JztShareErrorCodes.unsupportedFormatVersion:
        return l10n.externalWorkImportPreviewUnsupportedVersion;
      case JztShareErrorCodes.missingPackageType:
      case JztShareErrorCodes.unsupportedPackageType:
        return l10n.externalWorkImportPreviewUnsupportedPackage;
      case JztShareErrorCodes.missingPayloadSha256:
      case JztShareErrorCodes.invalidPayloadSha256:
        return l10n.externalWorkImportPreviewIncompleteIntegrity;
      case JztShareErrorCodes.payloadHashMismatch:
        return l10n.externalWorkImportPreviewHashMismatch;
      case JztShareErrorCodes.missingPayload:
      case JztShareErrorCodes.invalidExportLines:
      case JztShareErrorCodes.exportLinesTooMany:
      case JztShareErrorCodes.invalidLine:
      case JztShareErrorCodes.invalidPayload:
        return l10n.externalWorkImportPreviewInvalidRecords;
      case JztShareErrorCodes.invalidProducer:
      case JztShareErrorCodes.invalidIntegrity:
      case JztShareErrorCodes.unsupportedPayloadEncoding:
        return l10n.externalWorkImportPreviewInvalidBaseInfo;
      default:
        return l10n.externalWorkImportPreviewParseFailure;
    }
  }

  String importFailureMessage(ExternalWorkImportPreviewFailure error) {
    switch (error.code) {
      case 'duplicate_rejected':
        return l10n.externalWorkImportPreviewDuplicateRejected;
      default:
        return l10n.externalWorkImportPreviewGenericImportFailure;
    }
  }

  String duplicateStatusLabel(ExternalWorkDuplicateStatus status) {
    switch (status) {
      case ExternalWorkDuplicateStatus.none:
        return l10n.externalWorkImportPreviewStatusImportable;
      case ExternalWorkDuplicateStatus.sameShareAlreadyImported:
        return l10n.externalWorkImportPreviewStatusImported;
      case ExternalWorkDuplicateStatus.sameSourceRecordAlreadyImported:
        return l10n.externalWorkImportPreviewStatusSameSource;
      case ExternalWorkDuplicateStatus.sameOriginFingerprintAlreadyImported:
        return l10n.externalWorkImportPreviewStatusSuspiciousDuplicate;
    }
  }
}
