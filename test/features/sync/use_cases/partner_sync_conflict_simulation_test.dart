import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/features/sync/use_cases/partner_sync_conflict_simulation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const simulation = PartnerSyncConflictSimulation();

  group('PartnerSyncConflictSimulation', () {
    test(
      'accepts a single authorized remote write without recomputing amount',
      () {
        final remote = _entry(
          amountFen: 33334,
          quantityScaled: 3333,
          revision: 2,
          actorId: 'partner-1',
        );

        final result = simulation.merge(
          authorizedDeviceIds: const ['device-1'],
          localWrites: const [],
          remoteWrites: [remote],
        );

        expect(result.conflicts, isEmpty);
        expect(result.warnings, isEmpty);
        expect(result.accepted.single.amountFen, 33334);
        expect(result.accepted.single.quantityScaled, 3333);
      },
    );

    test('multi-party same-entry conflict preserves exact fen values', () {
      final local = _entry(
        amountFen: 33334,
        quantityScaled: 3333,
        revision: 2,
        actorId: 'owner',
      );
      final remote = _entry(
        amountFen: 33335,
        quantityScaled: 3333,
        revision: 2,
        actorId: 'partner-1',
      );

      final result = simulation.merge(
        authorizedDeviceIds: const ['device-1'],
        localWrites: [local],
        remoteWrites: [remote],
        baseEntries: [
          _entry(
            amountFen: 33330,
            quantityScaled: 3333,
            revision: 1,
            actorId: 'owner',
          ),
        ],
      );

      expect(result.accepted, isEmpty);
      final conflict = result.conflicts.single;
      expect(conflict.requiresOwnerReview, isTrue);
      expect(conflict.amountPrecisionPreserved, isTrue);
      expect(conflict.local.amountFen, 33334);
      expect(conflict.remote.amountFen, 33335);
      expect(conflict.local.toMap()['amount_fen'], 33334);
      expect(conflict.remote.toMap()['amount_fen'], 33335);
    });

    test(
      'conflicting settled snapshots are not auto-merged or overwritten',
      () {
        final localSnapshot = _snapshot(
          receivedFen: 80000,
          remainingFen: 0,
          digest: 'local-digest',
        );
        final remoteSnapshot = _snapshot(
          receivedFen: 79999,
          remainingFen: 1,
          digest: 'remote-digest',
        );

        final result = simulation.merge(
          authorizedDeviceIds: const ['device-1'],
          localWrites: [
            _entry(
              settledSnapshot: localSnapshot,
              revision: 2,
              actorId: 'owner',
            ),
          ],
          remoteWrites: [
            _entry(
              settledSnapshot: remoteSnapshot,
              revision: 2,
              actorId: 'partner-1',
            ),
          ],
          baseEntries: [
            _entry(
              settledSnapshot: _snapshot(
                receivedFen: 70000,
                remainingFen: 10000,
                digest: 'base-digest',
              ),
              revision: 1,
              actorId: 'owner',
            ),
          ],
        );

        expect(result.accepted, isEmpty);
        final conflict = result.conflicts.single;
        expect(conflict.requiresOwnerReview, isTrue);
        expect(conflict.settledSnapshotPreserved, isTrue);
        expect(conflict.local.settledSnapshot, same(localSnapshot));
        expect(conflict.remote.settledSnapshot, same(remoteSnapshot));
        expect(
          conflict.local.settledSnapshot!.toMap()['record_digest'],
          'local-digest',
        );
        expect(
          conflict.remote.settledSnapshot!.toMap()['record_digest'],
          'remote-digest',
        );
      },
    );

    test('one-sided remote update over base keeps snapshot exact', () {
      final baseSnapshot = _snapshot(
        receivedFen: 70000,
        remainingFen: 10000,
        digest: 'base-digest',
      );
      final remoteSnapshot = _snapshot(
        receivedFen: 80000,
        remainingFen: 0,
        digest: 'remote-digest',
      );
      final base = _entry(
        settledSnapshot: baseSnapshot,
        revision: 1,
        actorId: 'owner',
      );
      final local = _entry(
        settledSnapshot: baseSnapshot,
        revision: 1,
        actorId: 'owner',
      );
      final remote = _entry(
        settledSnapshot: remoteSnapshot,
        revision: 2,
        actorId: 'partner-1',
      );

      final result = simulation.merge(
        authorizedDeviceIds: const ['device-1'],
        localWrites: [local],
        remoteWrites: [remote],
        baseEntries: [base],
      );

      expect(result.conflicts, isEmpty);
      expect(result.accepted.single.settledSnapshot, same(remoteSnapshot));
      expect(result.accepted.single.toMap()['settled_snapshot'], {
        'snapshot_schema_version': 1,
        'receivable_fen': 80000,
        'received_fen': 80000,
        'write_off_fen': 0,
        'remaining_fen': 0,
        'settled_at': DateTime(2026, 6, 12).toIso8601String(),
        'calculation_policy_version': 'v1',
        'record_digest': 'remote-digest',
      });
    });

    test('unauthorized device write is skipped with warning', () {
      final result = simulation.merge(
        authorizedDeviceIds: const ['device-1'],
        localWrites: const [],
        remoteWrites: [
          _entry(id: 'entry-2', deviceId: 'device-2', actorId: 'partner-1'),
        ],
      );

      expect(result.accepted, isEmpty);
      expect(result.conflicts, isEmpty);
      expect(result.warnings, contains('device device-2 is not authorized'));
    });
  });
}

PartnerSyncLedgerEntry _entry({
  String id = 'entry-1',
  String deviceId = 'device-1',
  MeasureUnit unit = MeasureUnit.hour,
  int quantityScaled = 8000,
  int amountFen = 80000,
  int revision = 1,
  String actorId = 'owner',
  PartnerSyncSettledSnapshot? settledSnapshot,
}) {
  return PartnerSyncLedgerEntry(
    id: id,
    deviceId: deviceId,
    unit: unit,
    quantityScaled: quantityScaled,
    amountFen: amountFen,
    revision: revision,
    updatedAt: DateTime(2026, 6, 12, 8, revision),
    originActorId: actorId,
    settledSnapshot: settledSnapshot,
  );
}

PartnerSyncSettledSnapshot _snapshot({
  required int receivedFen,
  required int remainingFen,
  required String digest,
}) {
  return PartnerSyncSettledSnapshot(
    schemaVersion: 1,
    receivableFen: 80000,
    receivedFen: receivedFen,
    writeOffFen: 0,
    remainingFen: remainingFen,
    settledAt: DateTime(2026, 6, 12),
    calculationPolicyVersion: 'v1',
    recordDigest: digest,
  );
}
