part of 'sync_manager.dart';

/// R5.23: per-entity folding of due pending rows.
///
/// Rules (only applied when group-safety holds, see below):
/// - If an entity's snapshot ends with `delete`:
///   - and an earlier `create` exists → fold every row for that entity
///     (create + any intermediate updates + delete). Server never sees it.
///   - else (earlier rows are only updates) → fold every update; keep the
///     delete to push normally.
/// - Otherwise (no terminating delete) → no folding for that entity.
///   This intentionally preserves create→update sequences as-is: there is
///   no safe in-place payload merge today (R5.23 is folding, not deep
///   payload merge).
///
/// Group safety: a row is foldable only if it is ungrouped, OR every row of
/// its `transaction_group_id` in this snapshot belongs to the SAME
/// `(entity_type, entity_id)` being folded. Mixed groups (e.g. an account
/// settlement cluster: payment + write-off + project status) are NOT
/// folded, so R5.22-A's 1..n local_sequence invariant is preserved (a
/// surviving group of any size remains the original 1..n).
_FoldDecision _foldPendingRows(List<SyncOutboxEntry> pending) {
  if (pending.isEmpty) {
    return const _FoldDecision(remaining: [], foldedIds: []);
  }

  // Group the snapshot by entity for per-entity analysis, and by
  // transaction_group for the group-safety check.
  final perEntity = <String, List<SyncOutboxEntry>>{};
  final perGroup = <String, List<SyncOutboxEntry>>{};
  for (final entry in pending) {
    final key = '${entry.entityType}::${entry.entityId}';
    (perEntity[key] ??= <SyncOutboxEntry>[]).add(entry);
    final gid = entry.transactionGroupId;
    if (gid != null) {
      (perGroup[gid] ??= <SyncOutboxEntry>[]).add(entry);
    }
  }

  final foldedIds = <String>{};
  perEntity.forEach((entityKey, rows) {
    if (rows.length < 2) return; // single row has nothing to fold against
    // Stable order: by created_at ASC, then id ASC. Mirrors the existing
    // listPending base order + a deterministic tie-break.
    final sorted = [...rows]
      ..sort((a, b) {
        final byCreated = a.createdAt.compareTo(b.createdAt);
        if (byCreated != 0) return byCreated;
        return a.id.compareTo(b.id);
      });

    final lastOp = sorted.last.operation;
    if (lastOp != 'delete') return; // R5.23 only folds delete-terminated runs

    // Decide which rows we WANT to fold for this entity.
    final hasCreateBeforeDelete = sorted
        .take(sorted.length - 1)
        .any((r) => r.operation == 'create');
    final candidates = <SyncOutboxEntry>[];
    if (hasCreateBeforeDelete) {
      // Fold every row: the entity was created and deleted locally; server
      // never needs to see either op.
      candidates.addAll(sorted);
    } else {
      // No create in this snapshot — just collapse stale updates into the
      // delete: fold every update, keep the delete.
      for (final entry in sorted) {
        if (entry.operation == 'update') candidates.add(entry);
      }
      if (candidates.isEmpty) return; // nothing to fold (e.g. lone delete)
    }

    // Group safety: every candidate must be either ungrouped, or in a
    // group whose entire snapshot membership belongs to this entity.
    for (final candidate in candidates) {
      final gid = candidate.transactionGroupId;
      if (gid == null) continue; // ungrouped — always safe to fold
      final groupRows = perGroup[gid]!;
      final uniform = groupRows.every(
        (r) => '${r.entityType}::${r.entityId}' == entityKey,
      );
      if (!uniform) {
        // Mixed group (e.g. settlement cluster) — abort folding for this
        // entity to keep the surviving group as the original 1..n
        // sequence. The rows will push normally; a future revision can
        // teach folding to renumber groups safely.
        return;
      }
    }

    for (final entry in candidates) {
      foldedIds.add(entry.id);
    }
  });

  if (foldedIds.isEmpty) {
    return _FoldDecision(remaining: pending, foldedIds: const []);
  }
  final remaining = [
    for (final entry in pending)
      if (!foldedIds.contains(entry.id)) entry,
  ];
  return _FoldDecision(remaining: remaining, foldedIds: foldedIds.toList());
}

List<_PushGroup> _buildOrderedSyncPushGroups(List<SyncOutboxEntry> pending) {
  final grouped = <String, List<SyncOutboxEntry>>{};
  final singles = <SyncOutboxEntry>[];
  for (final entry in pending) {
    final groupId = entry.transactionGroupId;
    if (groupId != null) {
      (grouped[groupId] ??= <SyncOutboxEntry>[]).add(entry);
    } else {
      singles.add(entry);
    }
  }

  final groups = <_PushGroup>[];
  grouped.forEach((groupId, rows) {
    rows.sort((a, b) => (a.localSequence ?? 0).compareTo(b.localSequence ?? 0));
    final minCreatedAt = rows
        .map((r) => r.createdAt)
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    groups.add(
      _PushGroup(
        sortCreatedAt: minCreatedAt,
        tieKey: groupId,
        rows: rows,
        invalidReason: _groupInvalidReason(groupId, rows),
      ),
    );
  });

  for (final entry in singles) {
    // 未分组行不应带 local_sequence；带了即非法（防御旧库/坏数据）。
    final invalidReason = entry.localSequence != null
        ? 'ungrouped row ${entry.id} has local_sequence '
              '${entry.localSequence} but no transaction_group_id'
        : null;
    groups.add(
      _PushGroup(
        sortCreatedAt: entry.createdAt,
        tieKey: entry.id,
        rows: [entry],
        invalidReason: invalidReason,
      ),
    );
  }

  groups.sort((a, b) {
    final byCreated = a.sortCreatedAt.compareTo(b.sortCreatedAt);
    if (byCreated != 0) return byCreated;
    return a.tieKey.compareTo(b.tieKey);
  });
  return groups;
}

/// 校验一个已分组组的 local_sequence：必须存在、>0、且排序后恰为 1..n
/// （连续且不重复）。返回 null 表示合法，否则返回诊断原因。
String? _groupInvalidReason(String groupId, List<SyncOutboxEntry> rows) {
  if (groupId.trim().isEmpty) {
    return 'blank transaction_group_id';
  }
  final sequences = <int>[];
  for (final row in rows) {
    final seq = row.localSequence;
    if (seq == null) {
      return 'row ${row.id} in group $groupId has null local_sequence';
    }
    if (seq <= 0) {
      return 'row ${row.id} in group $groupId has non-positive '
          'local_sequence $seq';
    }
    sequences.add(seq);
  }
  sequences.sort();
  for (var i = 0; i < sequences.length; i += 1) {
    if (sequences[i] != i + 1) {
      // 同时覆盖重复（如 [1,1,2]）与跳号（如 [1,3]）。
      return 'group $groupId local_sequence is not contiguous 1..n '
          '(got $sequences)';
    }
  }
  return null;
}
