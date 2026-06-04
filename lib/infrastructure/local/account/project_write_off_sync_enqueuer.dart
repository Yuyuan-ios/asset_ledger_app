import 'package:sqflite/sqflite.dart';

import '../../../data/models/project_write_off.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';

/// Writes the row-level project_write_off sync contract using the caller's
/// transaction executor.
class ProjectWriteOffSyncEnqueuer {
  const ProjectWriteOffSyncEnqueuer({
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
  }) : _syncOutboxRepository =
           syncOutboxRepository ?? const LocalSyncOutboxRepository(),
       _entitySyncMetaRepository =
           entitySyncMetaRepository ?? const LocalEntitySyncMetaRepository();

  final SyncOutboxRepository _syncOutboxRepository;
  final EntitySyncMetaRepository _entitySyncMetaRepository;

  static const String entityType = 'project_write_off';
  static const String ownerAppSource = 'owner_app';

  Future<void> enqueueCreate(
    DatabaseExecutor executor,
    ProjectWriteOff writeOff,
  ) {
    return _enqueue(
      executor,
      writeOff: writeOff,
      operation: 'create',
      status: SyncStatus.pendingUpload,
    );
  }

  Future<void> enqueueDelete(
    DatabaseExecutor executor,
    ProjectWriteOff writeOff,
  ) {
    return _enqueue(
      executor,
      writeOff: writeOff,
      operation: 'delete',
      status: SyncStatus.pendingDelete,
    );
  }

  Future<void> _enqueue(
    DatabaseExecutor executor, {
    required ProjectWriteOff writeOff,
    required String operation,
    required SyncStatus status,
  }) async {
    final entityId = writeOff.id;
    if (entityId.trim().isEmpty) {
      throw StateError('ProjectWriteOff sync enqueue id missing');
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
        'record': writeOff.toMap(),
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
