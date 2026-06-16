import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/data/models/timing_record.dart';
import 'package:asset_ledger/features/timing/use_cases/driver_entry_submission_workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 6, 12, 8);
  final driver = ActorContext(
    actorType: OperationActorType.driver,
    actorId: 'driver-1',
    sessionId: 'session-1',
  );
  final owner = ActorContext(actorType: OperationActorType.owner);

  group('DriverEntrySubmissionWorkflow', () {
    test(
      'driver submit creates pending only and does not write TimingRecord',
      () async {
        final workflow = _newWorkflow();
        await workflow.links.save(
          _link(expiresAt: now.add(const Duration(days: 1))),
        );

        final submission = await workflow.workflow.submit(
          actor: driver,
          linkId: 'link-1',
          draft: _draft(),
          now: now,
        );

        expect(submission.status, DriverEntrySubmissionStatus.pending);
        expect(submission.driverId, 'driver-1');
        expect(workflow.gateway.requests, isEmpty);
        expect((await workflow.links.findById('link-1'))!.usedSubmissions, 1);

        final directExecute = const OperationPermissionPolicy().canPerform(
          actor: driver,
          action: OperationPermissionAction.executeSaveTimingRecord,
        );
        expect(directExecute.allowed, isFalse);
      },
    );

    test('link expiry, revoke, and submission limit block submit', () async {
      final expired = _newWorkflow();
      await expired.links.save(_link(expiresAt: now));
      await expectLater(
        expired.workflow.submit(
          actor: driver,
          linkId: 'link-1',
          draft: _draft(),
          now: now,
        ),
        _throwsCode(DriverEntryLinkFailureCode.linkExpired),
      );

      final revoked = _newWorkflow();
      await revoked.links.save(
        _link(
          expiresAt: now.add(const Duration(days: 1)),
          revokedAt: now.subtract(const Duration(minutes: 1)),
        ),
      );
      await expectLater(
        revoked.workflow.submit(
          actor: driver,
          linkId: 'link-1',
          draft: _draft(),
          now: now,
        ),
        _throwsCode(DriverEntryLinkFailureCode.linkRevoked),
      );

      final exhausted = _newWorkflow();
      await exhausted.links.save(
        _link(
          expiresAt: now.add(const Duration(days: 1)),
          maxSubmissions: 1,
          usedSubmissions: 1,
        ),
      );
      await expectLater(
        exhausted.workflow.submit(
          actor: driver,
          linkId: 'link-1',
          draft: _draft(),
          now: now,
        ),
        _throwsCode(DriverEntryLinkFailureCode.linkExhausted),
      );
    });

    test(
      'driver and device scope are enforced before pending creation',
      () async {
        final workflow = _newWorkflow();
        await workflow.links.save(
          _link(expiresAt: now.add(const Duration(days: 1))),
        );

        final otherDriver = ActorContext(
          actorType: OperationActorType.driver,
          actorId: 'driver-2',
        );
        await expectLater(
          workflow.workflow.submit(
            actor: otherDriver,
            linkId: 'link-1',
            draft: _draft(),
            now: now,
          ),
          _throwsCode(DriverEntryLinkFailureCode.driverMismatch),
        );

        await expectLater(
          workflow.workflow.submit(
            actor: driver,
            linkId: 'link-1',
            draft: _draft(deviceId: 99),
            now: now,
          ),
          _throwsCode(DriverEntryLinkFailureCode.deviceNotAllowed),
        );
        expect(workflow.submissions.items, isEmpty);
      },
    );

    test(
      'owner approve writes TimingRecord and marks submission approved',
      () async {
        final workflow = _newWorkflow();
        await workflow.links.save(
          _link(expiresAt: now.add(const Duration(days: 1))),
        );
        final pending = await workflow.workflow.submit(
          actor: driver,
          linkId: 'link-1',
          draft: _draft(quantityScaled: 2500),
          now: now,
        );

        final record = await workflow.workflow.approve(
          actor: owner,
          submissionId: pending.id,
          now: now.add(const Duration(minutes: 5)),
        );

        expect(record.id, 42);
        expect(record.deviceId, 7);
        expect(record.quantityScaled, 2500);
        expect(workflow.gateway.requests, hasLength(1));
        final stored = await workflow.submissions.findById(pending.id);
        expect(stored!.status, DriverEntrySubmissionStatus.approved);
        expect(stored.approvedTimingRecordId, '42');
      },
    );

    test(
      'driver cannot approve and owner cannot submit through driver link',
      () async {
        final workflow = _newWorkflow();
        await workflow.links.save(
          _link(expiresAt: now.add(const Duration(days: 1))),
        );
        final pending = await workflow.workflow.submit(
          actor: driver,
          linkId: 'link-1',
          draft: _draft(),
          now: now,
        );

        await expectLater(
          workflow.workflow.approve(
            actor: driver,
            submissionId: pending.id,
            now: now,
          ),
          _throwsCode(DriverEntryLinkFailureCode.permissionDenied),
        );
        await expectLater(
          workflow.workflow.submit(
            actor: owner,
            linkId: 'link-1',
            draft: _draft(),
            now: now,
          ),
          _throwsCode(DriverEntryLinkFailureCode.permissionDenied),
        );
      },
    );

    test(
      'driver view omits project, contact, site, and financial fields',
      () async {
        final submission = DriverEntrySubmission(
          id: 'sub-1',
          linkId: 'link-1',
          driverId: 'driver-1',
          draft: _draft(),
          status: DriverEntrySubmissionStatus.pending,
          submittedAt: now,
        );

        final view = DriverEntrySubmissionDriverView.fromSubmission(submission);
        final map = view.toMap();
        expect(map.containsKey('project_id'), isFalse);
        expect(map.containsKey('contact'), isFalse);
        expect(map.containsKey('site'), isFalse);
        expect(map.containsKey('income'), isFalse);
        expect(map.containsKey('income_fen'), isFalse);

        const visibility = OperationVisibilityPolicy();
        expect(
          visibility
              .canSee(
                actor: driver,
                capability: OperationVisibilityCapability.financialAmount,
              )
              .visible,
          isFalse,
        );
        expect(
          visibility
              .canSee(
                actor: driver,
                capability: OperationVisibilityCapability.projectLabel,
              )
              .visible,
          isFalse,
        );
      },
    );
  });
}

DriverEntrySubmissionDraft _draft({
  int deviceId = 7,
  int quantityScaled = 1500,
}) {
  return DriverEntrySubmissionDraft(
    deviceId: deviceId,
    workDate: 20260612,
    unit: MeasureUnit.hour,
    quantityScaled: quantityScaled,
    startMeter: 100,
    endMeter: 101.5,
  );
}

DriverEntryLink _link({
  required DateTime expiresAt,
  DateTime? revokedAt,
  int maxSubmissions = 3,
  int usedSubmissions = 0,
}) {
  return DriverEntryLink(
    id: 'link-1',
    driverId: 'driver-1',
    allowedDeviceIds: [7],
    expiresAt: expiresAt,
    revokedAt: revokedAt,
    maxSubmissions: maxSubmissions,
    usedSubmissions: usedSubmissions,
  );
}

Matcher _throwsCode(DriverEntryLinkFailureCode code) {
  return throwsA(
    isA<DriverEntryWorkflowException>().having((e) => e.code, 'code', code),
  );
}

_WorkflowHarness _newWorkflow() {
  final links = _MemoryLinkRepository();
  final submissions = _MemorySubmissionRepository();
  final gateway = _FakeApprovalGateway();
  var nextId = 1;
  return _WorkflowHarness(
    links: links,
    submissions: submissions,
    gateway: gateway,
    workflow: DriverEntrySubmissionWorkflow(
      linkRepository: links,
      submissionRepository: submissions,
      approvalGateway: gateway,
      idGenerator: () => 'sub-${nextId++}',
    ),
  );
}

class _WorkflowHarness {
  const _WorkflowHarness({
    required this.links,
    required this.submissions,
    required this.gateway,
    required this.workflow,
  });

  final _MemoryLinkRepository links;
  final _MemorySubmissionRepository submissions;
  final _FakeApprovalGateway gateway;
  final DriverEntrySubmissionWorkflow workflow;
}

class _MemoryLinkRepository implements DriverEntryLinkRepository {
  final items = <String, DriverEntryLink>{};

  @override
  Future<DriverEntryLink?> findById(String id) async => items[id];

  @override
  Future<void> save(DriverEntryLink link) async {
    items[link.id] = link;
  }
}

class _MemorySubmissionRepository implements DriverEntrySubmissionRepository {
  final items = <String, DriverEntrySubmission>{};

  @override
  Future<void> insert(DriverEntrySubmission submission) async {
    if (items.containsKey(submission.id)) {
      throw StateError('duplicate submission id ${submission.id}');
    }
    items[submission.id] = submission;
  }

  @override
  Future<DriverEntrySubmission?> findById(String id) async => items[id];

  @override
  Future<void> save(DriverEntrySubmission submission) async {
    items[submission.id] = submission;
  }
}

class _FakeApprovalGateway implements DriverEntryApprovalGateway {
  final requests = <DriverEntryApprovalRequest>[];

  @override
  Future<TimingRecord> createTimingRecord(
    DriverEntryApprovalRequest request,
  ) async {
    requests.add(request);
    final draft = request.submission.draft;
    return TimingRecord(
      id: 42,
      deviceId: draft.deviceId,
      startDate: draft.workDate,
      projectId: 'project:approved',
      contact: '甲方',
      site: '工地',
      type: TimingType.hours,
      startMeter: draft.startMeter,
      endMeter: draft.endMeter,
      hours: draft.quantityScaled / 1000.0,
      income: 0,
      unit: draft.unit,
      quantityScaled: draft.quantityScaled,
      isBreaking: draft.isBreaking,
    );
  }
}
