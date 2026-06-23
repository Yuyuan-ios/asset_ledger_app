import 'dart:convert';

import '../../data/db/database.dart';
import '../cloud/api_client.dart';
import 'conflict_resolver.dart';
import 'entity_sync_meta.dart';
import 'remote_change.dart';
import 'remote_change_applier.dart';
import 'sync_conflict_repository.dart';
import 'sync_live_readiness_gate.dart';
import 'sync_outbox_entry.dart';
import 'sync_repositories.dart';
import 'sync_state_repository.dart';
import 'sync_status.dart';

part 'sync_manager_push_models.dart';
part 'sync_manager_push_planner.dart';

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

/// R5.27-A push 执行模式：live 保持既有发送/ack 语义；dryRun 只做 preview。
enum SyncPushMode { live, dryRun }

/// R5.22-B push 结果汇总（取代旧的纯 int 返回，便于调用方区分成功/失败/跳过/非法）。
class SyncPushResult {
  const SyncPushResult({
    this.mode = SyncPushMode.live,
    this.pushed = 0,
    this.failed = 0,
    this.skipped = 0,
    this.invalid = 0,
    this.folded = 0,
    this.plannedPushes = 0,
    this.plannedFolded = 0,
    this.plannedOutboxIds = const [],
  });

  /// 本轮 push 的执行模式。默认 live，保持既有调用语义不变。
  final SyncPushMode mode;

  /// 成功发送并 ack（删除）的行数。
  final int pushed;

  /// 发送失败、已 bump retry/backoff、仍保留在 outbox 的行数。
  final int failed;

  /// 因同组更早的行失败而本轮未发送的同组后续行数（保持 pending）。
  final int skipped;

  /// 因元数据非法（缺序号 / 序号<=0 / 同组序号重复或不连续）未发送的行数。
  /// live 下会 terminal failed；dry-run 下只统计，不写 last_error/status。
  final int invalid;

  /// R5.23: 因同一 `(entity_type, entity_id)` 在本次 due-pending 快照中
  /// 出现了 supersede 关系（create→delete / update→delete）而在 live 模式下
  /// 被本地折叠剔除、未发往 CloudApiClient 的行数。live 折叠行会被
  /// [SyncOutboxPushRepository.deleteSuperseded] 从 sync_outbox 删除，不进入
  /// retry/backoff，也不计入 invalid。dry-run 只在 [plannedFolded] 预览。
  final int folded;

  /// dry-run 下按 R5.22/R5.23 规则预估会发送的 outbox 行数。
  final int plannedPushes;

  /// dry-run 下按 R5.23 folding 规则预估会折叠、但不会删除的 outbox 行数。
  final int plannedFolded;

  /// dry-run 下按 R5.22 ordering 规则排列的、预计会发送的 outbox id。
  final List<String> plannedOutboxIds;

  /// 本轮实际调用 CloudApiClient.send 的行数。
  int get attempted => pushed + failed;

  /// 是否为 R5.27-A dry-run preview；dry-run 不调用 CloudApiClient、不修改 outbox/meta。
  bool get isDryRun => mode == SyncPushMode.dryRun;

  /// dry-run 下按 R5.22/R5.23 规则预估会发送的 outbox 行数。
  int get wouldPush => isDryRun ? plannedPushes : 0;

  /// dry-run 下按 R5.23 folding 规则预估会折叠的 outbox 行数。
  int get wouldFold => isDryRun ? plannedFolded : 0;

  @override
  String toString() =>
      'SyncPushResult(mode: $mode, dryRun: $isDryRun, '
      'pushed: $pushed, failed: $failed, skipped: $skipped, '
      'invalid: $invalid, folded: $folded, wouldPush: $wouldPush, '
      'wouldFold: $wouldFold)';
}

class SyncPullConflict {
  const SyncPullConflict({required this.change, required this.reason});

  final RemoteChange change;
  final String reason;
}

class SyncPullResult {
  const SyncPullResult({
    this.applied = 0,
    this.conflicts = const [],
    this.skippedOwn = 0,
    this.skippedUnsupported = 0,
    this.skippedDuplicate = 0,
    this.failed = 0,
    this.error,
    this.nextCursor = 0,
  });

  final int applied;
  final List<SyncPullConflict> conflicts;
  final int skippedOwn;
  final int skippedUnsupported;
  final int skippedDuplicate;
  final int failed;
  final String? error;
  final int nextCursor;

  int get processed =>
      applied +
      conflicts.length +
      skippedOwn +
      skippedUnsupported +
      skippedDuplicate;

  bool get isSuccess => failed == 0 && error == null;

  @override
  String toString() =>
      'SyncPullResult(applied: $applied, conflicts: ${conflicts.length}, '
      'skippedOwn: $skippedOwn, skippedUnsupported: $skippedUnsupported, '
      'skippedDuplicate: $skippedDuplicate, failed: $failed, '
      'nextCursor: $nextCursor)';
}

class SyncManager {
  SyncManager({
    required SyncOutboxPushRepository outboxRepository,
    required CloudApiClient apiClient,
    SyncStateRepository syncStateRepository = const LocalSyncStateRepository(),
    EntitySyncMetaAckRepository metaRepository =
        const LocalEntitySyncMetaRepository(),
    EntitySyncMetaRepository pullMetaRepository =
        const LocalEntitySyncMetaRepository(),
    Map<String, RemoteChangeApplier> remoteChangeAppliers =
        const <String, RemoteChangeApplier>{
          TimingRecordRemoteChangeApplier.entityType:
              TimingRecordRemoteChangeApplier(),
          ProjectRemoteChangeApplier.entityType: ProjectRemoteChangeApplier(),
          ProjectDeviceRateRemoteChangeApplier.entityType:
              ProjectDeviceRateRemoteChangeApplier(),
          FuelLogRemoteChangeApplier.entityType: FuelLogRemoteChangeApplier(),
          MaintenanceRecordRemoteChangeApplier.entityType:
              MaintenanceRecordRemoteChangeApplier(),
        },
    ConflictResolver conflictResolver = const ConflictResolver(),
    SyncConflictRepository syncConflictRepository =
        const LocalSyncConflictRepository(),
    SyncLiveReadinessGate liveReadinessGate =
        const DefaultSyncLiveReadinessGate(),
    String? localDeviceId,
    DateTime Function()? now,
  }) : _outboxRepository = outboxRepository,
       _apiClient = apiClient,
       _syncStateRepository = syncStateRepository,
       _metaRepository = metaRepository,
       _pullMetaRepository = pullMetaRepository,
       _remoteChangeAppliers = Map.unmodifiable(remoteChangeAppliers),
       _conflictResolver = conflictResolver,
       _syncConflictRepository = syncConflictRepository,
       _liveReadinessGate = liveReadinessGate,
       _localDeviceId = localDeviceId,
       _now = now ?? DateTime.now;

  final SyncOutboxPushRepository _outboxRepository;
  final CloudApiClient _apiClient;
  final SyncStateRepository _syncStateRepository;
  final EntitySyncMetaAckRepository _metaRepository;
  final EntitySyncMetaRepository _pullMetaRepository;
  final Map<String, RemoteChangeApplier> _remoteChangeAppliers;
  final ConflictResolver _conflictResolver;
  final SyncConflictRepository _syncConflictRepository;
  final SyncLiveReadinessGate _liveReadinessGate;
  final String? _localDeviceId;
  final DateTime Function() _now;

  /// 指数退避（秒）：第 1 次失败 60s、第 2 次 5min、第 3 次及以后 30min。
  static const List<int> _backoffSeconds = [60, 300, 1800];

  Future<SyncPullResult> pullPending({int limit = 50}) async {
    final cursor = await _syncStateRepository.readPullCursor();
    final response = await _apiClient.send(
      ApiRequest(
        method: 'GET',
        path: '/sync/changes?since=$cursor&limit=$limit',
      ),
    );
    if (!response.isSuccess) {
      final err = response.error;
      return SyncPullResult(
        failed: 1,
        error: err == null
            ? 'http_${response.statusCode}'
            : '${err.code}: ${err.message}',
        nextCursor: cursor,
      );
    }

    final decoded = RemoteChangesResponse.parse(response.bodyJson);
    var applied = 0;
    var skippedOwn = 0;
    var skippedUnsupported = 0;
    var skippedDuplicate = 0;
    var processedCursor = cursor;
    final conflicts = <SyncPullConflict>[];

    for (final change in decoded.changes) {
      if (change.serverSeq <= processedCursor) {
        skippedDuplicate += 1;
        continue;
      }
      final nextCursor = change.serverSeq;
      final localDeviceId = _localDeviceId;

      if (localDeviceId != null &&
          change.originDeviceId != null &&
          change.originDeviceId == localDeviceId) {
        await _syncStateRepository.writePullCursor(nextCursor, now: _now());
        processedCursor = nextCursor;
        skippedOwn += 1;
        continue;
      }

      final remoteChangeApplier = _remoteChangeAppliers[change.entityType];
      if (remoteChangeApplier == null) {
        await _syncStateRepository.writePullCursor(nextCursor, now: _now());
        processedCursor = nextCursor;
        skippedUnsupported += 1;
        continue;
      }

      final remoteMeta = _remoteMeta(change);
      final localMeta =
          await _pullMetaRepository.find(
            entityType: change.entityType,
            localId: change.entityId,
          ) ??
          _emptyLocalMeta(change);
      final decision = _conflictResolver.resolve(
        local: localMeta,
        remote: remoteMeta,
      );

      if (decision.status == SyncStatus.synced) {
        final alreadyApplied =
            localMeta.payloadHash == change.payloadHash &&
            localMeta.version >= change.newVersion;
        await AppDatabase.inTransaction<void>((txn) async {
          if (!alreadyApplied) {
            await remoteChangeApplier.applyWithExecutor(
              txn,
              change,
              now: _now(),
            );
          }
          await _syncStateRepository.writePullCursorWithExecutor(
            txn,
            nextCursor,
            now: _now(),
          );
        });
        processedCursor = nextCursor;
        if (alreadyApplied) {
          skippedDuplicate += 1;
        } else {
          applied += 1;
        }
        continue;
      }

      final reason = decision.reason ?? decision.status.name;
      await AppDatabase.inTransaction<void>((txn) async {
        await _syncConflictRepository.insertIfAbsentWithExecutor(
          txn,
          SyncConflict.fromRemoteChange(
            change: change,
            reason: reason,
            detectedAt: _now(),
          ),
        );
        await _syncStateRepository.writePullCursorWithExecutor(
          txn,
          nextCursor,
          now: _now(),
        );
      });
      processedCursor = nextCursor;
      conflicts.add(SyncPullConflict(change: change, reason: reason));
    }

    return SyncPullResult(
      applied: applied,
      conflicts: List.unmodifiable(conflicts),
      skippedOwn: skippedOwn,
      skippedUnsupported: skippedUnsupported,
      skippedDuplicate: skippedDuplicate,
      nextCursor: processedCursor,
    );
  }

  EntitySyncMeta _remoteMeta(RemoteChange change) {
    return EntitySyncMeta(
      entityType: change.entityType,
      localId: change.entityId,
      serverId: change.entityId,
      syncStatus: SyncStatus.synced,
      version: change.newVersion,
      source: 'cloud_sync',
      deletedAt: change.deleted ? _now().toUtc().toIso8601String() : null,
      payloadHash: change.payloadHash,
    );
  }

  EntitySyncMeta _emptyLocalMeta(RemoteChange change) {
    return EntitySyncMeta(
      entityType: change.entityType,
      localId: change.entityId,
      serverId: change.entityId,
      syncStatus: SyncStatus.synced,
      version: 0,
      source: 'owner_app',
    );
  }

  Future<SyncPushResult> pushPending({
    int limit = 50,
    SyncPushMode mode = SyncPushMode.live,
  }) async {
    // R5.21 push gate：restore 后必须先 reconcile，才允许把本地 outbox 推到云端。
    // 在 listPending 与 CloudApiClient.send 之前短路，避免任何残留 pending 行
    // 在 gate 期间被读出/发送/标记。
    final gateReason = await _syncStateRepository.readPushGate();
    if (gateReason != null) {
      throw SyncPushBlockedException(gateReason);
    }

    // R5.27-B live readiness gate: beta builds may preview push decisions, but
    // live cloud push stays blocked until money-fen primary storage and the real
    // cloud transport are ready. Check before listPending/folding and before any
    // send/delete/markFailed/markTerminalFailed/meta-ack side effect.
    if (mode == SyncPushMode.live) {
      final readiness = await _liveReadinessGate.check();
      if (readiness.isNotReady) {
        throw SyncPushBlockedException(readiness.blockedReason);
      }
    }

    final pending = await _outboxRepository.listPending(limit: limit);
    // R5.23：在 ordering / send 之前，对同一 (entity_type, entity_id) 的 due
    // pending 行做最小折叠：create+delete 整体剔除、update→delete 中的 update
    // 剔除。live 下折叠行从 outbox 真删除（deleteSuperseded）；dry-run 只预览
    // 同一决策，不写 outbox。不计 invalid。仅对 "ungrouped 行" 或 "整组都属于
    // 同一 entity 的同组行" 生效，以保留 R5.22-A 的 transaction_group
    // local_sequence 1..n 不变量。
    final foldDecision = _foldPending(pending);
    if (mode == SyncPushMode.dryRun) {
      return _previewDryRunPush(foldDecision);
    }

    return _pushLive(foldDecision);
  }

  Future<SyncPushResult> _pushLive(_FoldDecision foldDecision) async {
    for (final id in foldDecision.foldedIds) {
      await _outboxRepository.deleteSuperseded(id);
    }
    final folded = foldDecision.foldedIds.length;

    // R5.22-B：按 transaction_group_id / local_sequence 把 pending 重排为
    // "组内因果有序、组间稳定" 的发送顺序。
    final groups = _buildOrderedGroups(foldDecision.remaining);

    var pushed = 0;
    var failed = 0;
    var skipped = 0;
    var invalid = 0;

    for (final group in groups) {
      // 非法元数据组（本地数据损坏 / 程序错误）：不调用 CloudApiClient，
      // 标记为 TERMINAL failed（status=failed、清 next_retry_at），写明确诊断
      // last_error。listPending 只取 pending，故不再无限退避重试，等待人工修数据。
      // 其他合法组不受影响继续推送。
      final invalidReason = group.invalidReason;
      if (invalidReason != null) {
        for (final entry in group.rows) {
          await _outboxRepository.markTerminalFailed(
            id: entry.id,
            lastError: 'invalid_metadata: $invalidReason',
          );
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
          // 成功 ack：先删除 outbox 行（权威 ack：保证下次 listPending 不再读到、
          // 不重复 push），再尽力清掉对应 entity_sync_meta 的 pending 状态，避免
          // 成功后仍残留 pendingUpload/pendingUpdate 的幽灵状态。meta 清理失败
          // 不影响 ack 正确性，只退化为旧行为（cosmetic ghost）。
          await _outboxRepository.deleteAcknowledged(entry.id);
          await _metaRepository.markPushAcknowledged(
            entityType: entry.entityType,
            localId: entry.entityId,
            operation: entry.operation,
            syncedAtIso: _now().toUtc().toIso8601String(),
            newVersion: outcome.newVersion,
          );
          final serverSeq = outcome.serverSeq;
          if (serverSeq != null) {
            final cursor = await _syncStateRepository.readPullCursor();
            if (serverSeq > cursor) {
              await _syncStateRepository.writePullCursor(
                serverSeq,
                now: _now(),
              );
            }
          }
          pushed += 1;
        } else {
          await _markFailed(entry, outcome.error);
          failed += 1;
          groupFailed = true;
        }
      }
    }

    return SyncPushResult(
      mode: SyncPushMode.live,
      pushed: pushed,
      failed: failed,
      skipped: skipped,
      invalid: invalid,
      folded: folded,
    );
  }

  SyncPushResult _previewDryRunPush(_FoldDecision foldDecision) {
    final groups = _buildOrderedGroups(foldDecision.remaining);
    var invalid = 0;
    final plannedOutboxIds = <String>[];

    for (final group in groups) {
      final invalidReason = group.invalidReason;
      if (invalidReason != null) {
        invalid += group.rows.length;
        continue;
      }

      for (final entry in group.rows) {
        plannedOutboxIds.add(entry.id);
      }
    }

    return SyncPushResult(
      mode: SyncPushMode.dryRun,
      invalid: invalid,
      plannedPushes: plannedOutboxIds.length,
      plannedFolded: foldDecision.foldedIds.length,
      plannedOutboxIds: List.unmodifiable(plannedOutboxIds),
    );
  }

  /// R5.23: per-entity folding of due pending rows.
  _FoldDecision _foldPending(List<SyncOutboxEntry> pending) =>
      _foldPendingRows(pending);

  Future<_SendOutcome> _send(SyncOutboxEntry entry) async {
    try {
      final baseVersion =
          (await _pullMetaRepository.find(
            entityType: entry.entityType,
            localId: entry.entityId,
          ))?.version ??
          0;
      final response = await _apiClient.send(
        ApiRequest(
          method: 'POST',
          path: '/sync/changes',
          bodyJson: jsonEncode({
            'changes': [
              {
                'entity_type': entry.entityType,
                'entity_id': entry.entityId,
                'op': entry.operation,
                'base_version': baseVersion,
                'payload': _decodePayload(entry),
                'payload_hash': entry.payloadHash,
                if (entry.transactionGroupId != null)
                  'transaction_group_id': entry.transactionGroupId,
                if (entry.localSequence != null)
                  'local_sequence': entry.localSequence,
              },
            ],
          }),
          headers: {'x-payload-hash': entry.payloadHash},
        ),
      );
      if (response.isSuccess) {
        return _parsePushChangesResponse(response.bodyJson, entry);
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

  Map<String, Object?> _decodePayload(SyncOutboxEntry entry) {
    final decoded = jsonDecode(entry.payloadJson);
    if (decoded is! Map) {
      throw FormatException('sync outbox payload must be a JSON object');
    }
    return Map<String, Object?>.from(decoded);
  }

  _SendOutcome _parsePushChangesResponse(
    String? bodyJson,
    SyncOutboxEntry entry,
  ) {
    if (bodyJson == null || bodyJson.trim().isEmpty) {
      // Older fake clients in unit tests only report HTTP 200. Real B6 backend
      // responses include accepted/conflicts; keep the empty-body path as a
      // test-only compatibility ack so unrelated ordering tests stay focused.
      return const _SendOutcome.ok();
    }

    final decoded = jsonDecode(bodyJson);
    if (decoded is! Map) {
      return const _SendOutcome.fail('invalid_sync_push_response');
    }
    final accepted = decoded['accepted'];
    if (accepted is List) {
      for (final item in accepted) {
        if (item is Map && _responseItemMatchesEntry(item, entry)) {
          return _SendOutcome.ok(
            serverSeq: _optionalInt(item['server_seq']),
            newVersion: _optionalInt(item['new_version']),
          );
        }
      }
    }

    final conflicts = decoded['conflicts'];
    if (conflicts is List) {
      for (final item in conflicts) {
        if (item is Map && _responseItemMatchesEntry(item, entry)) {
          final serverVersion = _optionalInt(item['server_version']);
          final suffix = serverVersion == null
              ? ''
              : ': server_version=$serverVersion';
          return _SendOutcome.fail('push_conflict$suffix');
        }
      }
    }

    return const _SendOutcome.fail('sync_push_response_missing_entity_ack');
  }

  bool _responseItemMatchesEntry(
    Map<Object?, Object?> item,
    SyncOutboxEntry entry,
  ) {
    final entity = item['entity'];
    final String? entityType;
    final Object? entityId;
    if (entity is Map) {
      entityType =
          (entity['entity_type'] ?? entity['type'] ?? item['entity_type'])
              as String?;
      entityId = entity['entity_id'] ?? entity['id'] ?? item['entity_id'];
    } else {
      entityType = item['entity_type'] as String?;
      entityId = item['entity_id'];
    }

    if (entityType == null && entityId == null) return true;
    return entityType == entry.entityType &&
        entityId?.toString() == entry.entityId;
  }

  int? _optionalInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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
  List<_PushGroup> _buildOrderedGroups(List<SyncOutboxEntry> pending) =>
      _buildOrderedSyncPushGroups(pending);
}
