import 'package:sqflite/sqflite.dart';

import '../../../core/operations/operation_access_control.dart';
import '../../../data/models/project_write_off.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_actor.dart';
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
    ProjectWriteOff writeOff, {
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      writeOff: writeOff,
      operation: 'create',
      status: SyncStatus.pendingUpload,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> enqueueDelete(
    DatabaseExecutor executor,
    ProjectWriteOff writeOff, {
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      writeOff: writeOff,
      operation: 'delete',
      status: SyncStatus.pendingDelete,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> _enqueue(
    DatabaseExecutor executor, {
    required ProjectWriteOff writeOff,
    required String operation,
    required SyncStatus status,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) async {
    final entityId = writeOff.id;
    if (entityId.trim().isEmpty) {
      throw StateError('ProjectWriteOff sync enqueue id missing');
    }

    final resolvedActor = resolveSyncActor(actor);
    final entry = await _syncOutboxRepository.enqueueWithExecutor(
      executor,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: {
        'payload_schema_version': kSyncPayloadSchemaVersion,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'actor': syncActorPayload(resolvedActor),
        'record': writeOff.toMap(),
      },
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
    );
    await _entitySyncMetaRepository.upsertWithExecutor(
      executor,
      EntitySyncMeta(
        entityType: entityType,
        localId: entityId,
        syncStatus: status,
        version: 0,
        source: ownerAppSource,
        updatedBy: resolvedActor.actorId,
        payloadHash: entry.payloadHash,
      ),
    );
  }
}
