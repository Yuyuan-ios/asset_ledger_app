import '../cloud/api_client.dart';
import 'sync_outbox_entry.dart';
import 'sync_repositories.dart';
import 'sync_state_repository.dart';

/// R5.21 抛出的 push gate 阻断异常。
///
/// `SyncManager.pushPending` 在检测到 `sync_state` 中 push gate 为非空
/// （restore 后未 reconcile）时抛出此异常，明确告知调用方推送被门控阻断，
/// 而不是发生网络/服务端错误。调用方应在完成 restore reconcile 后清除门控
/// 才能继续推送。
class SyncPushBlockedException implements Exception {
  const SyncPushBlockedException(this.reason);

  /// 当前 push gate 的原因，例如 [SyncStateRepository.gateRestorePending]。
  final String reason;

  @override
  String toString() => 'SyncPushBlockedException(reason: $reason)';
}

/// R5.22-B push 结果汇总（取代旧的纯 int 返回，便于调用方区分成功/失败/跳过/非法）。
class SyncPushResult {
  const SyncPushResult({
    this.pushed = 0,
    this.failed = 0,
    this.skipped = 0,
    this.invalid = 0,
  });

  /// 成功发送并 ack（删除）的行数。
  final int pushed;

  /// 发送失败、已 bump retry/backoff、仍保留在 outbox 的行数。
  final int failed;

  /// 因同组更早的行失败而本轮未发送的同组后续行数（保持 pending）。
  final int skipped;

  /// 因元数据非法（缺序号 / 序号<=0 / 同组序号重复或不连续）未发送、
  /// 保守 bump retry 的行数。
  final int invalid;

  /// 本轮实际调用 CloudApiClient.send 的行数。
  int get attempted => pushed + failed;

  @override
  String toString() =>
      'SyncPushResult(pushed: $pushed, failed: $failed, '
      'skipped: $skipped, invalid: $invalid)';
}

class SyncManager {
  SyncManager({
    required SyncOutboxPushRepository outboxRepository,
    required CloudApiClient apiClient,
    SyncStateRepository syncStateRepository = const LocalSyncStateRepository(),
    DateTime Function()? now,
  }) : _outboxRepository = outboxRepository,
       _apiClient = apiClient,
       _syncStateRepository = syncStateRepository,
       _now = now ?? DateTime.now;

  final SyncOutboxPushRepository _outboxRepository;
  final CloudApiClient _apiClient;
  final SyncStateRepository _syncStateRepository;
  final DateTime Function() _now;

  /// 指数退避（秒）：第 1 次失败 60s、第 2 次 5min、第 3 次及以后 30min。
  static const List<int> _backoffSeconds = [60, 300, 1800];

  Future<SyncPushResult> pushPending({int limit = 50}) async {
    // R5.21 push gate：restore 后必须先 reconcile，才允许把本地 outbox 推到云端。
    // 在 listPending 与 CloudApiClient.send 之前短路，避免任何残留 pending 行
    // 在 gate 期间被读出/发送/标记。
    final gateReason = await _syncStateRepository.readPushGate();
    if (gateReason != null) {
      throw SyncPushBlockedException(gateReason);
    }

    final pending = await _outboxRepository.listPending(limit: limit);
    // R5.22-B：按 transaction_group_id / local_sequence 把 pending 重排为
    // "组内因果有序、组间稳定" 的发送顺序。
    final groups = _buildOrderedGroups(pending);

    var pushed = 0;
    var failed = 0;
    var skipped = 0;
    var invalid = 0;

    for (final group in groups) {
      // 非法元数据组：保守处理 —— 不调用 CloudApiClient，对每行 bump retry，
      // 写明确诊断 last_error，并打 backoff。其他合法组不受影响继续推送。
      final invalidReason = group.invalidReason;
      if (invalidReason != null) {
        for (final entry in group.rows) {
          await _markFailed(entry, 'invalid_metadata: $invalidReason');
          invalid += 1;
        }
        continue;
      }

      var groupFailed = false;
      for (final entry in group.rows) {
        // 同组更早的行已失败 → 后续行不发送，避免破坏因果顺序（保持 pending）。
        if (groupFailed) {
          skipped += 1;
          continue;
        }

        final outcome = await _send(entry);
        if (outcome.success) {
          // 成功 ack：删除该行，保证下次 listPending 不再读到、不重复 push。
          await _outboxRepository.deleteAcknowledged(entry.id);
          pushed += 1;
        } else {
          await _markFailed(entry, outcome.error);
          failed += 1;
          groupFailed = true;
        }
      }
    }

    return SyncPushResult(
      pushed: pushed,
      failed: failed,
      skipped: skipped,
      invalid: invalid,
    );
  }

  Future<_SendOutcome> _send(SyncOutboxEntry entry) async {
    try {
      final response = await _apiClient.send(
        ApiRequest(
          method: 'POST',
          path: '/sync/outbox',
          bodyJson: entry.payloadJson,
          headers: {'x-payload-hash': entry.payloadHash},
        ),
      );
      if (response.isSuccess) {
        return const _SendOutcome.ok();
      }
      final err = response.error;
      return _SendOutcome.fail(
        err == null
            ? 'http_${response.statusCode}'
            : '${err.code}: ${err.message}',
      );
    } catch (e) {
      return _SendOutcome.fail(e.toString());
    }
  }

  Future<void> _markFailed(SyncOutboxEntry entry, String error) async {
    await _outboxRepository.markFailed(
      id: entry.id,
      lastError: error,
      nextRetryAtIso: _nextRetryAtIso(entry.retryCount),
    );
  }

  /// 基于当前（失败前）retry_count 计算本次失败后的下一次可重试时间。
  /// 失败后 retry_count 自增为 N，对应 [_backoffSeconds][N-1]（N>=3 取 30min）。
  String _nextRetryAtIso(int currentRetryCount) {
    final newCount = currentRetryCount + 1;
    final index = (newCount - 1).clamp(0, _backoffSeconds.length - 1);
    final seconds = _backoffSeconds[index];
    return _now().toUtc().add(Duration(seconds: seconds)).toIso8601String();
  }

  /// 把 pending 行重排为有序的发送组。
  ///
  /// - 已分组行（transaction_group_id != null）：同组内按 local_sequence ASC。
  /// - 未分组行（transaction_group_id == null）：各自成为单行组。
  /// - 组间顺序：组内最小 created_at ASC；相同再按 tieKey ASC
  ///   （分组用 group id，未分组用 row id）。
  /// - 同时对每组做非法元数据检测，记录 invalidReason（不在此处发送）。
  List<_PushGroup> _buildOrderedGroups(List<SyncOutboxEntry> pending) {
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
      rows.sort(
        (a, b) => (a.localSequence ?? 0).compareTo(b.localSequence ?? 0),
      );
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
}

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
  const _SendOutcome.ok() : success = true, error = '';
  const _SendOutcome.fail(this.error) : success = false;

  final bool success;
  final String error;
}
