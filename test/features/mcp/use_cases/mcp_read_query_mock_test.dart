import 'package:asset_ledger/core/operations/operation_access_control.dart';
import 'package:asset_ledger/core/operations/operation_actor_scope.dart';
import 'package:asset_ledger/core/operations/operation_actor_type.dart';
import 'package:asset_ledger/features/mcp/use_cases/mcp_read_query_mock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 12);
  const service = McpReadQueryMock();

  group('McpReadQueryMock', () {
    test('owner can query devices without exposing local ids', () {
      final result = service.query(
        context: _context(
          actor: _owner(),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
        facts: _facts(),
        request: const McpReadQueryRequest(type: McpReadQueryType.devices),
      );

      expect(result.items, hasLength(2));
      expect(result.items.first, {
        'type': 'device',
        'device_label': 'SANY 2#',
        'brand_or_model': 'SANY SY215',
        'active': true,
      });
      _expectNoPrivateKeys(result.items.first);
      expect(result.redacted, isFalse);
      expect(result.scopeLimited, isFalse);
    });

    test('owner can query projects without project_id or contact details', () {
      final result = service.query(
        context: _context(
          actor: _owner(),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
        facts: _facts(),
        request: const McpReadQueryRequest(type: McpReadQueryType.projects),
      );

      expect(result.items, [
        {'type': 'project', 'project_label': '丁队 · 五里山'},
        {'type': 'project', 'project_label': '王队 · 东坡'},
      ]);
      for (final item in result.items) {
        _expectNoPrivateKeys(item);
      }
    });

    test('owner can query receivables and payment status in integer fen', () {
      final receivable = service.query(
        context: _context(
          actor: _owner(),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
        facts: _facts(),
        request: const McpReadQueryRequest(
          type: McpReadQueryType.receivables,
          keyword: '五里山',
        ),
      );
      final payment = service.query(
        context: _context(
          actor: _owner(),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
        facts: _facts(),
        request: const McpReadQueryRequest(
          type: McpReadQueryType.paymentStatus,
          keyword: '五里山',
        ),
      );

      expect(receivable.items.single, {
        'type': 'receivable',
        'project_label': '丁队 · 五里山',
        'receivable_fen': 120000,
        'received_fen': 70000,
        'write_off_fen': 10000,
        'remaining_fen': 40000,
      });
      expect(payment.items.single, {
        'type': 'payment_status',
        'project_label': '丁队 · 五里山',
        'payment_status': 'partial',
        'remaining_fen': 40000,
      });
    });

    test('partner device scope can read authorized devices only', () {
      final result = service.query(
        context: _context(
          actor: _partner(),
          scope: ActorScope.devices(
            deviceIds: const ['device-2'],
            actorId: 'partner-1',
          ),
          now: now,
        ),
        facts: _facts(),
        request: const McpReadQueryRequest(type: McpReadQueryType.devices),
      );

      expect(result.items.map((item) => item['device_label']), ['CAT 3#']);
      expect(result.redacted, isTrue);
      expect(result.scopeLimited, isTrue);
      _expectNoPrivateKeys(result.items.single);
    });

    test('partner cannot query project or financial data', () {
      final projectResult = service.query(
        context: _context(
          actor: _partner(),
          scope: ActorScope.devices(
            deviceIds: const ['device-1'],
            actorId: 'partner-1',
          ),
          now: now,
        ),
        facts: _facts(),
        request: const McpReadQueryRequest(type: McpReadQueryType.projects),
      );
      final receivableResult = service.query(
        context: _context(
          actor: _partner(),
          scope: ActorScope.devices(
            deviceIds: const ['device-1'],
            actorId: 'partner-1',
          ),
          now: now,
        ),
        facts: _facts(),
        request: const McpReadQueryRequest(type: McpReadQueryType.receivables),
      );

      expect(projectResult.items, isEmpty);
      expect(projectResult.warnings, contains('project query not allowed'));
      expect(receivableResult.items, isEmpty);
      expect(
        receivableResult.warnings,
        contains('receivable query not allowed'),
      );
    });

    test('expired scope and undelegated agent are denied', () {
      final expired = service.query(
        context: _context(
          actor: _owner(),
          scope: ActorScope.fullOwner(expiresAt: now),
          now: now,
        ),
        facts: _facts(),
        request: const McpReadQueryRequest(type: McpReadQueryType.devices),
      );
      final undelegatedAgent = service.query(
        context: _context(
          actor: ActorContext(
            actorType: OperationActorType.agent,
            actorId: 'agent-1',
          ),
          scope: ActorScope.fullOwner(),
          now: now,
        ),
        facts: _facts(),
        request: const McpReadQueryRequest(type: McpReadQueryType.devices),
      );

      expect(expired.items, isEmpty);
      expect(expired.warnings, contains('scope expired'));
      expect(undelegatedAgent.items, isEmpty);
      expect(
        undelegatedAgent.warnings,
        contains('agent requires delegated actor scope'),
      );
    });
  });
}

McpReadQueryContext _context({
  required ActorContext actor,
  required ActorScope scope,
  required DateTime now,
}) {
  return McpReadQueryContext(actor: actor, scope: scope, now: now);
}

ActorContext _owner() => ActorContext(actorType: OperationActorType.owner);

ActorContext _partner() {
  return ActorContext(
    actorType: OperationActorType.partner,
    actorId: 'partner-1',
  );
}

McpReadLedgerFacts _facts() {
  return McpReadLedgerFacts(
    devices: [
      McpDeviceFact(
        deviceId: 'device-1',
        displayName: 'SANY 2#',
        brandOrModel: 'SANY SY215',
        localDeviceId: 'local-device-secret',
        deviceAutoNumber: 'AUTO-0001',
      ),
      McpDeviceFact(
        deviceId: 'device-2',
        displayName: 'CAT 3#',
        brandOrModel: 'CAT 320',
        localDeviceId: 'local-device-secret-2',
        deviceAutoNumber: 'AUTO-0002',
      ),
    ],
    projects: [
      McpProjectFact(
        projectId: 'project-secret-1',
        projectLabel: '丁队 · 五里山',
        contact: '丁队',
        site: '五里山',
        shareId: 'share-secret',
        phone: '13800000000',
      ),
      McpProjectFact(
        projectId: 'project-secret-2',
        projectLabel: '王队 · 东坡',
        contact: '王队',
        site: '东坡',
      ),
    ],
    receivables: [
      McpReceivableFact(
        projectId: 'project-secret-1',
        projectLabel: '丁队 · 五里山',
        receivableFen: 120000,
        receivedFen: 70000,
        writeOffFen: 10000,
        remainingFen: 40000,
        paymentStatus: 'partial',
      ),
      McpReceivableFact(
        projectId: 'project-secret-2',
        projectLabel: '王队 · 东坡',
        receivableFen: 90000,
        receivedFen: 90000,
        writeOffFen: 0,
        remainingFen: 0,
        paymentStatus: 'settled',
      ),
    ],
  );
}

void _expectNoPrivateKeys(Map<String, Object?> item) {
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
  for (final key in privateKeys) {
    expect(item.containsKey(key), isFalse, reason: 'must not expose $key');
  }
}
