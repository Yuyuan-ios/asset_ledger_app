import 'dart:convert';

import 'package:asset_ledger/core/operations/operation_models.dart';
import 'package:asset_ledger/data/models/operation_audit_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('enum wireName', () {
    test('OperationAuditActorType round-trips for every value', () {
      for (final v in OperationAuditActorType.values) {
        expect(OperationAuditActorType.fromWireName(v.wireName), v);
        expect(OperationAuditActorType.tryParse(v.wireName), v);
      }
      expect(OperationAuditActorType.owner.wireName, 'owner');
      expect(OperationAuditActorType.unknown.wireName, 'unknown');
      expect(OperationAuditActorType.tryParse('nope'), isNull);
      expect(
        () => OperationAuditActorType.fromWireName('nope'),
        throwsArgumentError,
      );
    });

    test('OperationAuditSource round-trips', () {
      for (final v in OperationAuditSource.values) {
        expect(OperationAuditSource.fromWireName(v.wireName), v);
      }
      expect(OperationAuditSource.app.wireName, 'app');
      expect(OperationAuditSource.mcp.wireName, 'mcp');
      expect(
        () => OperationAuditSource.fromWireName('cloud'),
        throwsArgumentError,
      );
    });

    test('OperationAuditResult round-trips', () {
      for (final v in OperationAuditResult.values) {
        expect(OperationAuditResult.fromWireName(v.wireName), v);
      }
      expect(OperationAuditResult.cancelled.wireName, 'cancelled');
    });
  });

  group('OperationAuditLog toMap/fromMap', () {
    OperationAuditLog sample({
      String id = 'audit-1',
      String operationId = 'op-1',
      OperationAuditResult result = OperationAuditResult.success,
      bool confirmed = true,
      String? errorMessage,
      OperationPreview? preview,
      List<OperationEntityRef> entityRefs = const [
        OperationEntityRef(entityType: 'timing_record', entityId: 't-1'),
      ],
    }) {
      return OperationAuditLog(
        id: id,
        operationId: operationId,
        operationType: OperationType.saveTimingRecord,
        actorId: 'user-1',
        actorType: OperationAuditActorType.owner,
        source: OperationAuditSource.app,
        createdAt: DateTime.utc(2026, 6, 1, 12, 0, 0),
        entityRefs: entityRefs,
        preview: preview,
        confirmed: confirmed,
        result: result,
        errorMessage: errorMessage,
      );
    }

    test('round-trip with preview snapshot', () {
      const preview = OperationPreview(
        operationId: 'op-1',
        operationType: OperationType.saveTimingRecord,
        title: '保存计时记录',
        riskLevel: OperationRiskLevel.medium,
        requiresConfirmation: true,
      );
      final log = sample(preview: preview);
      final map = log.toMap();
      // preview_snapshot_json 必须是 JSON 字符串。
      expect(map['preview_snapshot_json'], isA<String>());
      final restored = OperationAuditLog.fromMap(map);
      expect(restored.toMap(), map);
      expect(restored.preview, isNotNull);
      expect(restored.preview!.operationId, 'op-1');
      expect(restored.preview!.riskLevel, OperationRiskLevel.medium);
    });

    test('round-trip without preview (preview_snapshot_json NULL)', () {
      final log = sample();
      final map = log.toMap();
      expect(map['preview_snapshot_json'], isNull);
      final restored = OperationAuditLog.fromMap(map);
      expect(restored.preview, isNull);
      expect(restored.toMap(), map);
    });

    test('confirmed bool <-> int (0/1)', () {
      expect(sample(confirmed: true).toMap()['confirmed'], 1);
      expect(sample(confirmed: false).toMap()['confirmed'], 0);

      final restoredFalse = OperationAuditLog.fromMap(
        sample(confirmed: false).toMap(),
      );
      expect(restoredFalse.confirmed, isFalse);
    });

    test('entityRefs round-trip through JSON array', () {
      final log = sample(
        entityRefs: const [
          OperationEntityRef(entityType: 'project', entityId: 'p-1'),
          OperationEntityRef(
            entityType: 'timing_record',
            entityId: 't-1',
            label: '尚义 · HITACHI',
          ),
        ],
      );
      final map = log.toMap();
      final encoded = map['entity_refs_json'] as String;
      final decoded = jsonDecode(encoded) as List;
      expect(decoded, hasLength(2));

      final restored = OperationAuditLog.fromMap(map);
      expect(restored.entityRefs, log.entityRefs);
    });

    test('failure result carries error_message', () {
      final log = sample(
        result: OperationAuditResult.failure,
        errorMessage: '更新 0 行',
      );
      final restored = OperationAuditLog.fromMap(log.toMap());
      expect(restored.result, OperationAuditResult.failure);
      expect(restored.errorMessage, '更新 0 行');
    });

    test('createdAt serialized as UTC ISO8601', () {
      // 输入 local DateTime 也应被规范化为 UTC ISO 串。
      final log = OperationAuditLog(
        id: 'a',
        operationId: 'op',
        operationType: OperationType.generic,
        actorType: OperationAuditActorType.system,
        source: OperationAuditSource.system,
        createdAt: DateTime.utc(2026, 6, 1, 12, 0, 0),
        confirmed: false,
        result: OperationAuditResult.success,
      );
      expect(log.toMap()['created_at'], '2026-06-01T12:00:00.000Z');
      final restored = OperationAuditLog.fromMap(log.toMap());
      expect(restored.createdAt.toUtc(), log.createdAt.toUtc());
    });
  });

  group('error inputs', () {
    test('empty id is rejected by const assert', () {
      expect(
        () => OperationAuditLog(
          id: '',
          operationId: 'op',
          operationType: OperationType.generic,
          actorType: OperationAuditActorType.system,
          source: OperationAuditSource.system,
          createdAt: DateTime.utc(2026),
          confirmed: false,
          result: OperationAuditResult.success,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('empty operationId is rejected by const assert', () {
      expect(
        () => OperationAuditLog(
          id: 'a',
          operationId: '',
          operationType: OperationType.generic,
          actorType: OperationAuditActorType.system,
          source: OperationAuditSource.system,
          createdAt: DateTime.utc(2026),
          confirmed: false,
          result: OperationAuditResult.success,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('fromMap throws when id missing', () {
      expect(
        () => OperationAuditLog.fromMap(const {
          'operation_id': 'op',
          'operation_type': 'generic',
          'actor_type': 'system',
          'source': 'system',
          'created_at': '2026-06-01T12:00:00.000Z',
          'entity_refs_json': '[]',
          'confirmed': 1,
          'result': 'success',
        }),
        throwsArgumentError,
      );
    });

    test('fromMap throws when operation_type missing', () {
      expect(
        () => OperationAuditLog.fromMap(const {
          'id': 'a',
          'operation_id': 'op',
          'actor_type': 'system',
          'source': 'system',
          'created_at': '2026-06-01T12:00:00.000Z',
          'entity_refs_json': '[]',
          'confirmed': 1,
          'result': 'success',
        }),
        throwsArgumentError,
      );
    });

    test('fromMap throws when confirmed is not 0/1', () {
      expect(
        () => OperationAuditLog.fromMap(const {
          'id': 'a',
          'operation_id': 'op',
          'operation_type': 'generic',
          'actor_type': 'system',
          'source': 'system',
          'created_at': '2026-06-01T12:00:00.000Z',
          'entity_refs_json': '[]',
          'confirmed': 2,
          'result': 'success',
        }),
        throwsArgumentError,
      );
    });
  });
}
