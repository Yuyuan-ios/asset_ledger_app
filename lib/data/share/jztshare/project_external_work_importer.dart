import '../../db/database.dart';
import '../../models/external_import_batch.dart';
import '../../models/external_work_record.dart';
import '../../repositories/external_import_repository.dart';
import '../../repositories/external_work_record_repository.dart';
import 'project_external_work_duplicate_checker.dart';
import 'project_external_work_import_preview.dart';
import 'project_external_work_import_result.dart';
import 'share_envelope_parser.dart';

class ProjectExternalWorkImporter {
  const ProjectExternalWorkImporter({
    ProjectExternalWorkDuplicateChecker duplicateChecker =
        const ProjectExternalWorkDuplicateChecker(),
  }) : _duplicateChecker = duplicateChecker;

  final ProjectExternalWorkDuplicateChecker _duplicateChecker;

  Future<ExternalWorkImportPreview> buildPreview(
    ParsedProjectExternalWorkShare parsed,
  ) {
    return _duplicateChecker.buildPreview(parsed);
  }

  Future<ProjectExternalWorkImportResult> importParsed(
    ParsedProjectExternalWorkShare parsed, {
    String? importedAt,
  }) async {
    final preview = await buildPreview(parsed);
    if (preview.duplicateSummary.hasBlockingDuplicates) {
      return ProjectExternalWorkImportResult.rejectedDuplicate(
        preview: preview,
      );
    }

    final now = importedAt ?? DateTime.now().toUtc().toIso8601String();
    await AppDatabase.inTransaction<void>((txn) async {
      await SqfliteExternalImportRepository.insertBatchWithExecutor(
        txn,
        _batchFromPreview(preview, now),
      );
      for (final line in preview.lines) {
        await SqfliteExternalWorkRecordRepository.insertRecordWithExecutor(
          txn,
          _recordFromPreviewLine(preview: preview, line: line, now: now),
        );
      }
    });

    return ProjectExternalWorkImportResult.imported(preview: preview);
  }

  static ExternalImportBatch _batchFromPreview(
    ExternalWorkImportPreview preview,
    String now,
  ) {
    return ExternalImportBatch(
      id: preview.shareId,
      sourceShareId: preview.shareId,
      sourceDisplayName: preview.senderName,
      recordCount: preview.recordCount,
      totalHoursMilli: preview.totalHoursMilli,
      totalAmountFen: preview.totalAmountFen,
      siteSummary: preview.siteSummary,
      importedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  static ExternalWorkRecord _recordFromPreviewLine({
    required ExternalWorkImportPreview preview,
    required ExternalWorkImportPreviewLine line,
    required String now,
  }) {
    final id = 'external:${preview.shareId}:${line.exportLineUuid}';
    if (line.amountIsAuthoritative) {
      // 富事实层：amountFen 来自真实 income_fen，原样写入，不重算。
      // 单价透传 line.source/localUnitPriceFen（可能为 null = 未知），
      // 绝不在导入端反推。
      return ExternalWorkRecord.imported(
        id: id,
        importBatchId: preview.shareId,
        sourceShareId: preview.shareId,
        sourceRecordUuid: line.exportLineUuid,
        sourceInstallationUuid: preview.sourceInstallationUuid,
        originFingerprint: line.originFingerprint,
        collaboratorName: preview.senderName,
        contactSnapshot: line.contactSnapshot,
        siteSnapshot: line.siteSnapshot,
        equipmentBrand: line.equipmentBrand,
        equipmentModel: line.equipmentModel,
        equipmentType: line.equipmentType,
        workDate: line.workDate,
        hoursMilli: line.hoursMilli,
        amountFen: line.amountFen,
        sourceUnitPriceFen: line.sourceUnitPriceFen,
        localUnitPriceFen: line.localUnitPriceFen,
        recordKind: line.recordKind,
        linkedProjectId: null,
        note: line.note,
        createdAt: now,
        updatedAt: now,
      );
    }
    // legacy export_lines 路径：单价必有，按 AmountPolicy 校验金额。
    final sourcePrice = line.sourceUnitPriceFen;
    if (sourcePrice == null) {
      throw StateError(
        'legacy export_lines path requires a non-null source unit price',
      );
    }
    return ExternalWorkRecord.create(
      id: id,
      importBatchId: preview.shareId,
      sourceShareId: preview.shareId,
      sourceRecordUuid: line.exportLineUuid,
      sourceInstallationUuid: preview.sourceInstallationUuid,
      originFingerprint: line.originFingerprint,
      collaboratorName: preview.senderName,
      contactSnapshot: line.contactSnapshot,
      siteSnapshot: line.siteSnapshot,
      equipmentBrand: line.equipmentBrand,
      equipmentModel: line.equipmentModel,
      equipmentType: line.equipmentType,
      workDate: line.workDate,
      hoursMilli: line.hoursMilli,
      sourceUnitPriceFen: sourcePrice,
      // legacy 路径恒为 hours（builder _tryBuildExportLine 过滤了 rent）。
      recordKind: ExternalWorkRecordKind.hours,
      linkedProjectId: null,
      note: line.note,
      createdAt: now,
      updatedAt: now,
    );
  }
}
