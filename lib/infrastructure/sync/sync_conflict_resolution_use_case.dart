import '../local/timing/timing_record_sync_enqueuer.dart';
import '../../data/db/database.dart';
import '../../data/repositories/timing_repository.dart';
import 'entity_sync_meta.dart';
import 'remote_change_applier.dart';
import 'sync_conflict_repository.dart';
import 'sync_repositories.dart';
import 'sync_status.dart';

class SyncConflictResolutionUseCase {
  SyncConflictResolutionUseCase({
    SyncConflictRepository conflictRepository =
        const LocalSyncConflictRepository(),
    RemoteChangeApplier remoteChangeApplier =
        const TimingRecordRemoteChangeApplier(),
    SqfliteTimingRepository? timingRepository,
    EntitySyncMetaRepository entitySyncMetaRepository =
        const LocalEntitySyncMetaRepository(),
    TimingRecordSyncEnqueuer timingRecordSyncEnqueuer =
        const TimingRecordSyncEnqueuer(),
    DateTime Function()? now,
  }) : _conflictRepository = conflictRepository,
       _remoteChangeApplier = remoteChangeApplier,
       _timingRepository = timingRepository ?? SqfliteTimingRepository(),
       _entitySyncMetaRepository = entitySyncMetaRepository,
       _timingRecordSyncEnqueuer = timingRecordSyncEnqueuer,
       _now = now ?? DateTime.now;

  final SyncConflictRepository _conflictRepository;
  final RemoteChangeApplier _remoteChangeApplier;
  final SqfliteTimingRepository _timingRepository;
  final EntitySyncMetaRepository _entitySyncMetaRepository;
  final TimingRecordSyncEnqueuer _timingRecordSyncEnqueuer;
  final DateTime Function() _now;

  Future<void> useRemote(SyncConflict conflict) async {
    _ensurePendingTimingConflict(conflict);
    await AppDatabase.inTransaction<void>((txn) async {
      await _remoteChangeApplier.applyWithExecutor(
        txn,
        conflict.toRemoteChange(),
        now: _now(),
      );
      await txn.delete(
        'sync_outbox',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [conflict.entityType, conflict.entityId],
      );
      await _conflictRepository.markResolvedWithExecutor(
        txn,
        id: conflict.id,
        resolution: SyncConflictResolution.remote,
        now: _now(),
      );
    });
  }

  Future<void> useLocal(SyncConflict conflict) async {
    _ensurePendingTimingConflict(conflict);
    final id = int.tryParse(conflict.entityId);
    if (id == null || id <= 0) {
      throw StateError('Timing conflict entity id is invalid');
    }

    await AppDatabase.inTransaction<void>((txn) async {
      final local = await _timingRepository.findByIdWithExecutor(txn, id);
      if (local == null) {
        throw StateError('Local timing record no longer exists');
      }
      await _entitySyncMetaRepository.upsertWithExecutor(
        txn,
        EntitySyncMeta(
          entityType: conflict.entityType,
          localId: conflict.entityId,
          serverId: conflict.entityId,
          syncStatus: SyncStatus.synced,
          version: conflict.remoteNewVersion,
          source: TimingRecordSyncEnqueuer.ownerAppSource,
        ),
      );
      await _timingRecordSyncEnqueuer.enqueueUpdate(
        txn,
        record: local,
        existingRecord: local,
      );
      await _conflictRepository.markResolvedWithExecutor(
        txn,
        id: conflict.id,
        resolution: SyncConflictResolution.local,
        now: _now(),
      );
    });
  }

  void _ensurePendingTimingConflict(SyncConflict conflict) {
    if (conflict.status != SyncConflictStatus.pending) {
      throw StateError('Sync conflict is already resolved');
    }
    if (conflict.entityType != TimingRecordRemoteChangeApplier.entityType) {
      throw UnsupportedError(
        'Unsupported conflict entity: ${conflict.entityType}',
      );
    }
  }
}
