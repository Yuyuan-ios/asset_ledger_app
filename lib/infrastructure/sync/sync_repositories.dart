import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/db/database.dart';
import 'entity_sync_meta.dart';
import 'outbox_id_generator.dart';
import 'sync_outbox_entry.dart';
import 'sync_status.dart';

abstract class SyncOutboxRepository {
  Future<SyncOutboxEntry> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    String? transactionGroupId,
    int? localSequence,
  });

  Future<SyncOutboxEntry> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    String? transactionGroupId,
    int? localSequence,
  });

  Future<List<SyncOutboxEntry>> listPending({int limit = 50});
}

/// R5.22-B: the push-side lifecycle of `sync_outbox`, segregated from the
/// enqueue/write side so the SyncManager only depends on what it needs (ISP) and
/// the many enqueue-only test doubles do not have to implement push methods.
abstract class SyncOutboxPushRepository {
  /// Pending rows that are eligible to push right now: status = pending AND
  /// (next_retry_at IS NULL OR next_retry_at <= now). Base order is created_at
  /// ASC; the SyncManager re-orders by transaction group / local_sequence.
  Future<List<SyncOutboxEntry>> listPending({int limit = 50});

  /// Acknowledge a successfully pushed row by removing it so it is never pushed
  /// again. (R5.22-B keeps the deleted row as the authoritative ack.)
  Future<void> deleteAcknowledged(String id);

  /// R5.23: remove a pending row that the SyncManager folded out before push
  /// (a later pending row for the same `(entity_type, entity_id)` supersedes
  /// it — e.g. a `create` followed by a `delete` in the same listPending
  /// snapshot).
  ///
  /// Semantically distinct from [deleteAcknowledged]: the server NEVER saw
  /// this row. Structurally identical today (a plain delete by id), but kept
  /// as its own method so SyncManager telemetry, future meta-cleanup hooks,
  /// and casual readers can tell folding-side cleanup apart from server acks.
  Future<void> deleteSuperseded(String id);

  /// Record a transient push failure (network / server error): retry_count += 1,
  /// last_error and next_retry_at set, updated_at refreshed. The row stays
  /// pending so it is retried after the backoff window elapses.
  Future<void> markFailed({
    required String id,
    required String lastError,
    required String nextRetryAtIso,
  });

  /// R5.22-B-Hardening: record a TERMINAL failure (e.g. corrupt/invalid local
  /// metadata that can never push as-is). status -> failed, next_retry_at
  /// cleared, retry_count untouched. listPending only returns status = pending,
  /// so a terminal-failed row is never read/sent/retried again until a human
  /// repairs the data. This stops invalid rows from looping forever on backoff
  /// without losing the row or its diagnostic last_error.
  Future<void> markTerminalFailed({
    required String id,
    required String lastError,
  });
}

class LocalSyncOutboxRepository
    implements SyncOutboxRepository, SyncOutboxPushRepository {
  const LocalSyncOutboxRepository({
    DateTime Function()? now,
    OutboxIdGenerator? idGenerator,
  }) : _now = now ?? DateTime.now,
       _idGenerator = idGenerator;

  final DateTime Function() _now;

  /// 可注入的 id 生成器；为空时用共享的安全随机默认实现。
  /// 保持构造可 const（业务路径的 `const LocalSyncOutboxRepository()` 不变）。
  final OutboxIdGenerator? _idGenerator;

  /// 共享默认生成器。每次 `generate()` 取新随机熵，无需协调即避免碰撞，
  /// 因此共享单例不构成"靠共享可变状态避免碰撞"。
  static final OutboxIdGenerator _defaultIdGenerator =
      SecureRandomOutboxIdGenerator();

  @override
  Future<SyncOutboxEntry> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    String? transactionGroupId,
    int? localSequence,
  }) async {
    final db = await AppDatabase.database;
    return enqueueWithExecutor(
      db,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
    );
  }

  @override
  Future<SyncOutboxEntry> enqueueWithExecutor(
    DatabaseExecutor executor, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    String? transactionGroupId,
    int? localSequence,
  }) async {
    // R5.22-A-Hardening: validate the grouping metadata at the single write
    // boundary (enqueue() delegates here too).
    _validateTransactionGroupMetadata(
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
    );
    final now = _now().toUtc();
    final nowIso = now.toIso8601String();
    final payloadJson = jsonEncode(payload);
    final payloadHash = sha256.convert(utf8.encode(payloadJson)).toString();
    final entry = SyncOutboxEntry(
      id: (_idGenerator ?? _defaultIdGenerator).generate(),
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payloadJson: payloadJson,
      payloadHash: payloadHash,
      status: SyncOutboxStatus.pending,
      retryCount: 0,
      // R5.22-A outbox metadata (null for ordinary single-row enqueues); not
      // part of the business payload.
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      createdAt: nowIso,
      updatedAt: nowIso,
    );
    await executor.insert('sync_outbox', entry.toMap());
    return entry;
  }

  @override
  Future<List<SyncOutboxEntry>> listPending({int limit = 50}) async {
    final db = await AppDatabase.database;
    // R5.22-B: skip rows whose backoff window has not elapsed. next_retry_at
    // NULL means "never failed / immediately eligible". ISO8601 UTC strings
    // compare lexicographically in chronological order.
    final nowIso = _now().toUtc().toIso8601String();
    final rows = await db.query(
      'sync_outbox',
      where: 'status = ? AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [SyncOutboxStatus.pending.name, nowIso],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(SyncOutboxEntry.fromMap).toList(growable: false);
  }

  @override
  Future<void> deleteAcknowledged(String id) async {
    final db = await AppDatabase.database;
    await db.delete('sync_outbox', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteSuperseded(String id) async {
    // R5.23: structurally identical to [deleteAcknowledged] today (a plain
    // delete by id). Kept as its own method so the semantic split between
    // "client-side folded" and "server-acked" is visible at the call site
    // and so a future revision can attach side-effects to one but not the
    // other (e.g. only fold-side may eventually want to clear pendingDelete
    // meta rows).
    final db = await AppDatabase.database;
    await db.delete('sync_outbox', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> markFailed({
    required String id,
    required String lastError,
    required String nextRetryAtIso,
  }) async {
    final db = await AppDatabase.database;
    final nowIso = _now().toUtc().toIso8601String();
    await db.rawUpdate(
      'UPDATE sync_outbox SET retry_count = retry_count + 1, '
      'last_error = ?, next_retry_at = ?, updated_at = ? WHERE id = ?',
      [lastError, nextRetryAtIso, nowIso, id],
    );
  }

  @override
  Future<void> markTerminalFailed({
    required String id,
    required String lastError,
  }) async {
    final db = await AppDatabase.database;
    final nowIso = _now().toUtc().toIso8601String();
    // Terminal: leave status=failed (excluded by listPending) and clear any
    // backoff timestamp so it is not even considered. retry_count is left as-is.
    await db.rawUpdate(
      'UPDATE sync_outbox SET status = ?, last_error = ?, '
      'next_retry_at = NULL, updated_at = ? WHERE id = ?',
      [SyncOutboxStatus.failed.name, lastError, nowIso, id],
    );
  }
}

/// R5.22-B-Hardening: the push-success acknowledgement side of
/// `entity_sync_meta`, segregated from [EntitySyncMetaRepository] so the
/// SyncManager only depends on what it needs and the many enqueue-side meta test
/// doubles do not have to implement it (ISP).
abstract class EntitySyncMetaAckRepository {
  /// After a row's push is acknowledged (server accepted it), clear the local
  /// "pending" sync state of the matching meta row so a later status query does
  /// not still read it as pendingUpload/pendingUpdate.
  ///
  /// Operation semantics:
  /// - 'create' → flips an existing `pendingUpload` row to `synced`.
  /// - 'update' → flips an existing `pendingUpdate` row to `synced`.
  /// - 'delete' → no-op (the entity is locally gone; a deleted-entity meta
  ///   lifecycle is intentionally deferred — see report).
  ///
  /// Only an existing row is updated; no meta row is fabricated. Returns the
  /// number of meta rows updated (0 when none matched / delete).
  Future<int> markPushAcknowledged({
    required String entityType,
    required String localId,
    required String operation,
    required String syncedAtIso,
    int? newVersion,
  });
}

/// R5.22-A-Hardening: enforce that `transaction_group_id` and `local_sequence`
/// are written as a valid pair.
///
/// - both null → ordinary single-row enqueue (allowed).
/// - both non-null → a grouped row; the id must be non-blank and the sequence
///   must be 1-based positive.
/// - exactly one non-null → rejected (a half-written grouping is a programming
///   error that would silently break cloud-push ordering later).
void _validateTransactionGroupMetadata({
  required String? transactionGroupId,
  required int? localSequence,
}) {
  final hasGroup = transactionGroupId != null;
  final hasSequence = localSequence != null;

  if (!hasGroup && !hasSequence) return;

  if (hasGroup != hasSequence) {
    throw ArgumentError(
      'sync_outbox transactionGroupId and localSequence must be set together '
      'or both omitted (got transactionGroupId=$transactionGroupId, '
      'localSequence=$localSequence).',
    );
  }

  if (transactionGroupId!.trim().isEmpty) {
    throw ArgumentError.value(
      transactionGroupId,
      'transactionGroupId',
      'must not be empty or blank when grouping outbox rows',
    );
  }
  if (localSequence! <= 0) {
    throw ArgumentError.value(
      localSequence,
      'localSequence',
      'must be a 1-based positive sequence within the transaction group',
    );
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

class LocalEntitySyncMetaRepository
    implements EntitySyncMetaRepository, EntitySyncMetaAckRepository {
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

  @override
  Future<int> markPushAcknowledged({
    required String entityType,
    required String localId,
    required String operation,
    required String syncedAtIso,
    int? newVersion,
  }) async {
    // Map the pushed operation to the pending status it should clear. Delete is
    // intentionally a no-op (deferred deleted-entity meta lifecycle).
    final SyncStatus? clearsFrom;
    switch (operation) {
      case 'create':
        clearsFrom = SyncStatus.pendingUpload;
        break;
      case 'update':
        clearsFrom = SyncStatus.pendingUpdate;
        break;
      default:
        clearsFrom = null;
    }
    if (clearsFrom == null) return 0;

    final db = await AppDatabase.database;
    final values = <String, Object?>{
      'sync_status': SyncStatus.synced.name,
      'last_synced_at': syncedAtIso,
      'version': ?newVersion,
    };
    // Only flip an existing row that is still in the expected pending state;
    // never fabricate a meta row and never touch synced/conflict/failed states.
    return db.update(
      _table,
      values,
      where: 'entity_type = ? AND local_id = ? AND sync_status = ?',
      whereArgs: [entityType, localId, clearsFrom.name],
    );
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
