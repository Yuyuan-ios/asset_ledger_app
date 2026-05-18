import '../sync/sync_status.dart';

class CloudWorkRecordDto {
  const CloudWorkRecordDto({
    required this.localId,
    required this.ownerId,
    required this.workDate,
    required this.workType,
    required this.hoursMilli,
    required this.unitPriceFen,
    required this.amountFen,
    required this.status,
    required this.source,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.payloadHash,
    this.serverId,
    this.driverId,
    this.projectId,
    this.deviceId,
    this.createdBy,
    this.updatedBy,
    this.deletedAt,
    this.originFingerprint,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectReason,
  });

  final String? serverId;
  final String localId;
  final String ownerId;
  final String? driverId;
  final String? projectId;
  final String? deviceId;
  final int workDate;
  final String workType;
  final int hoursMilli;
  final int unitPriceFen;
  final int amountFen;
  final WorkRecordReviewStatus status;
  final String source;
  final int version;
  final String? createdBy;
  final String? updatedBy;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final String payloadHash;
  final String? originFingerprint;
  final String? reviewedBy;
  final String? reviewedAt;
  final String? rejectReason;

  Map<String, Object?> toMap() {
    return {
      'server_id': serverId,
      'local_id': localId,
      'owner_id': ownerId,
      'driver_id': driverId,
      'project_id': projectId,
      'device_id': deviceId,
      'work_date': workDate,
      'work_type': workType,
      'hours_milli': hoursMilli,
      'unit_price_fen': unitPriceFen,
      'amount_fen': amountFen,
      'status': status.name,
      'source': source,
      'version': version,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
      'payload_hash': payloadHash,
      'origin_fingerprint': originFingerprint,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt,
      'reject_reason': rejectReason,
    };
  }

  factory CloudWorkRecordDto.fromMap(Map<String, Object?> map) {
    return CloudWorkRecordDto(
      serverId: map['server_id'] as String?,
      localId: map['local_id'] as String,
      ownerId: map['owner_id'] as String,
      driverId: map['driver_id'] as String?,
      projectId: map['project_id'] as String?,
      deviceId: map['device_id'] as String?,
      workDate: (map['work_date'] as num).toInt(),
      workType: map['work_type'] as String,
      hoursMilli: (map['hours_milli'] as num).toInt(),
      unitPriceFen: (map['unit_price_fen'] as num).toInt(),
      amountFen: (map['amount_fen'] as num).toInt(),
      status: WorkRecordReviewStatus.parse(map['status'] as String),
      source: map['source'] as String,
      version: (map['version'] as num).toInt(),
      createdBy: map['created_by'] as String?,
      updatedBy: map['updated_by'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      deletedAt: map['deleted_at'] as String?,
      payloadHash: map['payload_hash'] as String,
      originFingerprint: map['origin_fingerprint'] as String?,
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: map['reviewed_at'] as String?,
      rejectReason: map['reject_reason'] as String?,
    );
  }
}
