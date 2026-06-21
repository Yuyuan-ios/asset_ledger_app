import 'package:sqflite/sqflite.dart';

import '../../../core/operations/operation_access_control.dart';
import '../../../data/models/maintenance_record.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_actor.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';

class MaintenanceRecordSyncEnqueuer {
  const MaintenanceRecordSyncEnqueuer({
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
  }) : _syncOutboxRepository =
           syncOutboxRepository ?? const LocalSyncOutboxRepository(),
       _entitySyncMetaRepository =
           entitySyncMetaRepository ?? const LocalEntitySyncMetaRepository();

  final SyncOutboxRepository _syncOutboxRepository;
  final EntitySyncMetaRepository _entitySyncMetaRepository;

  static const String entityType = 'maintenance_record';
  static const String ownerAppSource = 'owner_app';

  Future<void> enqueueCreate(
    DatabaseExecutor executor, {
    required MaintenanceRecord record,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      record: record,
      operation: 'create',
      status: SyncStatus.pendingUpload,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> enqueueUpdate(
    DatabaseExecutor executor, {
    required MaintenanceRecord record,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      record: record,
      operation: 'update',
      status: SyncStatus.pendingUpdate,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> enqueueDelete(
    DatabaseExecutor executor, {
    required MaintenanceRecord record,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      record: record,
      operation: 'delete',
      status: SyncStatus.pendingDelete,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> _enqueue(
    DatabaseExecutor executor, {
    required MaintenanceRecord record,
    required String operation,
    required SyncStatus status,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) async {
    final id = record.id;
    if (id == null) {
      throw StateError('MaintenanceRecord sync enqueue id missing');
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
        'record': record.toMap(),
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
