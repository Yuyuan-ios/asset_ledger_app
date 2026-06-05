import 'sync_status.dart';

class SyncOutboxEntry {
  const SyncOutboxEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.payloadHash,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
    this.transactionGroupId,
    this.localSequence,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final String payloadJson;
  final String payloadHash;
  final SyncOutboxStatus status;
  final int retryCount;
  final String? lastError;

  /// R5.22-A: id shared by every outbox row produced inside one business
  /// transaction. Null for ordinary single-row enqueues. Outbox metadata only —
  /// never part of [payloadJson].
  final String? transactionGroupId;

  /// R5.22-A: 1-based local causal order of this row within
  /// [transactionGroupId]. Null when [transactionGroupId] is null.
  final int? localSequence;

  final String createdAt;
  final String updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload_json': payloadJson,
      'payload_hash': payloadHash,
      'status': status.name,
      'retry_count': retryCount,
      'last_error': lastError,
      'transaction_group_id': transactionGroupId,
      'local_sequence': localSequence,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory SyncOutboxEntry.fromMap(Map<String, Object?> map) {
    return SyncOutboxEntry(
      id: map['id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      operation: map['operation'] as String,
      payloadJson: map['payload_json'] as String,
      payloadHash: map['payload_hash'] as String,
      status: SyncOutboxStatus.parse(map['status'] as String),
      retryCount: (map['retry_count'] as num).toInt(),
      lastError: map['last_error'] as String?,
      transactionGroupId: map['transaction_group_id'] as String?,
      localSequence: (map['local_sequence'] as num?)?.toInt(),
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
