import 'project_external_work_share_line.dart';

enum ExternalWorkDuplicateStatus {
  none,
  sameShareAlreadyImported,
  sameSourceRecordAlreadyImported,
  sameOriginFingerprintAlreadyImported,
}

class ExternalWorkImportPreview {
  const ExternalWorkImportPreview({
    required this.shareId,
    required this.senderName,
    required this.sourceInstallationUuid,
    required this.recordCount,
    required this.totalHoursMilli,
    required this.totalAmountFen,
    required this.siteSummary,
    required this.duplicateSummary,
    required this.lines,
  });

  final String shareId;
  final String senderName;
  final String sourceInstallationUuid;
  final int recordCount;
  final int totalHoursMilli;
  final int totalAmountFen;
  final String siteSummary;
  final ExternalWorkDuplicateSummary duplicateSummary;
  final List<ExternalWorkImportPreviewLine> lines;
}

class ExternalWorkImportPreviewLine {
  const ExternalWorkImportPreviewLine({
    required this.exportLineUuid,
    required this.originFingerprint,
    required this.contactSnapshot,
    required this.siteSnapshot,
    this.equipmentBrand,
    this.equipmentModel,
    this.equipmentType,
    required this.workDate,
    required this.hoursMilli,
    required this.sourceUnitPriceFen,
    required this.localUnitPriceFen,
    required this.amountFen,
    required this.duplicateStatus,
    this.note,
  });

  factory ExternalWorkImportPreviewLine.fromShareLine({
    required ProjectExternalWorkShareLine line,
    required ExternalWorkDuplicateStatus duplicateStatus,
  }) {
    return ExternalWorkImportPreviewLine(
      exportLineUuid: line.exportLineUuid,
      originFingerprint: line.originFingerprint,
      contactSnapshot: line.contactSnapshot,
      siteSnapshot: line.siteSnapshot,
      equipmentBrand: line.equipmentBrand,
      equipmentModel: line.equipmentModel,
      equipmentType: line.equipmentType,
      workDate: line.workDate,
      hoursMilli: line.hoursMilli,
      sourceUnitPriceFen: line.sourceUnitPriceFen,
      localUnitPriceFen: line.sourceUnitPriceFen,
      amountFen: line.amountFen,
      duplicateStatus: duplicateStatus,
      note: line.note,
    );
  }

  final String exportLineUuid;
  final String originFingerprint;
  final String contactSnapshot;
  final String siteSnapshot;
  final String? equipmentBrand;
  final String? equipmentModel;
  final String? equipmentType;
  final int workDate;
  final int hoursMilli;
  final int sourceUnitPriceFen;
  final int localUnitPriceFen;
  final int amountFen;
  final ExternalWorkDuplicateStatus duplicateStatus;
  final String? note;
}

class ExternalWorkDuplicateSummary {
  const ExternalWorkDuplicateSummary({
    required this.sameShareAlreadyImported,
    required this.sameSourceRecordCount,
    required this.sameOriginFingerprintCount,
  });

  final bool sameShareAlreadyImported;
  final int sameSourceRecordCount;
  final int sameOriginFingerprintCount;

  bool get hasBlockingDuplicates {
    return sameShareAlreadyImported || sameSourceRecordCount > 0;
  }

  bool get hasSuspiciousDuplicates {
    return sameOriginFingerprintCount > 0;
  }
}
