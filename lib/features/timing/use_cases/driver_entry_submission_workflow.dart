import '../../../core/measure/measure_unit.dart';
import '../../../core/operations/operation_access_control.dart';
import '../../../core/operations/operation_actor_type.dart';
import '../../../data/models/timing_record.dart';

enum DriverEntryLinkFailureCode {
  linkNotFound,
  linkExpired,
  linkRevoked,
  linkExhausted,
  driverMismatch,
  deviceNotAllowed,
  permissionDenied,
  submissionNotFound,
  invalidSubmissionState,
}

class DriverEntryWorkflowException implements Exception {
  const DriverEntryWorkflowException(this.code, this.message);

  final DriverEntryLinkFailureCode code;
  final String message;

  @override
  String toString() => 'DriverEntryWorkflowException(${code.name}, $message)';
}

class DriverEntryLink {
  DriverEntryLink({
    required this.id,
    required this.driverId,
    required Iterable<int> allowedDeviceIds,
    required this.expiresAt,
    this.revokedAt,
    this.maxSubmissions = 1,
    this.usedSubmissions = 0,
  }) : allowedDeviceIds = Set.unmodifiable(allowedDeviceIds) {
    _requireNonEmpty(id, 'id');
    _requireNonEmpty(driverId, 'driverId');
    if (this.allowedDeviceIds.isEmpty) {
      throw ArgumentError.value(allowedDeviceIds, 'allowedDeviceIds');
    }
    if (maxSubmissions <= 0) {
      throw ArgumentError.value(maxSubmissions, 'maxSubmissions');
    }
    if (usedSubmissions < 0 || usedSubmissions > maxSubmissions) {
      throw ArgumentError.value(usedSubmissions, 'usedSubmissions');
    }
  }

  final String id;
  final String driverId;
  final Set<int> allowedDeviceIds;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final int maxSubmissions;
  final int usedSubmissions;

  bool get isRevoked => revokedAt != null;
  bool get isExhausted => usedSubmissions >= maxSubmissions;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);

  bool allowsDevice(int deviceId) => allowedDeviceIds.contains(deviceId);

  DriverEntryLink recordSubmissionUse() {
    return copyWith(usedSubmissions: usedSubmissions + 1);
  }

  DriverEntryLink revoke(DateTime at) {
    return copyWith(revokedAt: at);
  }

  DriverEntryLink copyWith({
    String? id,
    String? driverId,
    Iterable<int>? allowedDeviceIds,
    DateTime? expiresAt,
    Object? revokedAt = _sentinel,
    int? maxSubmissions,
    int? usedSubmissions,
  }) {
    return DriverEntryLink(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      allowedDeviceIds: allowedDeviceIds ?? this.allowedDeviceIds,
      expiresAt: expiresAt ?? this.expiresAt,
      revokedAt: identical(revokedAt, _sentinel)
          ? this.revokedAt
          : revokedAt as DateTime?,
      maxSubmissions: maxSubmissions ?? this.maxSubmissions,
      usedSubmissions: usedSubmissions ?? this.usedSubmissions,
    );
  }
}

class DriverEntrySubmissionDraft {
  DriverEntrySubmissionDraft({
    required this.deviceId,
    required this.workDate,
    required this.unit,
    required this.quantityScaled,
    required this.startMeter,
    required this.endMeter,
    this.isBreaking = false,
    this.note,
  }) {
    if (deviceId <= 0) throw ArgumentError.value(deviceId, 'deviceId');
    if (workDate <= 0) throw ArgumentError.value(workDate, 'workDate');
    if (quantityScaled <= 0) {
      throw ArgumentError.value(quantityScaled, 'quantityScaled');
    }
    if (endMeter < startMeter) {
      throw ArgumentError.value(endMeter, 'endMeter');
    }
  }

  final int deviceId;
  final int workDate;
  final MeasureUnit unit;
  final int quantityScaled;
  final double startMeter;
  final double endMeter;
  final bool isBreaking;
  final String? note;
}

enum DriverEntrySubmissionStatus { pending, approved, rejected }

class DriverEntrySubmission {
  DriverEntrySubmission({
    required this.id,
    required this.linkId,
    required this.driverId,
    required this.draft,
    required this.status,
    required this.submittedAt,
    this.approvedAt,
    this.approvedTimingRecordId,
  }) {
    _requireNonEmpty(id, 'id');
    _requireNonEmpty(linkId, 'linkId');
    _requireNonEmpty(driverId, 'driverId');
    if (status == DriverEntrySubmissionStatus.approved &&
        approvedTimingRecordId == null) {
      throw ArgumentError.value(
        approvedTimingRecordId,
        'approvedTimingRecordId',
      );
    }
  }

  final String id;
  final String linkId;
  final String driverId;
  final DriverEntrySubmissionDraft draft;
  final DriverEntrySubmissionStatus status;
  final DateTime submittedAt;
  final DateTime? approvedAt;
  final String? approvedTimingRecordId;

  DriverEntrySubmission asApproved({
    required DateTime approvedAt,
    required String timingRecordId,
  }) {
    return DriverEntrySubmission(
      id: id,
      linkId: linkId,
      driverId: driverId,
      draft: draft,
      status: DriverEntrySubmissionStatus.approved,
      submittedAt: submittedAt,
      approvedAt: approvedAt,
      approvedTimingRecordId: timingRecordId,
    );
  }
}

class DriverEntrySubmissionDriverView {
  const DriverEntrySubmissionDriverView({
    required this.id,
    required this.deviceId,
    required this.workDate,
    required this.unit,
    required this.quantityScaled,
    required this.status,
  });

  final String id;
  final int deviceId;
  final int workDate;
  final MeasureUnit unit;
  final int quantityScaled;
  final DriverEntrySubmissionStatus status;

  factory DriverEntrySubmissionDriverView.fromSubmission(
    DriverEntrySubmission submission,
  ) {
    final draft = submission.draft;
    return DriverEntrySubmissionDriverView(
      id: submission.id,
      deviceId: draft.deviceId,
      workDate: draft.workDate,
      unit: draft.unit,
      quantityScaled: draft.quantityScaled,
      status: submission.status,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'work_date': workDate,
      'unit': unit.dbValue,
      'quantity_scaled': quantityScaled,
      'status': status.name,
    };
  }
}

class DriverEntryApprovalRequest {
  const DriverEntryApprovalRequest({
    required this.submission,
    required this.approvedBy,
    required this.approvedAt,
  });

  final DriverEntrySubmission submission;
  final ActorContext approvedBy;
  final DateTime approvedAt;
}

abstract class DriverEntryLinkRepository {
  Future<DriverEntryLink?> findById(String id);
  Future<void> save(DriverEntryLink link);
}

abstract class DriverEntrySubmissionRepository {
  Future<void> insert(DriverEntrySubmission submission);
  Future<DriverEntrySubmission?> findById(String id);
  Future<void> save(DriverEntrySubmission submission);
}

abstract class DriverEntryApprovalGateway {
  Future<TimingRecord> createTimingRecord(DriverEntryApprovalRequest request);
}

class DriverEntrySubmissionWorkflow {
  DriverEntrySubmissionWorkflow({
    required DriverEntryLinkRepository linkRepository,
    required DriverEntrySubmissionRepository submissionRepository,
    required DriverEntryApprovalGateway approvalGateway,
    OperationPermissionPolicy permissionPolicy =
        const OperationPermissionPolicy(),
    String Function()? idGenerator,
  }) : _linkRepository = linkRepository,
       _submissionRepository = submissionRepository,
       _approvalGateway = approvalGateway,
       _permissionPolicy = permissionPolicy,
       _idGenerator = idGenerator ?? _defaultIdGenerator;

  final DriverEntryLinkRepository _linkRepository;
  final DriverEntrySubmissionRepository _submissionRepository;
  final DriverEntryApprovalGateway _approvalGateway;
  final OperationPermissionPolicy _permissionPolicy;
  final String Function() _idGenerator;

  Future<DriverEntrySubmission> submit({
    required ActorContext actor,
    required String linkId,
    required DriverEntrySubmissionDraft draft,
    required DateTime now,
  }) async {
    _requireDriverPreviewPermission(actor);
    final driverId = actor.actorId!;
    final link = await _requireUsableLink(
      linkId: linkId,
      driverId: driverId,
      deviceId: draft.deviceId,
      now: now,
    );

    final submission = DriverEntrySubmission(
      id: _idGenerator(),
      linkId: link.id,
      driverId: driverId,
      draft: draft,
      status: DriverEntrySubmissionStatus.pending,
      submittedAt: now,
    );
    await _submissionRepository.insert(submission);
    await _linkRepository.save(link.recordSubmissionUse());
    return submission;
  }

  Future<TimingRecord> approve({
    required ActorContext actor,
    required String submissionId,
    required DateTime now,
  }) async {
    _requireOwnerExecutePermission(actor);
    final submission = await _submissionRepository.findById(submissionId);
    if (submission == null) {
      throw const DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.submissionNotFound,
        'submission not found',
      );
    }
    if (submission.status != DriverEntrySubmissionStatus.pending) {
      throw const DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.invalidSubmissionState,
        'only pending submissions can be approved',
      );
    }

    final record = await _approvalGateway.createTimingRecord(
      DriverEntryApprovalRequest(
        submission: submission,
        approvedBy: actor,
        approvedAt: now,
      ),
    );
    final timingRecordId = record.id?.toString();
    if (timingRecordId == null || timingRecordId.isEmpty) {
      throw const DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.invalidSubmissionState,
        'approval gateway must return a persisted timing record id',
      );
    }
    await _submissionRepository.save(
      submission.asApproved(approvedAt: now, timingRecordId: timingRecordId),
    );
    return record;
  }

  Future<DriverEntryLink> revokeLink({
    required ActorContext actor,
    required String linkId,
    required DateTime now,
  }) async {
    _requireOwnerExecutePermission(actor);
    final link = await _linkRepository.findById(linkId);
    if (link == null) {
      throw const DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.linkNotFound,
        'entry link not found',
      );
    }
    final revoked = link.revoke(now);
    await _linkRepository.save(revoked);
    return revoked;
  }

  void _requireDriverPreviewPermission(ActorContext actor) {
    final decision = _permissionPolicy.canPerform(
      actor: actor,
      action: OperationPermissionAction.previewSaveTimingRecord,
    );
    if (!decision.allowed ||
        actor.effectiveActorType != OperationActorType.driver) {
      throw DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.permissionDenied,
        decision.reason,
      );
    }
  }

  void _requireOwnerExecutePermission(ActorContext actor) {
    final decision = _permissionPolicy.canPerform(
      actor: actor,
      action: OperationPermissionAction.executeSaveTimingRecord,
    );
    if (!decision.allowed ||
        actor.effectiveActorType != OperationActorType.owner) {
      throw DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.permissionDenied,
        decision.reason,
      );
    }
  }

  Future<DriverEntryLink> _requireUsableLink({
    required String linkId,
    required String driverId,
    required int deviceId,
    required DateTime now,
  }) async {
    final link = await _linkRepository.findById(linkId);
    if (link == null) {
      throw const DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.linkNotFound,
        'entry link not found',
      );
    }
    if (link.driverId != driverId) {
      throw const DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.driverMismatch,
        'entry link belongs to another driver',
      );
    }
    if (link.isRevoked) {
      throw const DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.linkRevoked,
        'entry link has been revoked',
      );
    }
    if (link.isExpiredAt(now)) {
      throw const DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.linkExpired,
        'entry link has expired',
      );
    }
    if (link.isExhausted) {
      throw const DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.linkExhausted,
        'entry link submission limit reached',
      );
    }
    if (!link.allowsDevice(deviceId)) {
      throw const DriverEntryWorkflowException(
        DriverEntryLinkFailureCode.deviceNotAllowed,
        'entry link does not allow this device',
      );
    }
    return link;
  }
}

String _defaultIdGenerator() {
  return 'driver-submission-${DateTime.now().microsecondsSinceEpoch}';
}

String _requireNonEmpty(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}

const Object _sentinel = Object();
