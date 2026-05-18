import 'sync_status.dart';

class EntitySyncMeta {
  const EntitySyncMeta({
    required this.entityType,
    required this.localId,
    required this.syncStatus,
    required this.version,
    required this.source,
    this.serverId,
    this.createdBy,
    this.updatedBy,
    this.deletedAt,
    this.payloadHash,
    this.lastSyncedAt,
    this.conflictReason,
  });

  final String entityType;
  final String localId;
  final String? serverId;
  final SyncStatus syncStatus;
  final int version;
  final String source;
  final String? createdBy;
  final String? updatedBy;
  final String? deletedAt;
  final String? payloadHash;
  final String? lastSyncedAt;
  final String? conflictReason;

  Map<String, Object?> toMap() {
    return {
      'entity_type': entityType,
      'local_id': localId,
      'server_id': serverId,
      'sync_status': syncStatus.name,
      'version': version,
      'source': source,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'deleted_at': deletedAt,
      'payload_hash': payloadHash,
      'last_synced_at': lastSyncedAt,
      'conflict_reason': conflictReason,
    };
  }

  factory EntitySyncMeta.fromMap(Map<String, Object?> map) {
    return EntitySyncMeta(
      entityType: map['entity_type'] as String,
      localId: map['local_id'] as String,
      serverId: map['server_id'] as String?,
      syncStatus: SyncStatus.parse(map['sync_status'] as String),
      version: (map['version'] as num).toInt(),
      source: map['source'] as String,
      createdBy: map['created_by'] as String?,
      updatedBy: map['updated_by'] as String?,
      deletedAt: map['deleted_at'] as String?,
      payloadHash: map['payload_hash'] as String?,
      lastSyncedAt: map['last_synced_at'] as String?,
      conflictReason: map['conflict_reason'] as String?,
    );
  }
}
