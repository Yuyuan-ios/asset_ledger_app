import '../../../core/measure/measure_unit.dart';

class PartnerSyncSettledSnapshot {
  PartnerSyncSettledSnapshot({
    required this.schemaVersion,
    required this.receivableFen,
    required this.receivedFen,
    required this.writeOffFen,
    required this.remainingFen,
    required this.settledAt,
    required this.calculationPolicyVersion,
    required this.recordDigest,
  }) {
    if (schemaVersion <= 0) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
  }

  final int schemaVersion;
  final int receivableFen;
  final int receivedFen;
  final int writeOffFen;
  final int remainingFen;
  final DateTime settledAt;
  final String calculationPolicyVersion;
  final String recordDigest;

  Map<String, Object?> toMap() {
    return {
      'snapshot_schema_version': schemaVersion,
      'receivable_fen': receivableFen,
      'received_fen': receivedFen,
      'write_off_fen': writeOffFen,
      'remaining_fen': remainingFen,
      'settled_at': settledAt.toIso8601String(),
      'calculation_policy_version': calculationPolicyVersion,
      'record_digest': recordDigest,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is PartnerSyncSettledSnapshot &&
        other.schemaVersion == schemaVersion &&
        other.receivableFen == receivableFen &&
        other.receivedFen == receivedFen &&
        other.writeOffFen == writeOffFen &&
        other.remainingFen == remainingFen &&
        other.settledAt == settledAt &&
        other.calculationPolicyVersion == calculationPolicyVersion &&
        other.recordDigest == recordDigest;
  }

  @override
  int get hashCode {
    return Object.hash(
      schemaVersion,
      receivableFen,
      receivedFen,
      writeOffFen,
      remainingFen,
      settledAt,
      calculationPolicyVersion,
      recordDigest,
    );
  }
}

class PartnerSyncLedgerEntry {
  PartnerSyncLedgerEntry({
    required this.id,
    required this.deviceId,
    required this.unit,
    required this.quantityScaled,
    required this.amountFen,
    required this.revision,
    required this.updatedAt,
    required this.originActorId,
    this.settledSnapshot,
  }) {
    _requireNonEmpty(id, 'id');
    _requireNonEmpty(deviceId, 'deviceId');
    _requireNonEmpty(originActorId, 'originActorId');
    if (quantityScaled <= 0) {
      throw ArgumentError.value(quantityScaled, 'quantityScaled');
    }
    if (revision < 0) throw ArgumentError.value(revision, 'revision');
  }

  final String id;
  final String deviceId;
  final MeasureUnit unit;
  final int quantityScaled;
  final int amountFen;
  final int revision;
  final DateTime updatedAt;
  final String originActorId;
  final PartnerSyncSettledSnapshot? settledSnapshot;

  bool sameBusinessStateAs(PartnerSyncLedgerEntry other) {
    return id == other.id &&
        deviceId == other.deviceId &&
        unit == other.unit &&
        quantityScaled == other.quantityScaled &&
        amountFen == other.amountFen &&
        settledSnapshot == other.settledSnapshot;
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'unit': unit.dbValue,
      'quantity_scaled': quantityScaled,
      'amount_fen': amountFen,
      'revision': revision,
      'updated_at': updatedAt.toIso8601String(),
      'origin_actor_id': originActorId,
      'settled_snapshot': settledSnapshot?.toMap(),
    };
  }
}

class PartnerSyncConflict {
  const PartnerSyncConflict({
    required this.entryId,
    required this.local,
    required this.remote,
    required this.reason,
  });

  final String entryId;
  final PartnerSyncLedgerEntry local;
  final PartnerSyncLedgerEntry remote;
  final String reason;

  bool get requiresOwnerReview => true;
  bool get amountPrecisionPreserved => true;
  bool get settledSnapshotPreserved => true;
}

class PartnerSyncMergeResult {
  PartnerSyncMergeResult({
    required Iterable<PartnerSyncLedgerEntry> accepted,
    required Iterable<PartnerSyncConflict> conflicts,
    required Iterable<String> warnings,
  }) : accepted = List.unmodifiable(accepted),
       conflicts = List.unmodifiable(conflicts),
       warnings = List.unmodifiable(warnings);

  final List<PartnerSyncLedgerEntry> accepted;
  final List<PartnerSyncConflict> conflicts;
  final List<String> warnings;
}

class PartnerSyncConflictSimulation {
  const PartnerSyncConflictSimulation();

  PartnerSyncMergeResult merge({
    required Iterable<String> authorizedDeviceIds,
    required Iterable<PartnerSyncLedgerEntry> localWrites,
    required Iterable<PartnerSyncLedgerEntry> remoteWrites,
    Iterable<PartnerSyncLedgerEntry> baseEntries = const [],
  }) {
    final authorized = Set<String>.unmodifiable(authorizedDeviceIds);
    final baseById = _byId(baseEntries);
    final localById = _byId(localWrites);
    final remoteById = _byId(remoteWrites);
    final allIds = <String>{...localById.keys, ...remoteById.keys}.toList()
      ..sort();
    final accepted = <PartnerSyncLedgerEntry>[];
    final conflicts = <PartnerSyncConflict>[];
    final warnings = <String>[];

    for (final id in allIds) {
      final local = localById[id];
      final remote = remoteById[id];
      final candidate = remote ?? local;
      if (candidate == null) continue;
      if (!authorized.contains(candidate.deviceId)) {
        warnings.add('device ${candidate.deviceId} is not authorized');
        continue;
      }
      if (local != null &&
          remote != null &&
          local.deviceId != remote.deviceId) {
        conflicts.add(
          PartnerSyncConflict(
            entryId: id,
            local: local,
            remote: remote,
            reason: 'same entry id targets different devices',
          ),
        );
        continue;
      }

      final base = baseById[id];
      if (local != null && remote != null) {
        if (local.sameBusinessStateAs(remote)) {
          accepted.add(_newer(local, remote));
          continue;
        }
        final localChanged = base == null || !local.sameBusinessStateAs(base);
        final remoteChanged = base == null || !remote.sameBusinessStateAs(base);
        if (localChanged && remoteChanged) {
          conflicts.add(
            PartnerSyncConflict(
              entryId: id,
              local: local,
              remote: remote,
              reason: 'both sides changed the same entry',
            ),
          );
          continue;
        }
        accepted.add(remoteChanged ? remote : local);
        continue;
      }

      accepted.add(candidate);
    }

    return PartnerSyncMergeResult(
      accepted: accepted,
      conflicts: conflicts,
      warnings: warnings,
    );
  }

  Map<String, PartnerSyncLedgerEntry> _byId(
    Iterable<PartnerSyncLedgerEntry> entries,
  ) {
    return {for (final entry in entries) entry.id: entry};
  }

  PartnerSyncLedgerEntry _newer(
    PartnerSyncLedgerEntry left,
    PartnerSyncLedgerEntry right,
  ) {
    if (left.revision != right.revision) {
      return left.revision > right.revision ? left : right;
    }
    if (left.updatedAt != right.updatedAt) {
      return left.updatedAt.isAfter(right.updatedAt) ? left : right;
    }
    return left.id.compareTo(right.id) <= 0 ? left : right;
  }
}

void _requireNonEmpty(String value, String name) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
}
