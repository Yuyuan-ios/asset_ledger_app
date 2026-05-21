import '../../models/external_work_record.dart';
import 'project_external_work_share_line.dart';
import 'project_external_work_share_rich_payload.dart';

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
    this.isRich = false,
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

  /// 本预览基于富事实层 `records[]` 构建（true），还是 legacy
  /// `export_lines[]`（false）。importer 据此决定金额来源。
  final bool isRich;
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
    this.recordKind = ExternalWorkRecordKind.hours,
    this.note,
    this.amountIsAuthoritative = false,
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
      // legacy export_lines 路径只产出 hours 行（builder _tryBuildExportLine
      // 已过滤 rent），这里固定为 hours。
      recordKind: ExternalWorkRecordKind.hours,
      note: line.note,
    );
  }

  /// 富事实层记录 → 预览行。金额取真实 `income_fen`（authoritative），
  /// 不按 hours×单价重算；单价透传 `source_unit_price_fen`，null 即未知，
  /// 绝不伪造为 0。设备快照缺失时 equipment* 留空，不崩溃。
  factory ExternalWorkImportPreviewLine.fromRichRecord({
    required ProjectExternalWorkShareRecord record,
    required ProjectExternalWorkShareProjectSnapshot projectSnapshot,
    ProjectExternalWorkShareDeviceSnapshot? device,
    required ExternalWorkDuplicateStatus duplicateStatus,
  }) {
    return ExternalWorkImportPreviewLine(
      exportLineUuid: record.sourceRecordUuid,
      originFingerprint: record.originFingerprint,
      contactSnapshot: projectSnapshot.contactSnapshot,
      siteSnapshot: projectSnapshot.siteSnapshot,
      equipmentBrand: device?.brand,
      equipmentModel: device?.model,
      equipmentType: device?.type,
      workDate: record.workDate,
      hoursMilli: record.hoursMilli,
      sourceUnitPriceFen: record.sourceUnitPriceFen,
      localUnitPriceFen: record.sourceUnitPriceFen,
      amountFen: record.incomeFen,
      duplicateStatus: duplicateStatus,
      recordKind: externalWorkRecordKindFromName(record.type),
      note: null,
      amountIsAuthoritative: true,
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

  /// 单价（分）。null 代表未知（rent / 人工覆写金额 / 设备缺失），
  /// 0 代表真实单价为 0。两者不可互换。
  final int? sourceUnitPriceFen;
  final int? localUnitPriceFen;
  final int amountFen;
  final ExternalWorkDuplicateStatus duplicateStatus;
  final ExternalWorkRecordKind recordKind;
  final String? note;

  /// true 表示 amountFen 来自真实来源金额（rich `income_fen`），
  /// importer 必须原样写入，禁止按 AmountPolicy 重算。
  final bool amountIsAuthoritative;
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
