import 'package:sqflite/sqflite.dart';

import '../../../core/operations/operation_access_control.dart';
import '../../../data/models/project.dart';
import '../../sync/entity_sync_meta.dart';
import '../../sync/sync_actor.dart';
import '../../sync/sync_repositories.dart';
import '../../sync/sync_status.dart';

/// Writes the row-level project lifecycle sync contract using the caller's
/// transaction executor.
///
/// R5.26-A: covers the full project lifecycle — create / update / delete — so
/// project rows reach the cloud with the same payload-schema-version + actor
/// traceability as the other entities. The create/delete enqueues mirror
/// [enqueueUpdate] exactly, differing only in `operation` and the
/// `entity_sync_meta` pending status.
///
/// Production wiring note: the only production project create path today is the
/// timing-save transaction (a brand-new project is resolved-or-created while
/// saving a timing record); see [enqueueCreate]'s caller in
/// `local_save_timing_record_with_impact_use_case.dart`. There is no production
/// project *delete* path (projects are never hard/soft deleted by any business
/// flow), so [enqueueDelete] is currently exercised only by tests and kept for
/// contract symmetry + R5.23 folding readiness + a future delete/archive or
/// restore-reconcile path. This is documented and locked by
/// `project_lifecycle_sync_coverage_invariant_test`.
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

  /// R5.26-A: project create outbox + `pendingUpload` meta.
  Future<void> enqueueCreate(
    DatabaseExecutor executor, {
    required Project project,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      project: project,
      operation: 'create',
      status: SyncStatus.pendingUpload,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  /// Settlement-status (and timing-edit revocation) project update outbox +
  /// `pendingUpdate` meta.
  Future<void> enqueueUpdate(
    DatabaseExecutor executor, {
    required Project project,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      project: project,
      operation: 'update',
      status: SyncStatus.pendingUpdate,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  /// R5.26-A: project delete outbox + `pendingDelete` meta.
  ///
  /// No production caller today (see class doc); the [project] snapshot should
  /// be the pre-delete authoritative row so the cloud can identify the entity.
  Future<void> enqueueDelete(
    DatabaseExecutor executor, {
    required Project project,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) {
    return _enqueue(
      executor,
      project: project,
      operation: 'delete',
      status: SyncStatus.pendingDelete,
      transactionGroupId: transactionGroupId,
      localSequence: localSequence,
      actor: actor,
    );
  }

  Future<void> _enqueue(
    DatabaseExecutor executor, {
    required Project project,
    required String operation,
    required SyncStatus status,
    String? transactionGroupId,
    int? localSequence,
    ActorContext? actor,
  }) async {
    final entityId = project.id;
    if (entityId.trim().isEmpty) {
      throw StateError('Project sync enqueue id missing');
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
        'record': project.toMap(),
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
