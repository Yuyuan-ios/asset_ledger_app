import 'dart:math';

/// R5.22-A: groups the multiple `sync_outbox` rows produced inside a single
/// business transaction so cloud push can later replay them as one ordered unit.
///
/// Create exactly one group at a multi-entity cluster's transaction entry, then
/// pass [id] plus a fresh [nextSequence] to every enqueue call inside that
/// transaction. Single-row paths do not need a group and may keep
/// transaction_group_id / local_sequence null.
///
/// This intentionally does not touch the DB or SyncManager push side; it only
/// allocates the grouping metadata. Push ordering / grouped replay is R5.22-B.
class SyncTransactionGroup {
  SyncTransactionGroup(this.id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'transaction group id must not be empty');
    }
  }

  /// Collision-safe `txn-<128-bit hex>` id, mirroring the
  /// SecureRandomOutboxIdGenerator convention (`Random.secure()`, 16 bytes).
  /// Inject [random] in tests for a deterministic id.
  factory SyncTransactionGroup.create({Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return SyncTransactionGroup('txn-$hex');
  }

  final String id;
  int _sequence = 0;

  /// Returns the next 1-based local sequence within this group (1, 2, 3, …).
  /// Each call advances the counter, so callers must request one sequence per
  /// outbox row in business-causal order.
  int nextSequence() => ++_sequence;
}
