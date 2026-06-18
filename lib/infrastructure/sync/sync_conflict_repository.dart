import 'package:sqflite/sqflite.dart';

import '../../data/db/database.dart';
import 'remote_change.dart';

enum SyncConflictStatus {
  pending,
  resolved;

  static SyncConflictStatus parse(String value) {
    return SyncConflictStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SyncConflictStatus.pending,
    );
  }
}

enum SyncConflictResolution {
  local,
  remote;

  static SyncConflictResolution? parse(Object? value) {
    if (value is! String) return null;
    for (final item in SyncConflictResolution.values) {
      if (item.name == value) return item;
    }
    return null;
  }
}

class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.remoteServerSeq,
    required this.remoteBaseVersion,
    required this.remoteNewVersion,
    required this.remotePayloadJson,
    required this.remotePayloadHash,
    required this.remoteDeleted,
    required this.conflictReason,
    required this.detectedAt,
    required this.status,
    this.resolution,
    this.resolvedAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final int remoteServerSeq;
  final int remoteBaseVersion;
  final int remoteNewVersion;
  final String remotePayloadJson;
  final String remotePayloadHash;
  final bool remoteDeleted;
  final String conflictReason;
  final String detectedAt;
  final SyncConflictStatus status;
  final SyncConflictResolution? resolution;
  final String? resolvedAt;

  factory SyncConflict.fromRemoteChange({
    required RemoteChange change,
    required String reason,
    required DateTime detectedAt,
  }) {
    return SyncConflict(
      id: '${change.entityType}:${change.entityId}:${change.serverSeq}',
      entityType: change.entityType,
      entityId: change.entityId,
      remoteServerSeq: change.serverSeq,
      remoteBaseVersion: change.baseVersion,
      remoteNewVersion: change.newVersion,
      remotePayloadJson: change.payloadJson,
      remotePayloadHash: change.payloadHash,
      remoteDeleted: change.deleted,
      conflictReason: reason,
      detectedAt: detectedAt.toUtc().toIso8601String(),
      status: SyncConflictStatus.pending,
    );
  }

  factory SyncConflict.fromMap(Map<String, Object?> map) {
    return SyncConflict(
      id: map['id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      remoteServerSeq: (map['remote_server_seq'] as num).toInt(),
      remoteBaseVersion: (map['remote_base_version'] as num?)?.toInt() ?? 0,
      remoteNewVersion: (map['remote_new_version'] as num).toInt(),
      remotePayloadJson: map['remote_payload_json'] as String,
      remotePayloadHash: map['remote_payload_hash'] as String,
      remoteDeleted: ((map['remote_deleted'] as num?)?.toInt() ?? 0) != 0,
      conflictReason: map['conflict_reason'] as String,
      detectedAt: map['detected_at'] as String,
      status: SyncConflictStatus.parse(map['status'] as String),
      resolution: SyncConflictResolution.parse(map['resolution']),
      resolvedAt: map['resolved_at'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'remote_server_seq': remoteServerSeq,
      'remote_base_version': remoteBaseVersion,
      'remote_new_version': remoteNewVersion,
      'remote_payload_json': remotePayloadJson,
      'remote_payload_hash': remotePayloadHash,
      'remote_deleted': remoteDeleted ? 1 : 0,
      'conflict_reason': conflictReason,
      'detected_at': detectedAt,
      'status': status.name,
      'resolution': resolution?.name,
      'resolved_at': resolvedAt,
    };
  }

  RemoteChange toRemoteChange() {
    return RemoteChange(
      serverSeq: remoteServerSeq,
      entityType: entityType,
      entityId: entityId,
      baseVersion: remoteBaseVersion,
      newVersion: remoteNewVersion,
      payloadJson: remotePayloadJson,
      payloadHash: remotePayloadHash,
      deleted: remoteDeleted,
    );
  }
}

abstract class SyncConflictRepository {
  Future<bool> insertIfAbsent(SyncConflict conflict);

  Future<bool> insertIfAbsentWithExecutor(
    DatabaseExecutor executor,
    SyncConflict conflict,
  );

  Future<List<SyncConflict>> listPending({int limit = 50});

  /// 最早一条未解决冲突的 remote_server_seq；无未决冲突时返回 null。
  ///
  /// 用于云备份 watermark 收敛：parked 冲突对应的 server_seq 虽已被 pull 游标
  /// 越过，但其变更并未落入快照（被搁置待人工裁决），且 restore 会清空
  /// sync_conflicts。watermark 必须停在最早未决冲突之前，恢复方才会重新拉取
  /// 并重建这些冲突，避免静默丢失待审改动。
  Future<int?> earliestPendingServerSeq();

  Future<int> markResolved({
    required String id,
    required SyncConflictResolution resolution,
    DateTime? now,
  });

  Future<int> markResolvedWithExecutor(
    DatabaseExecutor executor, {
    required String id,
    required SyncConflictResolution resolution,
    DateTime? now,
  });
}

class LocalSyncConflictRepository implements SyncConflictRepository {
  const LocalSyncConflictRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  static const String _table = 'sync_conflicts';

  @override
  Future<bool> insertIfAbsent(SyncConflict conflict) async {
    final db = await AppDatabase.database;
    return insertIfAbsentWithExecutor(db, conflict);
  }

  @override
  Future<bool> insertIfAbsentWithExecutor(
    DatabaseExecutor executor,
    SyncConflict conflict,
  ) async {
    final inserted = await executor.insert(
      _table,
      conflict.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return inserted != 0;
  }

  @override
  Future<List<SyncConflict>> listPending({int limit = 50}) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      _table,
      where: 'status = ?',
      whereArgs: [SyncConflictStatus.pending.name],
      orderBy: 'detected_at ASC, remote_server_seq ASC',
      limit: limit,
    );
    return rows.map(SyncConflict.fromMap).toList(growable: false);
  }

  @override
  Future<int?> earliestPendingServerSeq() async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      _table,
      columns: const ['MIN(remote_server_seq) AS min_seq'],
      where: 'status = ?',
      whereArgs: [SyncConflictStatus.pending.name],
    );
    // MIN(...) 在空集上返回单行 NULL；只有 num 才视为有效 seq。
    final value = rows.isEmpty ? null : rows.single['min_seq'];
    return value is num ? value.toInt() : null;
  }

  @override
  Future<int> markResolved({
    required String id,
    required SyncConflictResolution resolution,
    DateTime? now,
  }) async {
    final db = await AppDatabase.database;
    return markResolvedWithExecutor(
      db,
      id: id,
      resolution: resolution,
      now: now,
    );
  }

  @override
  Future<int> markResolvedWithExecutor(
    DatabaseExecutor executor, {
    required String id,
    required SyncConflictResolution resolution,
    DateTime? now,
  }) async {
    return executor.update(
      _table,
      {
        'status': SyncConflictStatus.resolved.name,
        'resolution': resolution.name,
        'resolved_at': (now ?? _now()).toUtc().toIso8601String(),
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, SyncConflictStatus.pending.name],
    );
  }
}
