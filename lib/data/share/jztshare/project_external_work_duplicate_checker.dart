import 'package:sqflite/sqflite.dart';

import '../../db/database.dart';
import '../../models/external_work_record.dart';
import 'project_external_work_import_preview.dart';
import 'project_external_work_import_result.dart';
import 'project_external_work_share_line.dart';
import 'share_envelope_parser.dart';

class ProjectExternalWorkDuplicateChecker {
  const ProjectExternalWorkDuplicateChecker();

  Future<ExternalWorkImportPreview> buildPreview(
    ParsedProjectExternalWorkShare parsed,
  ) async {
    final db = await AppDatabase.database;
    return buildPreviewWithExecutor(db, parsed);
  }

  Future<ExternalWorkImportPreview> buildPreviewWithExecutor(
    DatabaseExecutor executor,
    ParsedProjectExternalWorkShare parsed,
  ) async {
    final payload = parsed.payload;
    final shareId = payload.shareId;
    final isRich = payload.hasRichRecords;
    final sameShareImported = await _exists(
      executor,
      'external_import_batches',
      where: 'source_share_id = ?',
      whereArgs: [shareId],
    );

    final previewLines = <ExternalWorkImportPreviewLine>[];
    var sameSourceRecordCount = 0;
    var sameOriginFingerprintCount = 0;

    Future<ExternalWorkDuplicateStatus> resolve({
      required String sourceRecordUuid,
      required String originFingerprint,
    }) async {
      final sameSourceRecord = await _exists(
        executor,
        'external_work_records',
        where: 'source_share_id = ? AND source_record_uuid = ?',
        whereArgs: [shareId, sourceRecordUuid],
      );
      final sameOriginFingerprint = await _exists(
        executor,
        'external_work_records',
        where: 'origin_fingerprint = ?',
        whereArgs: [originFingerprint],
      );
      if (sameSourceRecord) sameSourceRecordCount++;
      if (sameOriginFingerprint) sameOriginFingerprintCount++;
      return _resolveDuplicateStatus(
        sameShareImported: sameShareImported,
        sameSourceRecord: sameSourceRecord,
        sameOriginFingerprint: sameOriginFingerprint,
      );
    }

    if (isRich) {
      final projectSnapshot = payload.projectSnapshot!;
      final deviceById = payload.deviceById;
      final memberProjectById = payload.memberProjectById;
      for (final record in payload.richRecords!) {
        final status = await resolve(
          sourceRecordUuid: record.sourceRecordUuid,
          originFingerprint: record.originFingerprint,
        );
        previewLines.add(
          ExternalWorkImportPreviewLine.fromRichRecord(
            record: record,
            projectSnapshot: projectSnapshot,
            memberProject: memberProjectById[record.sourceProjectId],
            device: deviceById[record.sourceDeviceId],
            duplicateStatus: status,
          ),
        );
      }
    } else {
      for (final line in payload.exportLines) {
        _verifyAmount(line);
        final status = await resolve(
          sourceRecordUuid: line.exportLineUuid,
          originFingerprint: line.originFingerprint,
        );
        previewLines.add(
          ExternalWorkImportPreviewLine.fromShareLine(
            line: line,
            duplicateStatus: status,
          ),
        );
      }
    }

    return ExternalWorkImportPreview(
      shareId: shareId,
      senderName: payload.senderName,
      sourceInstallationUuid: payload.sourceInstallationUuid,
      recordCount: previewLines.length,
      totalHoursMilli: previewLines.fold<int>(
        0,
        (sum, line) => sum + line.hoursMilli,
      ),
      totalAmountFen: previewLines.fold<int>(
        0,
        (sum, line) => sum + line.amountFen,
      ),
      siteSummary: _buildSiteSummary(previewLines),
      duplicateSummary: ExternalWorkDuplicateSummary(
        sameShareAlreadyImported: sameShareImported,
        sameSourceRecordCount: sameSourceRecordCount,
        sameOriginFingerprintCount: sameOriginFingerprintCount,
      ),
      lines: List.unmodifiable(previewLines),
      isRich: isRich,
    );
  }

  static ExternalWorkDuplicateStatus _resolveDuplicateStatus({
    required bool sameShareImported,
    required bool sameSourceRecord,
    required bool sameOriginFingerprint,
  }) {
    if (sameShareImported) {
      return ExternalWorkDuplicateStatus.sameShareAlreadyImported;
    }
    if (sameSourceRecord) {
      return ExternalWorkDuplicateStatus.sameSourceRecordAlreadyImported;
    }
    if (sameOriginFingerprint) {
      return ExternalWorkDuplicateStatus.sameOriginFingerprintAlreadyImported;
    }
    return ExternalWorkDuplicateStatus.none;
  }

  static void _verifyAmount(ProjectExternalWorkShareLine line) {
    final expected = ExternalWorkRecord.calculateAmountFen(
      hoursMilli: line.hoursMilli,
      unitPriceFen: line.sourceUnitPriceFen,
    );
    if (line.amountFen != expected) {
      throw const ProjectExternalWorkImportException(
        ProjectExternalWorkImportErrorCodes.amountMismatch,
        'external work line amount_fen does not match AmountPolicy',
      );
    }
  }

  static String _buildSiteSummary(List<ExternalWorkImportPreviewLine> lines) {
    final sites = <String>[];
    for (final line in lines) {
      final site = line.siteSnapshot.trim();
      if (site.isEmpty || sites.contains(site)) continue;
      sites.add(site);
    }
    if (sites.length <= 3) return sites.join('、');
    return '${sites.take(3).join('、')} 等${sites.length}个工地';
  }

  static Future<bool> _exists(
    DatabaseExecutor executor,
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final rows = await executor.query(
      table,
      columns: const ['id'],
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
