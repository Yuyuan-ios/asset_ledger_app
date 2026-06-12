import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/features/mcp/use_cases/ai_mcp_write_pending_workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 6, 12, 10);
  final aiActor = ActorContext(
    actorType: OperationActorType.agent,
    actorId: 'agent-mcp-1',
    delegatedActorType: OperationActorType.owner,
    delegatedActorId: 'owner-1',
    sessionId: 'mcp-session-1',
    source: 'mock_mcp',
  );
  final owner = ActorContext(
    actorType: OperationActorType.owner,
    actorId: 'owner-1',
  );

  group('AiMcpWritePendingWorkflow', () {
    test(
      'natural language submit creates pending structured submission only',
      () async {
        final harness = _newHarness();

        final submission = await harness.workflow.submitNaturalLanguage(
          context: _context(actor: aiActor, now: now),
          request: _request(),
        );

        expect(submission.status, AiMcpWriteSubmissionStatus.pending);
        expect(submission.requestText, contains('五里山'));
        expect(submission.structured.projectLabel, '丁队 · 五里山');
        expect(submission.structured.quantityScaled, 1500);
        expect(harness.parser.requests, hasLength(1));
        expect(harness.gateway.requests, isEmpty);
        expect(harness.submissions.items, contains(submission.id));

        final directExecute = const OperationPermissionPolicy().canPerform(
          actor: aiActor,
          action: OperationPermissionAction.executeSaveTimingRecord,
        );
        expect(directExecute.allowed, isFalse);

        expect(harness.audit.events, [AiMcpWriteAuditEvent.pendingSubmitted]);
        _expectReviewMapIsPrivate(submission.toReviewMap());
      },
    );

    test('owner approval calls gateway and appends audit log', () async {
      final harness = _newHarness();
      final pending = await harness.workflow.submitNaturalLanguage(
        context: _context(actor: aiActor, now: now),
        request: _request(clientRequestId: 'client-1'),
      );

      final result = await harness.workflow.approve(
        actor: owner,
        submissionId: pending.id,
        now: now.add(const Duration(minutes: 5)),
      );

      expect(result.recordId, 'ledger-record-1');
      expect(harness.gateway.requests, hasLength(1));
      expect(harness.gateway.requests.single.submission.id, pending.id);
      final stored = await harness.submissions.findById(pending.id);
      expect(stored!.status, AiMcpWriteSubmissionStatus.approved);
      expect(stored.approvedRecordId, 'ledger-record-1');
      expect(harness.audit.events, [
        AiMcpWriteAuditEvent.pendingSubmitted,
        AiMcpWriteAuditEvent.approveSucceeded,
      ]);
      expect(harness.audit.logs.last.details['record_id'], 'ledger-record-1');
    });

    test('AI actor cannot approve even when delegated to owner', () async {
      final harness = _newHarness();
      final pending = await harness.workflow.submitNaturalLanguage(
        context: _context(actor: aiActor, now: now),
        request: _request(),
      );

      await expectLater(
        harness.workflow.approve(
          actor: aiActor,
          submissionId: pending.id,
          now: now.add(const Duration(minutes: 1)),
        ),
        _throwsCode(AiMcpWriteFailureCode.permissionDenied),
      );

      expect(harness.gateway.requests, isEmpty);
      final stored = await harness.submissions.findById(pending.id);
      expect(stored!.status, AiMcpWriteSubmissionStatus.pending);
      expect(harness.audit.events, [
        AiMcpWriteAuditEvent.pendingSubmitted,
        AiMcpWriteAuditEvent.denied,
      ]);
    });

    test(
      'device scope blocks pending creation before approval gateway',
      () async {
        final harness = _newHarness();

        await expectLater(
          harness.workflow.submitNaturalLanguage(
            context: _context(
              actor: aiActor,
              now: now,
              scope: ActorScope.devices(
                deviceIds: const ['device-other'],
                actorId: 'agent-mcp-1',
              ),
            ),
            request: _request(),
          ),
          _throwsCode(AiMcpWriteFailureCode.deviceOutOfScope),
        );

        expect(harness.submissions.items, isEmpty);
        expect(harness.gateway.requests, isEmpty);
        expect(harness.audit.events, [AiMcpWriteAuditEvent.denied]);
      },
    );

    test('undelegated agent and expired scope are denied', () async {
      final undelegated = ActorContext(
        actorType: OperationActorType.agent,
        actorId: 'agent-mcp-2',
      );
      final permissionHarness = _newHarness();
      await expectLater(
        permissionHarness.workflow.submitNaturalLanguage(
          context: _context(actor: undelegated, now: now),
          request: _request(),
        ),
        _throwsCode(AiMcpWriteFailureCode.permissionDenied),
      );
      expect(permissionHarness.parser.requests, isEmpty);
      expect(permissionHarness.audit.events, [AiMcpWriteAuditEvent.denied]);

      final expiredHarness = _newHarness();
      await expectLater(
        expiredHarness.workflow.submitNaturalLanguage(
          context: _context(
            actor: aiActor,
            now: now,
            scope: ActorScope.fullOwner(expiresAt: now),
          ),
          request: _request(),
        ),
        _throwsCode(AiMcpWriteFailureCode.scopeExpired),
      );
      expect(expiredHarness.parser.requests, isEmpty);
      expect(expiredHarness.gateway.requests, isEmpty);
    });

    test(
      'owner can reject pending with audit and without gateway call',
      () async {
        final harness = _newHarness();
        final pending = await harness.workflow.submitNaturalLanguage(
          context: _context(actor: aiActor, now: now),
          request: _request(),
        );

        final rejected = await harness.workflow.reject(
          actor: owner,
          submissionId: pending.id,
          reason: 'duplicate command',
          now: now.add(const Duration(minutes: 2)),
        );

        expect(rejected.status, AiMcpWriteSubmissionStatus.rejected);
        expect(rejected.rejectionReason, 'duplicate command');
        expect(harness.gateway.requests, isEmpty);
        expect(harness.audit.events, [
          AiMcpWriteAuditEvent.pendingSubmitted,
          AiMcpWriteAuditEvent.rejected,
        ]);
        expect(harness.audit.logs.last.details['reason'], 'duplicate command');
      },
    );
  });
}

AiMcpWriteContext _context({
  required ActorContext actor,
  required DateTime now,
  ActorScope? scope,
}) {
  return AiMcpWriteContext(
    actor: actor,
    scope: scope ?? ActorScope.fullOwner(actorId: actor.actorId),
    now: now,
  );
}

AiMcpNaturalLanguageWriteRequest _request({String? clientRequestId}) {
  return AiMcpNaturalLanguageWriteRequest(
    commandText: '给丁队五里山补一条 SANY 2# 6月12日 1.5 小时',
    clientRequestId: clientRequestId,
  );
}

Matcher _throwsCode(AiMcpWriteFailureCode code) {
  return throwsA(
    isA<AiMcpWriteWorkflowException>().having((e) => e.code, 'code', code),
  );
}

_Harness _newHarness() {
  final parser = _FakeParser(
    structured: AiMcpStructuredTimingSubmission(
      deviceId: 'device-7',
      deviceLabel: 'SANY 2#',
      projectLabel: '丁队 · 五里山',
      workDate: 20260612,
      unit: 'HOUR',
      quantityScaled: 1500,
      startMeter: 100000,
      endMeter: 101500,
      note: 'AI parsed from natural language',
    ),
  );
  final submissions = _MemorySubmissionRepository();
  final gateway = _FakeApprovalGateway();
  final audit = _MemoryAuditSink();
  var nextSubmission = 1;
  var nextAudit = 1;
  return _Harness(
    parser: parser,
    submissions: submissions,
    gateway: gateway,
    audit: audit,
    workflow: AiMcpWritePendingWorkflow(
      parser: parser,
      submissionRepository: submissions,
      approvalGateway: gateway,
      auditSink: audit,
      idGenerator: () => 'ai-sub-${nextSubmission++}',
      auditIdGenerator: () => 'ai-audit-${nextAudit++}',
    ),
  );
}

class _Harness {
  const _Harness({
    required this.parser,
    required this.submissions,
    required this.gateway,
    required this.audit,
    required this.workflow,
  });

  final _FakeParser parser;
  final _MemorySubmissionRepository submissions;
  final _FakeApprovalGateway gateway;
  final _MemoryAuditSink audit;
  final AiMcpWritePendingWorkflow workflow;
}

class _FakeParser implements AiMcpWriteParser {
  _FakeParser({required this.structured});

  final AiMcpStructuredTimingSubmission structured;
  final requests = <AiMcpNaturalLanguageWriteRequest>[];

  @override
  Future<AiMcpStructuredTimingSubmission> parse(
    AiMcpNaturalLanguageWriteRequest request,
  ) async {
    requests.add(request);
    return structured;
  }
}

class _MemorySubmissionRepository implements AiMcpPendingSubmissionRepository {
  final items = <String, AiMcpPendingSubmission>{};

  @override
  Future<void> insert(AiMcpPendingSubmission submission) async {
    if (items.containsKey(submission.id)) {
      throw StateError('duplicate submission id ${submission.id}');
    }
    items[submission.id] = submission;
  }

  @override
  Future<AiMcpPendingSubmission?> findById(String id) async => items[id];

  @override
  Future<void> save(AiMcpPendingSubmission submission) async {
    items[submission.id] = submission;
  }
}

class _FakeApprovalGateway implements AiMcpWriteApprovalGateway {
  final requests = <AiMcpWriteApprovalRequest>[];

  @override
  Future<AiMcpApprovedWriteResult> createLedgerEntry(
    AiMcpWriteApprovalRequest request,
  ) async {
    requests.add(request);
    return AiMcpApprovedWriteResult(recordId: 'ledger-record-1');
  }
}

class _MemoryAuditSink implements AiMcpWriteAuditSink {
  final logs = <AiMcpWriteAuditLog>[];

  List<AiMcpWriteAuditEvent> get events =>
      logs.map((log) => log.event).toList(growable: false);

  @override
  Future<void> append(AiMcpWriteAuditLog log) async {
    logs.add(log);
  }
}

void _expectReviewMapIsPrivate(Map<String, Object?> map) {
  const privateKeys = {
    'project_id',
    'share_id',
    'device_id',
    'local_device_id',
    'device_auto_number',
    'contact',
    'site',
    'phone',
  };
  for (final entry in map.entries) {
    expect(privateKeys.contains(entry.key), isFalse);
    final value = entry.value;
    if (value is Map<String, Object?>) {
      _expectReviewMapIsPrivate(value);
    }
  }
}
