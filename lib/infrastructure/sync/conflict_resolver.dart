import 'entity_sync_meta.dart';
import 'sync_status.dart';

class ConflictDecision {
  const ConflictDecision({required this.status, this.reason});

  final SyncStatus status;
  final String? reason;
}

class ConflictResolver {
  const ConflictResolver();

  ConflictDecision resolve({
    required EntitySyncMeta local,
    required EntitySyncMeta remote,
  }) {
    if (local.deletedAt != null && remote.deletedAt == null) {
      return const ConflictDecision(
        status: SyncStatus.conflict,
        reason: 'local_deleted_remote_updated',
      );
    }
    if (remote.version > local.version &&
        local.syncStatus != SyncStatus.synced) {
      return const ConflictDecision(
        status: SyncStatus.conflict,
        reason: 'remote_newer_local_dirty',
      );
    }
    if (remote.payloadHash == local.payloadHash) {
      return const ConflictDecision(status: SyncStatus.synced);
    }
    return const ConflictDecision(
      status: SyncStatus.conflict,
      reason: 'payload_hash_mismatch',
    );
  }
}
