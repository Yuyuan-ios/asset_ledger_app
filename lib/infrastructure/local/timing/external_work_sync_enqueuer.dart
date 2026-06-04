import 'package:sqflite/sqflite.dart';

import '../../../data/models/external_work_record.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';

/// Writes the row-level external_work_record sync contract using the caller's
/// transaction executor.
///
/// This helper is a reusable sync building block. Production ExternalWork
/// import/link/unlink/delete/reset paths remain deferred until they explicitly
/// call this helper inside their existing business transactions.
class ExternalWorkSyncEnqueuer {
  const ExternalWorkSyncEnqueuer({
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
  }) : _syncOutboxRepository =
           syncOutboxRepository ?? const LocalSyncOutboxRepository(),
       _entitySyncMetaRepository =
           entitySyncMetaRepository ?? const LocalEntitySyncMetaRepository();

  final SyncOutboxRepository _syncOutboxRepository;
  final EntitySyncMetaRepository _entitySyncMetaRepository;

  static const String entityType = 'external_work_record';
  static const String ownerAppSource = 'owner_app';

  Future<void> enqueueCreate(
    DatabaseExecutor executor, {
    required ExternalWorkRecord record,
  }) {
    return _enqueue(
      executor,
      record: record,
      operation: 'create',
      status: SyncStatus.pendingUpload,
    );
  }

  Future<void> enqueueUpdate(
    DatabaseExecutor executor, {
    required ExternalWorkRecord record,
  }) {
    return _enqueue(
      executor,
      record: record,
      operation: 'update',
      status: SyncStatus.pendingUpdate,
    );
  }

  Future<void> enqueueDelete(
    DatabaseExecutor executor, {
    required ExternalWorkRecord record,
  }) {
    return _enqueue(
      executor,
      record: record,
      operation: 'delete',
      status: SyncStatus.pendingDelete,
    );
  }

  Future<void> _enqueue(
    DatabaseExecutor executor, {
    required ExternalWorkRecord record,
    required String operation,
    required SyncStatus status,
  }) async {
    final entityId = record.id;
    if (entityId.trim().isEmpty) {
      throw StateError('ExternalWorkRecord sync enqueue id missing');
    }

    final entry = await _syncOutboxRepository.enqueueWithExecutor(
      executor,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: {
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'record': record.toMap(),
      },
    );
    await _entitySyncMetaRepository.upsertWithExecutor(
      executor,
      EntitySyncMeta(
        entityType: entityType,
        localId: entityId,
        syncStatus: status,
        version: 0,
        source: ownerAppSource,
        payloadHash: entry.payloadHash,
      ),
    );
  }
}
