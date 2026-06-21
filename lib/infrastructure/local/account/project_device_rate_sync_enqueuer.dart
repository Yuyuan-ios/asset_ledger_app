import 'package:sqflite/sqflite.dart';

import '../../../core/operations/operation_access_control.dart';
import '../../../data/models/project_device_rate.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_actor.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';

class ProjectDeviceRateSyncEnqueuer {
  const ProjectDeviceRateSyncEnqueuer({
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
  }) : _syncOutboxRepository =
           syncOutboxRepository ?? const LocalSyncOutboxRepository(),
       _entitySyncMetaRepository =
           entitySyncMetaRepository ?? const LocalEntitySyncMetaRepository();

  final SyncOutboxRepository _syncOutboxRepository;
  final EntitySyncMetaRepository _entitySyncMetaRepository;

  static const String entityType = 'project_device_rate';
  static const String ownerAppSource = 'owner_app';

  static String entityIdFor(ProjectDeviceRate rate) {
    return '${rate.effectiveProjectId}:${rate.deviceId}:'
        '${rate.isBreaking ? 1 : 0}';
  }

  Future<void> enqueueUpsert(
    DatabaseExecutor executor, {
    required ProjectDeviceRate rate,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      rate: rate,
      operation: 'update',
      status: SyncStatus.pendingUpdate,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> enqueueDelete(
    DatabaseExecutor executor, {
    required ProjectDeviceRate rate,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      rate: rate,
      operation: 'delete',
      status: SyncStatus.pendingDelete,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> _enqueue(
    DatabaseExecutor executor, {
    required ProjectDeviceRate rate,
    required String operation,
    required SyncStatus status,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) async {
    final entityId = entityIdFor(rate);
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
        'record': rate.toMap(),
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
