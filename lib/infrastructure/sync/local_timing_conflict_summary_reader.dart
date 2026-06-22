import 'dart:convert';

import '../../data/db/database.dart';
import '../../features/sync/sync_conflict_review_controller.dart';
import 'remote_change_applier.dart';
import 'sync_conflict_repository.dart';

class LocalTimingConflictSummaryReader implements TimingConflictSummaryReader {
  const LocalTimingConflictSummaryReader();

  @override
  Future<TimingConflictSummary?> localSummary(SyncConflict conflict) async {
    if (conflict.entityType != TimingRecordRemoteChangeApplier.entityType) {
      return null;
    }
    final db = await AppDatabase.database;
    final rows = await db.query(
      'timing_records',
      where: 'id = ?',
      whereArgs: [int.tryParse(conflict.entityId) ?? -1],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _summaryFromRecord(rows.single, deleted: false);
  }

  @override
  TimingConflictSummary remoteSummary(SyncConflict conflict) {
    if (conflict.remoteDeleted) {
      return const TimingConflictSummary(
        deviceId: 0,
        startDate: 0,
        hours: 0,
        incomeFen: 0,
        deleted: true,
      );
    }
    final decoded = jsonDecode(conflict.remotePayloadJson);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('remote timing payload must be an object');
    }
    final record = decoded['record'];
    if (record is Map<String, Object?>) {
      return _summaryFromRecord(record, deleted: false);
    }
    return _summaryFromRecord(decoded, deleted: false);
  }
}

TimingConflictSummary _summaryFromRecord(
  Map<String, Object?> record, {
  required bool deleted,
}) {
  return TimingConflictSummary(
    deviceId: _requiredInt(record, 'device_id'),
    startDate: _requiredInt(record, 'start_date'),
    hours: _requiredNumber(record, 'hours'),
    incomeFen: _requiredInt(record, 'income_fen'),
    deleted: deleted,
  );
}

int _requiredInt(Map<String, Object?> record, String name) {
  final value = record[name];
  if (value is int) return value;
  if (value is num && value % 1 == 0) return value.toInt();
  throw FormatException('timing_record.$name must be an integer');
}

double _requiredNumber(Map<String, Object?> record, String name) {
  final value = record[name];
  if (value is num) return value.toDouble();
  throw FormatException('timing_record.$name must be a number');
}
