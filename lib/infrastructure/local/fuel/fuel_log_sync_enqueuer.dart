import 'package:sqflite/sqflite.dart';

import '../../../core/operations/operation_access_control.dart';
import '../../../data/models/fuel_log.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_actor.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';

class FuelLogSyncEnqueuer {
  const FuelLogSyncEnqueuer({
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
  }) : _syncOutboxRepository =
           syncOutboxRepository ?? const LocalSyncOutboxRepository(),
       _entitySyncMetaRepository =
           entitySyncMetaRepository ?? const LocalEntitySyncMetaRepository();

  final SyncOutboxRepository _syncOutboxRepository;
  final EntitySyncMetaRepository _entitySyncMetaRepository;

  static const String entityType = 'fuel_log';
  static const String ownerAppSource = 'owner_app';

  Future<void> enqueueCreate(
    DatabaseExecutor executor, {
    required FuelLog log,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      log: log,
      operation: 'create',
      status: SyncStatus.pendingUpload,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> enqueueUpdate(
    DatabaseExecutor executor, {
    required FuelLog log,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      log: log,
      operation: 'update',
      status: SyncStatus.pendingUpdate,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> enqueueDelete(
    DatabaseExecutor executor, {
    required FuelLog log,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      log: log,
      operation: 'delete',
      status: SyncStatus.pendingDelete,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> _enqueue(
    DatabaseExecutor executor, {
    required FuelLog log,
    required String operation,
    required SyncStatus status,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) async {
    final id = log.id;
    if (id == null) {
      throw StateError('FuelLog sync enqueue id missing');
    }
    final entityId = id.toString();
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
        'record': log.toMap(),
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
