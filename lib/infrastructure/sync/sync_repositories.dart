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

  @override
  Future<void> upsert(EntitySyncMeta meta) async {
    final db = await AppDatabase.database;
    await upsertWithExecutor(db, meta);
  }

  @override
  Future<void> upsertWithExecutor(
    DatabaseExecutor executor,
    EntitySyncMeta meta,
  ) async {
    await executor.insert(
      'entity_sync_meta',
      meta.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<EntitySyncMeta?> find({
    required String entityType,
    required String localId,
  }) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'entity_sync_meta',
      where: 'entity_type = ? AND local_id = ?',
      whereArgs: [entityType, localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return EntitySyncMeta.fromMap(rows.single);
  }
}
