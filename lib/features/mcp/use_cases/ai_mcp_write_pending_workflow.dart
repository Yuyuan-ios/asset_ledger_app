import '../../../core/operations/operation_access_control.dart';
import '../../../core/operations/operation_actor_scope.dart';
import '../../../core/operations/operation_actor_type.dart';

enum AiMcpWriteSubmissionStatus { pending, approved, rejected }

enum AiMcpWriteAuditEvent {
  pendingSubmitted,
  approveSucceeded,
  rejected,
  denied,
}

enum AiMcpWriteFailureCode {
  permissionDenied,
  scopeExpired,
  emptyCommand,
  deviceOutOfScope,
  submissionNotFound,
  invalidSubmissionState,
  approvalGatewayFailed,
}

class AiMcpWriteWorkflowException implements Exception {
  const AiMcpWriteWorkflowException(this.code, this.message);

  final AiMcpWriteFailureCode code;
  final String message;

  @override
  String toString() => 'AiMcpWriteWorkflowException(${code.name}, $message)';
}

class AiMcpWriteContext {
  const AiMcpWriteContext({
    required this.actor,
    required this.scope,
    required this.now,
  });

  final ActorContext actor;
  final ActorScope scope;
  final DateTime now;
}

class AiMcpNaturalLanguageWriteRequest {
  AiMcpNaturalLanguageWriteRequest({
    required this.commandText,
    this.clientRequestId,
  }) {
    _requireNonEmpty(commandText, 'commandText');
  }

  final String commandText;
  final String? clientRequestId;
}

class AiMcpStructuredTimingSubmission {
  AiMcpStructuredTimingSubmission({
    required this.deviceId,
    required this.deviceLabel,
    required this.projectLabel,
    required this.workDate,
    required this.unit,
    required this.quantityScaled,
    this.startMeter,
    this.endMeter,
    this.note,
  }) {
    _requireNonEmpty(deviceId, 'deviceId');
    _requireNonEmpty(deviceLabel, 'deviceLabel');
    _requireNonEmpty(projectLabel, 'projectLabel');
    _requireNonEmpty(unit, 'unit');
    if (workDate <= 0) throw ArgumentError.value(workDate, 'workDate');
    if (quantityScaled <= 0) {
      throw ArgumentError.value(quantityScaled, 'quantityScaled');
    }
    final start = startMeter;
    final end = endMeter;
    if (start != null && end != null && end < start) {
      throw ArgumentError.value(end, 'endMeter');
    }
  }

  final String deviceId;
  final String deviceLabel;
  final String projectLabel;
  final int workDate;
  final String unit;
  final int quantityScaled;
  final int? startMeter;
  final int? endMeter;
  final String? note;

  Map<String, Object?> toReviewMap() {
    return {
      'device_label': deviceLabel,
      'project_label': projectLabel,
      'work_date': workDate,
      'unit': unit,
      'quantity_scaled': quantityScaled,
      if (startMeter != null) 'start_meter': startMeter,
      if (endMeter != null) 'end_meter': endMeter,
      if (_hasText(note)) 'note': note,
    };
  }
}

class AiMcpPendingSubmission {
  AiMcpPendingSubmission({
    required this.id,
    required this.requestText,
    required this.structured,
    required this.requestedBy,
    required this.status,
    required this.submittedAt,
    this.clientRequestId,
    this.approvedAt,
    this.approvedBy,
    this.approvedRecordId,
    this.rejectedAt,
    this.rejectedBy,
    this.rejectionReason,
  }) {
    _requireNonEmpty(id, 'id');
    _requireNonEmpty(requestText, 'requestText');
    if (status == AiMcpWriteSubmissionStatus.approved &&
        !_hasText(approvedRecordId)) {
      throw ArgumentError.value(approvedRecordId, 'approvedRecordId');
    }
  }

  final String id;
  final String requestText;
  final String? clientRequestId;
  final AiMcpStructuredTimingSubmission structured;
  final ActorContext requestedBy;
  final AiMcpWriteSubmissionStatus status;
  final DateTime submittedAt;
  final DateTime? approvedAt;
  final ActorContext? approvedBy;
  final String? approvedRecordId;
  final DateTime? rejectedAt;
  final ActorContext? rejectedBy;
  final String? rejectionReason;

  AiMcpPendingSubmission asApproved({
    required DateTime approvedAt,
    required ActorContext approvedBy,
    required String recordId,
  }) {
    return AiMcpPendingSubmission(
      id: id,
      requestText: requestText,
      clientRequestId: clientRequestId,
      structured: structured,
      requestedBy: requestedBy,
      status: AiMcpWriteSubmissionStatus.approved,
      submittedAt: submittedAt,
      approvedAt: approvedAt,
      approvedBy: approvedBy,
      approvedRecordId: _requireNonEmpty(recordId, 'recordId'),
    );
  }

  AiMcpPendingSubmission asRejected({
    required DateTime rejectedAt,
    required ActorContext rejectedBy,
    required String reason,
  }) {
    return AiMcpPendingSubmission(
      id: id,
      requestText: requestText,
      clientRequestId: clientRequestId,
      structured: structured,
      requestedBy: requestedBy,
      status: AiMcpWriteSubmissionStatus.rejected,
      submittedAt: submittedAt,
      rejectedAt: rejectedAt,
      rejectedBy: rejectedBy,
      rejectionReason: _requireNonEmpty(reason, 'reason'),
    );
  }

  Map<String, Object?> toReviewMap() {
    return {
      'id': id,
      'status': status.name,
      'request_text': requestText,
      if (_hasText(clientRequestId)) 'client_request_id': clientRequestId,
      'submitted_at': submittedAt.toIso8601String(),
      'structured_submission': structured.toReviewMap(),
    };
  }
}

class AiMcpWriteApprovalRequest {
  const AiMcpWriteApprovalRequest({
    required this.submission,
    required this.approvedBy,
    required this.approvedAt,
  });

  final AiMcpPendingSubmission submission;
  final ActorContext approvedBy;
  final DateTime approvedAt;
}

class AiMcpApprovedWriteResult {
  AiMcpApprovedWriteResult({required this.recordId}) {
    _requireNonEmpty(recordId, 'recordId');
  }

  final String recordId;
}

class AiMcpWriteAuditLog {
  AiMcpWriteAuditLog({
    required this.id,
    required this.event,
    required this.actorType,
    required this.at,
    required Map<String, Object?> details,
    this.actorId,
    this.submissionId,
  }) : details = Map<String, Object?>.unmodifiable(details) {
    _requireNonEmpty(id, 'id');
  }

  final String id;
  final AiMcpWriteAuditEvent event;
  final OperationActorType actorType;
  final String? actorId;
  final String? submissionId;
  final DateTime at;
  final Map<String, Object?> details;
}

abstract class AiMcpWriteParser {
  Future<AiMcpStructuredTimingSubmission> parse(
    AiMcpNaturalLanguageWriteRequest request,
  );
}

abstract class AiMcpPendingSubmissionRepository {
  Future<void> insert(AiMcpPendingSubmission submission);
  Future<AiMcpPendingSubmission?> findById(String id);
  Future<void> save(AiMcpPendingSubmission submission);
}

abstract class AiMcpWriteApprovalGateway {
  Future<AiMcpApprovedWriteResult> createLedgerEntry(
    AiMcpWriteApprovalRequest request,
  );
}

abstract class AiMcpWriteAuditSink {
  Future<void> append(AiMcpWriteAuditLog log);
}

class AiMcpWritePendingWorkflow {
  AiMcpWritePendingWorkflow({
    required AiMcpWriteParser parser,
    required AiMcpPendingSubmissionRepository submissionRepository,
    required AiMcpWriteApprovalGateway approvalGateway,
    required AiMcpWriteAuditSink auditSink,
    OperationPermissionPolicy permissionPolicy =
        const OperationPermissionPolicy(),
    OperationScopePolicy scopePolicy = const OperationScopePolicy(),
    String Function()? idGenerator,
    String Function()? auditIdGenerator,
  }) : _parser = parser,
       _submissionRepository = submissionRepository,
       _approvalGateway = approvalGateway,
       _auditSink = auditSink,
       _permissionPolicy = permissionPolicy,
       _scopePolicy = scopePolicy,
       _idGenerator = idGenerator ?? _defaultSubmissionId,
       _auditIdGenerator = auditIdGenerator ?? _defaultAuditId;

  final AiMcpWriteParser _parser;
  final AiMcpPendingSubmissionRepository _submissionRepository;
  final AiMcpWriteApprovalGateway _approvalGateway;
  final AiMcpWriteAuditSink _auditSink;
  final OperationPermissionPolicy _permissionPolicy;
  final OperationScopePolicy _scopePolicy;
  final String Function() _idGenerator;
  final String Function() _auditIdGenerator;

  Future<AiMcpPendingSubmission> submitNaturalLanguage({
    required AiMcpWriteContext context,
    required AiMcpNaturalLanguageWriteRequest request,
  }) async {
    _requireActiveScope(context);
    await _requireAiPreviewActor(context.actor, context.now);

    final structured = await _parser.parse(request);
    await _requireDeviceScope(context, structured.deviceId);

    final submission = AiMcpPendingSubmission(
      id: _idGenerator(),
      requestText: request.commandText,
      clientRequestId: request.clientRequestId,
      structured: structured,
      requestedBy: context.actor,
      status: AiMcpWriteSubmissionStatus.pending,
      submittedAt: context.now,
    );
    await _submissionRepository.insert(submission);
    await _audit(
      event: AiMcpWriteAuditEvent.pendingSubmitted,
      actor: context.actor,
      submissionId: submission.id,
      at: context.now,
      details: {
        'client_request_id': request.clientRequestId,
        'device_label': structured.deviceLabel,
        'project_label': structured.projectLabel,
        'unit': structured.unit,
        'quantity_scaled': structured.quantityScaled,
      },
    );
    return submission;
  }

  Future<AiMcpApprovedWriteResult> approve({
    required ActorContext actor,
    required String submissionId,
    required DateTime now,
  }) async {
    await _requireOwnerExecuteActor(actor, now, submissionId: submissionId);
    final submission = await _requirePendingSubmission(submissionId);
    final result = await _approvalGateway.createLedgerEntry(
      AiMcpWriteApprovalRequest(
        submission: submission,
        approvedBy: actor,
        approvedAt: now,
      ),
    );
    if (!_hasText(result.recordId)) {
      throw const AiMcpWriteWorkflowException(
        AiMcpWriteFailureCode.approvalGatewayFailed,
        'approval gateway must return a persisted record id',
      );
    }
    await _submissionRepository.save(
      submission.asApproved(
        approvedAt: now,
        approvedBy: actor,
        recordId: result.recordId,
      ),
    );
    await _audit(
      event: AiMcpWriteAuditEvent.approveSucceeded,
      actor: actor,
      submissionId: submission.id,
      at: now,
      details: {'record_id': result.recordId},
    );
    return result;
  }

  Future<AiMcpPendingSubmission> reject({
    required ActorContext actor,
    required String submissionId,
    required String reason,
    required DateTime now,
  }) async {
    await _requireOwnerExecuteActor(actor, now, submissionId: submissionId);
    final submission = await _requirePendingSubmission(submissionId);
    final rejected = submission.asRejected(
      rejectedAt: now,
      rejectedBy: actor,
      reason: reason,
    );
    await _submissionRepository.save(rejected);
    await _audit(
      event: AiMcpWriteAuditEvent.rejected,
      actor: actor,
      submissionId: submission.id,
      at: now,
      details: {'reason': reason},
    );
    return rejected;
  }

  void _requireActiveScope(AiMcpWriteContext context) {
    if (context.scope.isExpired(context.now)) {
      throw const AiMcpWriteWorkflowException(
        AiMcpWriteFailureCode.scopeExpired,
        'actor scope has expired',
      );
    }
  }

  Future<void> _requireAiPreviewActor(
    ActorContext actor,
    DateTime now, {
    String? submissionId,
  }) async {
    final decision = _permissionPolicy.canPerform(
      actor: actor,
      action: OperationPermissionAction.previewSaveTimingRecord,
    );
    final isDelegatedOwnerAgent =
        actor.isAgent &&
        actor.delegatedActorType == OperationActorType.owner &&
        _hasText(actor.delegatedActorId);
    if (!decision.allowed || !isDelegatedOwnerAgent) {
      await _auditDenied(
        actor: actor,
        at: now,
        submissionId: submissionId,
        reason: isDelegatedOwnerAgent
            ? decision.reason
            : 'AI/MCP write submit requires delegated owner agent scope',
      );
      throw const AiMcpWriteWorkflowException(
        AiMcpWriteFailureCode.permissionDenied,
        'AI/MCP write submit requires delegated owner agent scope',
      );
    }
  }

  Future<void> _requireOwnerExecuteActor(
    ActorContext actor,
    DateTime now, {
    String? submissionId,
  }) async {
    final decision = _permissionPolicy.canPerform(
      actor: actor,
      action: OperationPermissionAction.executeSaveTimingRecord,
    );
    if (!decision.allowed || actor.actorType != OperationActorType.owner) {
      await _auditDenied(
        actor: actor,
        at: now,
        submissionId: submissionId,
        reason: actor.actorType == OperationActorType.owner
            ? decision.reason
            : 'AI/MCP approval requires direct owner confirmation',
      );
      throw const AiMcpWriteWorkflowException(
        AiMcpWriteFailureCode.permissionDenied,
        'AI/MCP approval requires direct owner confirmation',
      );
    }
  }

  Future<void> _requireDeviceScope(
    AiMcpWriteContext context,
    String deviceId,
  ) async {
    final decision = _scopePolicy.canAccessResource(
      actor: context.actor,
      scope: context.scope,
      resourceType: OperationResourceType.device,
      resourceId: deviceId,
      now: context.now,
    );
    if (!decision.allowed) {
      await _auditDenied(
        actor: context.actor,
        at: context.now,
        reason: decision.reason,
      );
      throw AiMcpWriteWorkflowException(
        AiMcpWriteFailureCode.deviceOutOfScope,
        decision.reason,
      );
    }
  }

  Future<AiMcpPendingSubmission> _requirePendingSubmission(
    String submissionId,
  ) async {
    final submission = await _submissionRepository.findById(submissionId);
    if (submission == null) {
      throw const AiMcpWriteWorkflowException(
        AiMcpWriteFailureCode.submissionNotFound,
        'submission not found',
      );
    }
    if (submission.status != AiMcpWriteSubmissionStatus.pending) {
      throw const AiMcpWriteWorkflowException(
        AiMcpWriteFailureCode.invalidSubmissionState,
        'only pending submissions can be approved or rejected',
      );
    }
    return submission;
  }

  Future<void> _auditDenied({
    required ActorContext actor,
    required DateTime at,
    required String reason,
    String? submissionId,
  }) {
    return _audit(
      event: AiMcpWriteAuditEvent.denied,
      actor: actor,
      submissionId: submissionId,
      at: at,
      details: {'reason': reason},
    );
  }

  Future<void> _audit({
    required AiMcpWriteAuditEvent event,
    required ActorContext actor,
    required String? submissionId,
    required DateTime at,
    required Map<String, Object?> details,
  }) {
    return _auditSink.append(
      AiMcpWriteAuditLog(
        id: _auditIdGenerator(),
        event: event,
        actorType: actor.actorType,
        actorId: actor.actorId,
        submissionId: submissionId,
        at: at,
        details: details,
      ),
    );
  }
}

String _defaultSubmissionId() {
  return 'ai-mcp-submission-${DateTime.now().microsecondsSinceEpoch}';
}

String _defaultAuditId() {
  return 'ai-mcp-audit-${DateTime.now().microsecondsSinceEpoch}';
}

String _requireNonEmpty(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
