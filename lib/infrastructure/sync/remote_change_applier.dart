import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../data/db/database.dart';
import 'remote_change.dart';
import 'sync_status.dart';

abstract class RemoteChangeApplier {
  Future<void> apply(RemoteChange change, {DateTime? now});

  Future<void> applyWithExecutor(
    DatabaseExecutor executor,
    RemoteChange change, {
    DateTime? now,
  });
}

class TimingRecordRemoteChangeApplier implements RemoteChangeApplier {
  const TimingRecordRemoteChangeApplier();

  static const entityType = 'timing_record';
  static const _table = 'timing_records';
  static const _metaTable = 'entity_sync_meta';
  static const _ownerAppSource = 'owner_app';

  @override
  Future<void> apply(RemoteChange change, {DateTime? now}) {
    return AppDatabase.inTransaction(
      (txn) => applyWithExecutor(txn, change, now: now),
    );
  }

  @override
  Future<void> applyWithExecutor(
    DatabaseExecutor executor,
    RemoteChange change, {
    DateTime? now,
  }) async {
    if (change.entityType != entityType) {
      throw UnsupportedError('Unsupported remote entity: ${change.entityType}');
    }
    final id = _parseEntityId(change.entityId);
    final syncedAt = (now ?? DateTime.now()).toUtc().toIso8601String();

    if (change.deleted) {
      await executor.delete(_table, where: 'id = ?', whereArgs: [id]);
      await _writeSyncedMeta(
        executor,
        change,
        syncedAt: syncedAt,
        deletedAt: syncedAt,
      );
      return;
    }

    final record = _recordFromPayload(change.payloadJson);
    final row = _timingRowFromRemoteRecord(record, id);
    final updated = await executor.update(
      _table,
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      await executor.insert(_table, {'id': id, ...row});
    }
    await _writeSyncedMeta(
      executor,
      change,
      syncedAt: syncedAt,
      deletedAt: null,
    );
  }

  Future<void> _writeSyncedMeta(
    DatabaseExecutor executor,
    RemoteChange change, {
    required String syncedAt,
    required String? deletedAt,
  }) async {
    final existing = await executor.query(
      _metaTable,
      where: 'entity_type = ? AND local_id = ?',
      whereArgs: [change.entityType, change.entityId],
      limit: 1,
    );
    final existingRow = existing.isEmpty
        ? const <String, Object?>{}
        : existing.single;
    await executor.insert(_metaTable, {
      'entity_type': change.entityType,
      'local_id': change.entityId,
      'server_id': existingRow['server_id'] ?? change.entityId,
      'sync_status': SyncStatus.synced.name,
      'version': change.newVersion,
      'source': existingRow['source'] ?? _ownerAppSource,
      'created_by': existingRow['created_by'],
      'updated_by': existingRow['updated_by'],
      'deleted_at': deletedAt,
      'payload_hash': change.payloadHash,
      'last_synced_at': syncedAt,
      'conflict_reason': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  int _parseEntityId(String entityId) {
    final id = int.tryParse(entityId);
    if (id == null || id <= 0) {
      throw FormatException(
        'timing_record entity_id must be a positive int: $entityId',
      );
    }
    return id;
  }

  Map<String, Object?> _recordFromPayload(String payloadJson) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'timing_record payload_json must be an object',
      );
    }
    final record = decoded['record'];
    if (record is Map<String, Object?>) return record;
    return decoded;
  }

  Map<String, Object?> _timingRowFromRemoteRecord(
    Map<String, Object?> record,
    int id,
  ) {
    final type = _requiredString(record, 'type');
    return {
      'project_id': _requiredString(record, 'project_id'),
      'device_id': _requiredInt(record, 'device_id'),
      'start_date': _requiredInt(record, 'start_date'),
      'allocation_cutoff_date': _optionalInt(record, 'allocation_cutoff_date'),
      'display_end_date': _optionalInt(record, 'display_end_date'),
      'contact': _requiredString(record, 'contact'),
      'site': _requiredString(record, 'site'),
      'type': type,
      'start_meter': _requiredNumber(record, 'start_meter'),
      'end_meter': _requiredNumber(record, 'end_meter'),
      'hours': _requiredNumber(record, 'hours'),
      'income_fen': _requiredInt(record, 'income_fen'),
      'unit':
          _optionalString(record, 'unit') ?? (type == 'rent' ? 'RENT' : 'HOUR'),
      'quantity_scaled': _optionalInt(record, 'quantity_scaled'),
      'exclude_from_fuel_eff': _boolInt(record, 'exclude_from_fuel_eff'),
      'is_breaking': _boolInt(record, 'is_breaking'),
    };
  }

  String _requiredString(Map<String, Object?> record, String name) {
    final value = record[name];
    if (value is String) return value;
    throw FormatException('timing_record.$name must be a string');
  }

  String? _optionalString(Map<String, Object?> record, String name) {
    final value = record[name];
    return value is String ? value : null;
  }

  int _requiredInt(Map<String, Object?> record, String name) {
    final value = record[name];
    if (value is int) return value;
    if (value is num && value % 1 == 0) return value.toInt();
    throw FormatException('timing_record.$name must be an integer');
  }

  int? _optionalInt(Map<String, Object?> record, String name) {
    final value = record[name];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num && value % 1 == 0) return value.toInt();
    throw FormatException('timing_record.$name must be an integer');
  }

  double _requiredNumber(Map<String, Object?> record, String name) {
    final value = record[name];
    if (value is num) return value.toDouble();
    throw FormatException('timing_record.$name must be a number');
  }

  int _boolInt(Map<String, Object?> record, String name) {
    final value = record[name];
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value == 0 ? 0 : 1;
    return 0;
  }
}
