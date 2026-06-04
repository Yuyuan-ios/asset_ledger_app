import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/db/database.dart';
import 'entity_sync_meta.dart';
import 'sync_outbox_entry.dart';
import 'sync_status.dart';

abstract class SyncOutboxRepository {
  Future<SyncOutboxEntry> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  });

  Future<SyncOutboxEntry> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  });

  Future<List<SyncOutboxEntry>> listPending({int limit = 50});
}

class LocalSyncOutboxRepository implements SyncOutboxRepository {
  const LocalSyncOutboxRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  @override
  Future<SyncOutboxEntry> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final db = await AppDatabase.database;
    return enqueueWithExecutor(
      db,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
    );
  }

  @override
  Future<SyncOutboxEntry> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final now = _now().toUtc();
    final nowIso = now.toIso8601String();
    final payloadJson = jsonEncode(payload);
    final payloadHash = sha256.convert(utf8.encode(payloadJson)).toString();
    final entry = SyncOutboxEntry(
      id: 'outbox-${now.microsecondsSinceEpoch}',
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payloadJson: payloadJson,
      payloadHash: payloadHash,
      status: SyncOutboxStatus.pending,
      retryCount: 0,
      createdAt: nowIso,
      updatedAt: nowIso,
    );
    await executor.insert('sync_outbox', entry.toMap());
    return entry;
  }

  @override
  Future<List<SyncOutboxEntry>> listPending({int limit = 50}) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'sync_outbox',
      where: 'status = ?',
      whereArgs: [SyncOutboxStatus.pending.name],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(SyncOutboxEntry.fromMap).toList(growable: false);
  }
}

abstract class EntitySyncMetaRepository {
  Future<void> upsert(EntitySyncMeta meta);

  Future<void> upsertWithExecutor(
    DatabaseExecutor executor,
    EntitySyncMeta meta,
  );

  Future<EntitySyncMeta?> find({
    required String entityType,
    required String localId,
  });
}

class LocalEntitySyncMetaRepository implements EntitySyncMetaRepository {
  const LocalEntitySyncMetaRepository();

  static const String _table = 'entity_sync_meta';

  @override
  Future<void> upsert(EntitySyncMeta meta) async {
    // 非事务入口也走 read-merge-write，包一层事务保证原子性。
    await AppDatabase.inTransaction((txn) => upsertWithExecutor(txn, meta));
  }

  /// 保留式 upsert（R5.4）。
  ///
  /// 不再整行 replace。先按 (entity_type, local_id) 读取既有行：
  /// - 不存在 → 直接插入 incoming（行为同旧实现）。
  /// - 已存在 → 合并：保留 server_id / source / created_by 等长期字段与既有
  ///   version（仅当 incoming.version 更高才上调），仅用 incoming 覆盖
  ///   sync_status / payload_hash 等"当前状态"字段。
  ///
  /// 由此本地 save / delete / payment 的 pending 标记不会抹掉云端 pull 回填的
  /// server_id / version。该逻辑收口在 repo 层，三条业务写路径自动受益，无需各
  /// use case 自行处理保留。
  @override
  Future<void> upsertWithExecutor(
    DatabaseExecutor executor,
    EntitySyncMeta meta,
  ) async {
    final existing = await _findWithExecutor(
      executor,
      entityType: meta.entityType,
      localId: meta.localId,
    );
    final row = existing == null ? meta : _mergePreserving(existing, meta);
    await executor.insert(
      _table,
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<EntitySyncMeta?> find({
    required String entityType,
    required String localId,
  }) async {
    final db = await AppDatabase.database;
    return _findWithExecutor(db, entityType: entityType, localId: localId);
  }

  Future<EntitySyncMeta?> _findWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String localId,
  }) async {
    final rows = await executor.query(
      _table,
      where: 'entity_type = ? AND local_id = ?',
      whereArgs: [entityType, localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return EntitySyncMeta.fromMap(rows.single);
  }

  /// 合并已有行与新写入，保留长期/权威字段，仅覆盖当前状态字段。
  EntitySyncMeta _mergePreserving(
    EntitySyncMeta existing,
    EntitySyncMeta incoming,
  ) {
    return EntitySyncMeta(
      entityType: existing.entityType,
      localId: existing.localId,
      // server_id：云端回填后不可被本地 pending 抹掉。
      serverId: existing.serverId ?? incoming.serverId,
      // sync_status：当前状态，始终用 incoming。
      syncStatus: incoming.syncStatus,
      // version：保留既有；仅当 incoming 明确更高才上调（云端 pull 场景）。
      version: incoming.version > existing.version
          ? incoming.version
          : existing.version,
      // source：实体来源不因本地编辑而改变 → 保留既有。
      source: existing.source,
      // created_by：创建归属不可变 → 保留既有。
      createdBy: existing.createdBy ?? incoming.createdBy,
      // updated_by：保留最近已知写者，incoming 显式提供才覆盖。
      updatedBy: incoming.updatedBy ?? existing.updatedBy,
      // 以下长期字段默认保留，incoming 显式非空才覆盖，避免本地 pending 抹掉。
      deletedAt: incoming.deletedAt ?? existing.deletedAt,
      payloadHash: incoming.payloadHash ?? existing.payloadHash,
      lastSyncedAt: incoming.lastSyncedAt ?? existing.lastSyncedAt,
      conflictReason: incoming.conflictReason ?? existing.conflictReason,
    );
  }
}
