import 'package:sqflite/sqflite.dart';

import '../../../data/models/project.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';

/// Writes the row-level project update sync contract using the caller's
/// transaction executor.
///
/// This helper is a settlement-status sync building block. It does not claim
/// full project lifecycle create/delete coverage.
class ProjectSyncEnqueuer {
  const ProjectSyncEnqueuer({
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
  }) : _syncOutboxRepository =
           syncOutboxRepository ?? const LocalSyncOutboxRepository(),
       _entitySyncMetaRepository =
           entitySyncMetaRepository ?? const LocalEntitySyncMetaRepository();

  final SyncOutboxRepository _syncOutboxRepository;
  final EntitySyncMetaRepository _entitySyncMetaRepository;

  static const String entityType = 'project';
  static const String ownerAppSource = 'owner_app';

  Future<void> enqueueUpdate(
    DatabaseExecutor executor, {
    required Project project,
  }) async {
    final entityId = project.id;
    if (entityId.trim().isEmpty) {
      throw StateError('Project sync enqueue id missing');
    }

    final entry = await _syncOutboxRepository.enqueueWithExecutor(
      executor,
      entityType: entityType,
      entityId: entityId,
      operation: 'update',
      payload: {
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': 'update',
        'record': project.toMap(),
      },
    );
    await _entitySyncMetaRepository.upsertWithExecutor(
      executor,
      EntitySyncMeta(
        entityType: entityType,
        localId: entityId,
        syncStatus: SyncStatus.pendingUpdate,
        version: 0,
        source: ownerAppSource,
        payloadHash: entry.payloadHash,
      ),
    );
  }
}
