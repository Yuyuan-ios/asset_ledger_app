part of 'sync_manager.dart';

class _PushGroup {
  _PushGroup({
    required this.sortCreatedAt,
    required this.tieKey,
    required this.rows,
    required this.invalidReason,
  });

  final String sortCreatedAt;
  final String tieKey;
  final List<SyncOutboxEntry> rows;
  final String? invalidReason;
}

class _SendOutcome {
  const _SendOutcome.ok({this.serverSeq, this.newVersion})
    : success = true,
      error = '';
  const _SendOutcome.fail(this.error)
    : success = false,
      serverSeq = null,
      newVersion = null;

  final bool success;
  final String error;
  final int? serverSeq;
  final int? newVersion;
}

/// R5.23: result of folding the due pending snapshot. [remaining] preserves
/// the input order minus folded ids; [foldedIds] is the set of outbox ids to
/// delete via [SyncOutboxPushRepository.deleteSuperseded] before push.
class _FoldDecision {
  const _FoldDecision({required this.remaining, required this.foldedIds});

  final List<SyncOutboxEntry> remaining;
  final List<String> foldedIds;
}
