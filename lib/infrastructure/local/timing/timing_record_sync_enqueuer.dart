import 'package:sqflite/sqflite.dart';

import '../../../core/operations/operation_access_control.dart';
import '../../../data/models/timing_record.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_actor.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';

class TimingRecordSyncEnqueuer {
  const TimingRecordSyncEnqueuer({
    SyncOutboxRepository? syncOutboxRepository,
    EntitySyncMetaRepository? entitySyncMetaRepository,
  }) : _syncOutboxRepository =
           syncOutboxRepository ?? const LocalSyncOutboxRepository(),
       _entitySyncMetaRepository =
           entitySyncMetaRepository ?? const LocalEntitySyncMetaRepository();

  final SyncOutboxRepository _syncOutboxRepository;
  final EntitySyncMetaRepository _entitySyncMetaRepository;

  static const String entityType = 'timing_record';
  static const String ownerAppSource = 'owner_app';

  Future<void> enqueueCreate(
    DatabaseExecutor executor, {
    required TimingRecord record,
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
    required TimingRecord record,
    TimingRecord? existingRecord,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      record: record,
      operation: 'update',
      status: SyncStatus.pendingUpdate,
      existingRecord: existingRecord,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> enqueueDelete(
    DatabaseExecutor executor, {
    required TimingRecord record,
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
    required TimingRecord record,
    required String operation,
    required SyncStatus status,
    TimingRecord? existingRecord,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) async {
    final id = record.id;
    if (id == null) {
      throw StateError('TimingRecord sync enqueue id missing');
    }
    final entityId = id.toString();
    final isUpdate = operation == 'update';
    final includeNullAllocationCutoffDate =
        isUpdate &&
        record.allocationCutoffDate == null &&
        existingRecord?.allocationCutoffDate != null;
    final includeNullDisplayEndDate =
        isUpdate &&
        record.displayEndDate == null &&
        existingRecord?.displayEndDate != null;

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
        'record': record.toMap(
          includeNullAllocationCutoffDate: includeNullAllocationCutoffDate,
          includeNullDisplayEndDate: includeNullDisplayEndDate,
        ),
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
