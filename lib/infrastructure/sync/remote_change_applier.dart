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

abstract class _TableRemoteChangeApplier implements RemoteChangeApplier {
  const _TableRemoteChangeApplier();

  String get remoteEntityType;

  String get table;

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
    if (change.entityType != remoteEntityType) {
      throw UnsupportedError('Unsupported remote entity: ${change.entityType}');
    }
    final key = _parseEntityId(change.entityId);
    final syncedAt = (now ?? DateTime.now()).toUtc().toIso8601String();

    if (change.deleted) {
      await executor.delete(table, where: key.whereClause, whereArgs: key.args);
      await _writeSyncedMeta(
        executor,
        change,
        syncedAt: syncedAt,
        deletedAt: syncedAt,
      );
      return;
    }

    final record = _recordFromPayload(change.payloadJson);
    final row = _rowFromRemoteRecord(record, key);
    final updated = await executor.update(
      table,
      row,
      where: key.whereClause,
      whereArgs: key.args,
    );
    if (updated == 0) {
      await executor.insert(table, {...key.columns, ...row});
    }
    await _writeSyncedMeta(
      executor,
      change,
      syncedAt: syncedAt,
      deletedAt: null,
    );
  }

  _RemoteEntityKey _parseEntityId(String entityId);

  Map<String, Object?> _rowFromRemoteRecord(
    Map<String, Object?> record,
    _RemoteEntityKey key,
  );

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

  Map<String, Object?> _recordFromPayload(String payloadJson) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('$remoteEntityType payload_json must be an object');
    }
    final record = decoded['record'];
    if (record is Map<String, Object?>) return record;
    return decoded;
  }

  String requiredString(Map<String, Object?> record, String name) {
    final value = record[name];
    if (value is String) return value;
    throw FormatException('$remoteEntityType.$name must be a string');
  }

  String? optionalString(Map<String, Object?> record, String name) {
    final value = record[name];
    return value is String ? value : null;
  }

  int requiredInt(Map<String, Object?> record, String name) {
    final value = record[name];
    if (value is int) return value;
    if (value is num && value % 1 == 0) return value.toInt();
    throw FormatException('$remoteEntityType.$name must be an integer');
  }

  int? optionalInt(Map<String, Object?> record, String name) {
    final value = record[name];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num && value % 1 == 0) return value.toInt();
    throw FormatException('$remoteEntityType.$name must be an integer');
  }

  double requiredNumber(Map<String, Object?> record, String name) {
    final value = record[name];
    if (value is num) return value.toDouble();
    throw FormatException('$remoteEntityType.$name must be a number');
  }

  int boolInt(Map<String, Object?> record, String name) {
    final value = record[name];
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value == 0 ? 0 : 1;
    return 0;
  }
}

class _RemoteEntityKey {
  const _RemoteEntityKey(this.columns);

  final Map<String, Object?> columns;

  String get whereClause =>
      columns.keys.map((column) => '$column = ?').join(' AND ');

  List<Object?> get args => columns.values.toList(growable: false);
}

class TimingRecordRemoteChangeApplier extends _TableRemoteChangeApplier {
  const TimingRecordRemoteChangeApplier();

  static const entityType = 'timing_record';
  static const _table = 'timing_records';

  @override
  String get remoteEntityType => entityType;

  @override
  String get table => _table;

  @override
  _RemoteEntityKey _parseEntityId(String entityId) {
    final id = int.tryParse(entityId);
    if (id == null || id <= 0) {
      throw FormatException(
        'timing_record entity_id must be a positive int: $entityId',
      );
    }
    return _RemoteEntityKey({'id': id});
  }

  @override
  Map<String, Object?> _rowFromRemoteRecord(
    Map<String, Object?> record,
    _RemoteEntityKey key,
  ) {
    final type = requiredString(record, 'type');
    return {
      'project_id': requiredString(record, 'project_id'),
      'device_id': requiredInt(record, 'device_id'),
      'start_date': requiredInt(record, 'start_date'),
      'allocation_cutoff_date': optionalInt(record, 'allocation_cutoff_date'),
      'display_end_date': optionalInt(record, 'display_end_date'),
      'contact': requiredString(record, 'contact'),
      'site': requiredString(record, 'site'),
      'type': type,
      'start_meter': requiredNumber(record, 'start_meter'),
      'end_meter': requiredNumber(record, 'end_meter'),
      'hours': requiredNumber(record, 'hours'),
      'income_fen': requiredInt(record, 'income_fen'),
      'unit':
          optionalString(record, 'unit') ?? (type == 'rent' ? 'RENT' : 'HOUR'),
      'quantity_scaled': optionalInt(record, 'quantity_scaled'),
      'exclude_from_fuel_eff': boolInt(record, 'exclude_from_fuel_eff'),
      'is_breaking': boolInt(record, 'is_breaking'),
    };
  }
}

class ProjectRemoteChangeApplier extends _TableRemoteChangeApplier {
  const ProjectRemoteChangeApplier();

  static const entityType = 'project';
  static const _table = 'projects';

  @override
  String get remoteEntityType => entityType;

  @override
  String get table => _table;

  @override
  _RemoteEntityKey _parseEntityId(String entityId) {
    if (entityId.trim().isEmpty) {
      throw const FormatException('project entity_id must be a non-empty text');
    }
    return _RemoteEntityKey({'id': entityId});
  }

  @override
  Map<String, Object?> _rowFromRemoteRecord(
    Map<String, Object?> record,
    _RemoteEntityKey key,
  ) {
    final id = key.columns['id'] as String;
    final recordId = requiredString(record, 'id');
    if (recordId != id) {
      throw FormatException('project.id must match entity_id: $id');
    }
    return {
      'contact': requiredString(record, 'contact'),
      'site': requiredString(record, 'site'),
      'status': requiredString(record, 'status'),
      'settled_at': optionalString(record, 'settled_at'),
      'settled_snapshot': optionalString(record, 'settled_snapshot'),
      'created_at': requiredString(record, 'created_at'),
      'updated_at': requiredString(record, 'updated_at'),
      'legacy_project_key': optionalString(record, 'legacy_project_key'),
    };
  }
}

class ProjectDeviceRateRemoteChangeApplier extends _TableRemoteChangeApplier {
  const ProjectDeviceRateRemoteChangeApplier();

  static const entityType = 'project_device_rate';
  static const _table = 'project_device_rates';

  @override
  String get remoteEntityType => entityType;

  @override
  String get table => _table;

  @override
  _RemoteEntityKey _parseEntityId(String entityId) {
    final lastSeparator = entityId.lastIndexOf(':');
    final secondLastSeparator = lastSeparator <= 0
        ? -1
        : entityId.lastIndexOf(':', lastSeparator - 1);
    if (secondLastSeparator <= 0 || secondLastSeparator == lastSeparator - 1) {
      throw FormatException(
        'project_device_rate entity_id must be '
        '<project_id>:<device_id>:<is_breaking>: $entityId',
      );
    }
    final projectId = entityId.substring(0, secondLastSeparator);
    final deviceId = int.tryParse(
      entityId.substring(secondLastSeparator + 1, lastSeparator),
    );
    final isBreaking = int.tryParse(entityId.substring(lastSeparator + 1));
    if (projectId.trim().isEmpty || deviceId == null || deviceId <= 0) {
      throw FormatException(
        'project_device_rate entity_id must be '
        '<project_id>:<device_id>:<is_breaking>: $entityId',
      );
    }
    if (isBreaking != 0 && isBreaking != 1) {
      throw FormatException(
        'project_device_rate entity_id is_breaking must be 0 or 1: $entityId',
      );
    }
    return _RemoteEntityKey({
      'project_id': projectId,
      'device_id': deviceId,
      'is_breaking': isBreaking,
    });
  }

  @override
  Map<String, Object?> _rowFromRemoteRecord(
    Map<String, Object?> record,
    _RemoteEntityKey key,
  ) {
    final projectId = key.columns['project_id'] as String;
    final deviceId = key.columns['device_id'] as int;
    final isBreaking = key.columns['is_breaking'] as int;
    final recordProjectId = requiredString(record, 'project_id');
    final recordDeviceId = requiredInt(record, 'device_id');
    final recordIsBreaking = _requiredBoolInt(record, 'is_breaking');
    if (recordProjectId != projectId ||
        recordDeviceId != deviceId ||
        recordIsBreaking != isBreaking) {
      throw FormatException(
        'project_device_rate record key must match entity_id: '
        '$projectId:$deviceId:$isBreaking',
      );
    }
    return {
      'project_key': requiredString(record, 'project_key'),
      'rate_fen': requiredInt(record, 'rate_fen'),
    };
  }

  int _requiredBoolInt(Map<String, Object?> record, String name) {
    final value = requiredInt(record, name);
    if (value == 0 || value == 1) return value;
    throw FormatException('project_device_rate.$name must be 0 or 1');
  }
}

class FuelLogRemoteChangeApplier extends _TableRemoteChangeApplier {
  const FuelLogRemoteChangeApplier();

  static const entityType = 'fuel_log';
  static const _table = 'fuel_logs';

  @override
  String get remoteEntityType => entityType;

  @override
  String get table => _table;

  @override
  _RemoteEntityKey _parseEntityId(String entityId) {
    final id = int.tryParse(entityId);
    if (id == null || id <= 0) {
      throw FormatException(
        'fuel_log entity_id must be a positive int: $entityId',
      );
    }
    return _RemoteEntityKey({'id': id});
  }

  @override
  Map<String, Object?> _rowFromRemoteRecord(
    Map<String, Object?> record,
    _RemoteEntityKey key,
  ) {
    final id = key.columns['id'] as int;
    final recordId = requiredInt(record, 'id');
    if (recordId != id) {
      throw FormatException('fuel_log.id must match entity_id: $id');
    }
    return {
      'device_id': requiredInt(record, 'device_id'),
      'date': requiredInt(record, 'date'),
      'supplier': requiredString(record, 'supplier'),
      'liters': requiredNumber(record, 'liters'),
      'cost_fen': requiredInt(record, 'cost_fen'),
    };
  }
}

class MaintenanceRecordRemoteChangeApplier extends _TableRemoteChangeApplier {
  const MaintenanceRecordRemoteChangeApplier();

  static const entityType = 'maintenance_record';
  static const _table = 'maintenance_records';

  @override
  String get remoteEntityType => entityType;

  @override
  String get table => _table;

  @override
  _RemoteEntityKey _parseEntityId(String entityId) {
    final id = int.tryParse(entityId);
    if (id == null || id <= 0) {
      throw FormatException(
        'maintenance_record entity_id must be a positive int: $entityId',
      );
    }
    return _RemoteEntityKey({'id': id});
  }

  @override
  Map<String, Object?> _rowFromRemoteRecord(
    Map<String, Object?> record,
    _RemoteEntityKey key,
  ) {
    final id = key.columns['id'] as int;
    final recordId = requiredInt(record, 'id');
    if (recordId != id) {
      throw FormatException('maintenance_record.id must match entity_id: $id');
    }
    return {
      'device_id': optionalInt(record, 'device_id'),
      'ymd': requiredInt(record, 'ymd'),
      'item': requiredString(record, 'item'),
      'amount_fen': requiredInt(record, 'amount_fen'),
      'note': optionalString(record, 'note'),
    };
  }
}
