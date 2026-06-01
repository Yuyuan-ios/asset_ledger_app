import 'dart:convert';

import '../../core/operations/operation_confirmation_token.dart';

/// 阶段 D Step 47：operation_tokens 行模型。
///
/// 包裹 core 的纯模型 [OperationConfirmationToken]（避免与之混淆），并补充落库
/// 才有的可变状态时间戳与维护字段。
///
/// 列与 token_json 的关系：
/// - `token_json` 保存 [OperationConfirmationToken.toMap] 的 JSON，是**权威来源**，
///   且始终反映“当前” token（含当前 [status]）；状态迁移会整体重写本行（含 token_json）。
/// - 其余拍平列（id / operation_id / status / *_hash / 标志位 等）是为索引/查询而
///   去规范化的副本，[fromMap] 会逐项校验它们与 token_json 一致，不一致即抛
///   [ArgumentError]（侦测篡改 / 损坏行）。
class OperationTokenRecord {
  const OperationTokenRecord({
    required this.token,
    this.consumedAt,
    this.cancelledAt,
    this.lastError,
    this.metadataJson,
  });

  final OperationConfirmationToken token;
  final DateTime? consumedAt;
  final DateTime? cancelledAt;
  final String? lastError;
  final String? metadataJson;

  String get id => token.tokenId;
  String get operationId => token.operationId;
  OperationConfirmationTokenStatus get status => token.status;
  DateTime get createdAt => token.createdAt;
  DateTime get expiresAt => token.expiresAt;

  /// 用 [newStatus] 重建一份新记录（不可变；token 通过 fromMap 重建以复用其不变量）。
  OperationTokenRecord _withStatus(
    OperationConfirmationTokenStatus newStatus, {
    DateTime? consumedAt,
    DateTime? cancelledAt,
    String? lastError,
  }) {
    final map = Map<String, Object?>.from(token.toMap());
    map['status'] = newStatus.wireName;
    return OperationTokenRecord(
      token: OperationConfirmationToken.fromMap(map),
      consumedAt: consumedAt ?? this.consumedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      lastError: lastError ?? this.lastError,
      metadataJson: metadataJson,
    );
  }

  OperationTokenRecord asConsumed(DateTime at) => _withStatus(
    OperationConfirmationTokenStatus.consumed,
    consumedAt: at,
  );

  OperationTokenRecord asCancelled(DateTime at, {String? reason}) => _withStatus(
    OperationConfirmationTokenStatus.cancelled,
    cancelledAt: at,
    lastError: reason,
  );

  OperationTokenRecord asExpired() =>
      _withStatus(OperationConfirmationTokenStatus.expired);

  Map<String, Object?> toMap() {
    final t = token;
    return {
      'id': t.tokenId,
      'operation_id': t.operationId,
      'operation_type': t.operationType.wireName,
      'actor_type': t.actorType.wireName,
      'actor_id': t.actorId,
      'delegated_actor_type': t.delegatedActorType?.wireName,
      'delegated_actor_id': t.delegatedActorId,
      'session_id': t.sessionId,
      'source': t.source,
      'created_at': t.createdAt.toUtc().toIso8601String(),
      'expires_at': t.expiresAt.toUtc().toIso8601String(),
      'consumed_at': consumedAt?.toUtc().toIso8601String(),
      'cancelled_at': cancelledAt?.toUtc().toIso8601String(),
      'status': t.status.wireName,
      'input_hash': t.inputHash,
      'full_analysis_hash': t.fullAnalysisHash,
      'redacted_preview_hash': t.redactedPreviewHash,
      'actor_scope_hash': t.actorScopeHash,
      'freshness_required': t.freshnessRequired ? 1 : 0,
      'requires_reanalysis_before_execute':
          t.requiresReanalysisBeforeExecute ? 1 : 0,
      'one_time_use': t.oneTimeUse ? 1 : 0,
      'token_json': jsonEncode(t.toMap()),
      'last_error': lastError,
      'metadata_json': metadataJson,
    };
  }

  factory OperationTokenRecord.fromMap(Map<String, Object?> map) {
    final rawTokenJson = map['token_json'];
    if (rawTokenJson is! String || rawTokenJson.isEmpty) {
      throw ArgumentError.value(
        rawTokenJson,
        'token_json',
        'Missing or empty required token_json',
      );
    }
    final decoded = jsonDecode(rawTokenJson);
    if (decoded is! Map) {
      throw ArgumentError.value(
        rawTokenJson,
        'token_json',
        'token_json must decode to a JSON object',
      );
    }
    final token = OperationConfirmationToken.fromMap(
      Map<String, Object?>.from(decoded),
    );

    // 去规范化列必须与 token_json 一致（侦测篡改 / 损坏）。
    _expectString(map, 'id', token.tokenId);
    _expectString(map, 'operation_id', token.operationId);
    _expectString(map, 'operation_type', token.operationType.wireName);
    _expectString(map, 'actor_type', token.actorType.wireName);
    _expectNullableString(map, 'actor_id', token.actorId);
    _expectNullableString(
      map,
      'delegated_actor_type',
      token.delegatedActorType?.wireName,
    );
    _expectNullableString(map, 'delegated_actor_id', token.delegatedActorId);
    _expectNullableString(map, 'session_id', token.sessionId);
    _expectString(map, 'status', token.status.wireName);
    _expectString(map, 'input_hash', token.inputHash);
    _expectString(map, 'full_analysis_hash', token.fullAnalysisHash);
    _expectNullableString(
      map,
      'redacted_preview_hash',
      token.redactedPreviewHash,
    );
    _expectString(map, 'actor_scope_hash', token.actorScopeHash);
    _expectBool(map, 'freshness_required', token.freshnessRequired);
    _expectBool(
      map,
      'requires_reanalysis_before_execute',
      token.requiresReanalysisBeforeExecute,
    );
    _expectBool(map, 'one_time_use', token.oneTimeUse);

    return OperationTokenRecord(
      token: token,
      consumedAt: _optionalDateTime(map, 'consumed_at'),
      cancelledAt: _optionalDateTime(map, 'cancelled_at'),
      lastError: _optionalString(map, 'last_error'),
      metadataJson: _optionalString(map, 'metadata_json'),
    );
  }
}

// ───────────────────────── 内部 helper ─────────────────────────

void _expectString(Map<String, Object?> map, String key, String expected) {
  final value = map[key];
  if (value != expected) {
    throw ArgumentError.value(
      value,
      key,
      'column disagrees with token_json (expected "$expected")',
    );
  }
}

void _expectNullableString(
  Map<String, Object?> map,
  String key,
  String? expected,
) {
  final raw = map[key];
  final value = (raw is String && raw.isEmpty) ? null : raw;
  if (value != expected) {
    throw ArgumentError.value(
      raw,
      key,
      'column disagrees with token_json (expected ${expected ?? 'null'})',
    );
  }
}

void _expectBool(Map<String, Object?> map, String key, bool expected) {
  final value = map[key];
  if (value is! int || (value != 0 && value != 1)) {
    throw ArgumentError.value(value, key, 'Expected 0 or 1');
  }
  if ((value == 1) != expected) {
    throw ArgumentError.value(
      value,
      key,
      'column disagrees with token_json (expected $expected)',
    );
  }
}

DateTime? _optionalDateTime(Map<String, Object?> map, String key) {
  final raw = map[key];
  if (raw == null) return null;
  if (raw is! String || raw.isEmpty) {
    throw ArgumentError.value(raw, key, 'Expected ISO-8601 string or null');
  }
  return DateTime.parse(raw);
}

String? _optionalString(Map<String, Object?> map, String key) {
  final raw = map[key];
  if (raw == null) return null;
  if (raw is! String) {
    throw ArgumentError.value(raw, key, 'Expected string or null');
  }
  return raw.isEmpty ? null : raw;
}
