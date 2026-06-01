/// 阶段 D Step 44：preview -> confirm -> execute 的确认凭据纯模型地基。
///
/// D43 审计结论：当前「确认凭据」事实上就是完整的 analyze 结果（bearer 对象），
/// 缺少 actor / scope / session 绑定、过期、抗重放、preview↔execute 内容绑定。
/// 本文件提供这层契约的**纯模型 + 无状态校验 + 稳定指纹**，但：
/// - 不落库、不建 operation_tokens 表、不接 repository。
/// - 不接 PreviewService / ConfirmAdapter / Command / MCP / UI / outbox。
/// - 不写 audit、不改 audit schema。
/// - oneTimeUse / consumed 的**真正强制需要后续落库**；本轮只定义契约字段，
///   validator 仅能做无状态判断（status==issued、未过期、各项绑定一致）。
///
/// 约束（保持 core 纯净）：
/// - 不 import Flutter / DB / repository / use case / feature / provider。
/// - 复用 core 既有：[OperationType] / [OperationActorType] / [ActorContext] /
///   [ActorScope]。
/// - 指纹用 sha256(hex)（项目已依赖 `package:crypto`），**绝不**使用
///   `String.hashCode` / `Object.hash` 作持久指纹。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'operation_access_control.dart';
import 'operation_actor_scope.dart';
import 'operation_actor_type.dart';
import 'operation_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Status
// ─────────────────────────────────────────────────────────────────────────────

/// 确认凭据状态。
///
/// D44 只定义字段；真正的 consumed / one-time-use 强制需要后续 operation_tokens
/// 落库。validator 仅按 status 做基础判断：只有 [issued] 可用。
enum OperationConfirmationTokenStatus {
  issued,
  consumed,
  expired,
  cancelled;

  String get wireName {
    switch (this) {
      case OperationConfirmationTokenStatus.issued:
        return 'issued';
      case OperationConfirmationTokenStatus.consumed:
        return 'consumed';
      case OperationConfirmationTokenStatus.expired:
        return 'expired';
      case OperationConfirmationTokenStatus.cancelled:
        return 'cancelled';
    }
  }

  static OperationConfirmationTokenStatus fromWireName(String wireName) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(
        wireName,
        'wireName',
        'Unknown OperationConfirmationTokenStatus',
      );
    }
    return parsed;
  }

  static OperationConfirmationTokenStatus? tryParse(String? wireName) {
    for (final value in OperationConfirmationTokenStatus.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fingerprint helper
// ─────────────────────────────────────────────────────────────────────────────

/// 稳定指纹助手：把 canonical map / list 序列化为确定性 JSON 后取 sha256(hex)。
///
/// 规则：
/// - Map：key 必须是 String，按 key 升序重排（顺序无关）。
/// - List / Iterable：保持原顺序（顺序敏感）。
/// - DateTime：归一化为 UTC ISO8601。
/// - String / num / bool / null：原样。
/// - 其它类型：抛 [ArgumentError]，强制调用方先转成 wireName / 基本类型，
///   避免误把 enum index / hashCode 混进指纹。
///
/// **不使用** `String.hashCode` / `Object.hash`：它们跨进程不稳定，不能做持久指纹。
class OperationConfirmationFingerprint {
  const OperationConfirmationFingerprint._();

  /// 确定性 canonical JSON 字符串。
  static String stableJsonEncode(Object? value) {
    return jsonEncode(_canonicalize(value));
  }

  /// canonical JSON 的 sha256 十六进制摘要。
  static String stableHash(Object? value) {
    return sha256.convert(utf8.encode(stableJsonEncode(value))).toString();
  }

  static Object? _canonicalize(Object? value) {
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Map) {
      final keys = <String>[];
      for (final key in value.keys) {
        if (key is! String) {
          throw ArgumentError.value(
            key,
            'mapKey',
            'stable hash requires String map keys',
          );
        }
        keys.add(key);
      }
      keys.sort();
      final sorted = <String, Object?>{};
      for (final key in keys) {
        sorted[key] = _canonicalize(value[key]);
      }
      return sorted;
    }
    if (value is Iterable) {
      return [for (final element in value) _canonicalize(element)];
    }
    throw ArgumentError.value(
      value,
      'value',
      'unsupported type for stable hash: ${value.runtimeType}',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Token
// ─────────────────────────────────────────────────────────────────────────────

/// preview -> confirm -> execute 的确认凭据。
///
/// 绑定：operation 身份、actor / delegated actor、session、scope 指纹、输入指纹、
/// full analysis 指纹、（可选）redacted preview 指纹、有效期、freshness 要求。
class OperationConfirmationToken {
  OperationConfirmationToken({
    required this.tokenId,
    required this.operationId,
    required this.operationType,
    required this.actorType,
    this.actorId,
    this.delegatedActorType,
    this.delegatedActorId,
    this.sessionId,
    this.source,
    required this.createdAt,
    required this.expiresAt,
    required this.inputHash,
    required this.fullAnalysisHash,
    this.redactedPreviewHash,
    required this.actorScopeHash,
    this.freshnessRequired = true,
    this.requiresReanalysisBeforeExecute = true,
    this.oneTimeUse = true,
    this.status = OperationConfirmationTokenStatus.issued,
  }) {
    if (tokenId.isEmpty) {
      throw ArgumentError.value(tokenId, 'tokenId', 'must not be empty');
    }
    if (operationId.isEmpty) {
      throw ArgumentError.value(operationId, 'operationId', 'must not be empty');
    }
    if (!expiresAt.isAfter(createdAt)) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'must be strictly after createdAt',
      );
    }
    if (inputHash.isEmpty) {
      throw ArgumentError.value(inputHash, 'inputHash', 'must not be empty');
    }
    if (fullAnalysisHash.isEmpty) {
      throw ArgumentError.value(
        fullAnalysisHash,
        'fullAnalysisHash',
        'must not be empty',
      );
    }
    if (redactedPreviewHash != null && redactedPreviewHash!.isEmpty) {
      throw ArgumentError.value(
        redactedPreviewHash,
        'redactedPreviewHash',
        'must be null or non-empty',
      );
    }
    if (actorScopeHash.isEmpty) {
      throw ArgumentError.value(
        actorScopeHash,
        'actorScopeHash',
        'must not be empty',
      );
    }
    if (!freshnessRequired) {
      throw ArgumentError.value(
        freshnessRequired,
        'freshnessRequired',
        'confirmation token must require freshness',
      );
    }
    if (!requiresReanalysisBeforeExecute) {
      throw ArgumentError.value(
        requiresReanalysisBeforeExecute,
        'requiresReanalysisBeforeExecute',
        'confirmation token must require reanalysis before execute',
      );
    }
    _validateActorInvariants(
      actorType: actorType,
      actorId: actorId,
      delegatedActorType: delegatedActorType,
      delegatedActorId: delegatedActorId,
    );
  }

  final String tokenId;
  final String operationId;
  final OperationType operationType;
  final OperationActorType actorType;
  final String? actorId;
  final OperationActorType? delegatedActorType;
  final String? delegatedActorId;
  final String? sessionId;
  final String? source;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String inputHash;
  final String fullAnalysisHash;
  final String? redactedPreviewHash;
  final String actorScopeHash;
  final bool freshnessRequired;
  final bool requiresReanalysisBeforeExecute;
  final bool oneTimeUse;
  final OperationConfirmationTokenStatus status;

  bool get hasDelegatedScope =>
      actorType == OperationActorType.agent &&
      delegatedActorType != null &&
      delegatedActorId != null &&
      delegatedActorId!.isNotEmpty;

  /// 是否已过期（仅看时间；不改 [status]）。
  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  Map<String, Object?> toMap() {
    return {
      'token_id': tokenId,
      'operation_id': operationId,
      'operation_type': operationType.wireName,
      'actor_type': actorType.wireName,
      'actor_id': actorId,
      'delegated_actor_type': delegatedActorType?.wireName,
      'delegated_actor_id': delegatedActorId,
      'session_id': sessionId,
      'source': source,
      'created_at': createdAt.toUtc().toIso8601String(),
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'input_hash': inputHash,
      'full_analysis_hash': fullAnalysisHash,
      'redacted_preview_hash': redactedPreviewHash,
      'actor_scope_hash': actorScopeHash,
      'freshness_required': freshnessRequired,
      'requires_reanalysis_before_execute': requiresReanalysisBeforeExecute,
      'one_time_use': oneTimeUse,
      'status': status.wireName,
    };
  }

  factory OperationConfirmationToken.fromMap(Map<String, Object?> map) {
    final rawDelegatedType = map['delegated_actor_type'];
    return OperationConfirmationToken(
      tokenId: _requiredString(map, 'token_id'),
      operationId: _requiredString(map, 'operation_id'),
      operationType: OperationType.fromWireName(
        _requiredString(map, 'operation_type'),
      ),
      actorType: OperationActorType.fromWireName(
        _requiredString(map, 'actor_type'),
      ),
      actorId: _optionalString(map, 'actor_id'),
      delegatedActorType: rawDelegatedType is String && rawDelegatedType.isNotEmpty
          ? OperationActorType.fromWireName(rawDelegatedType)
          : null,
      delegatedActorId: _optionalString(map, 'delegated_actor_id'),
      sessionId: _optionalString(map, 'session_id'),
      source: _optionalString(map, 'source'),
      createdAt: _requiredDateTime(map, 'created_at'),
      expiresAt: _requiredDateTime(map, 'expires_at'),
      inputHash: _requiredString(map, 'input_hash'),
      fullAnalysisHash: _requiredString(map, 'full_analysis_hash'),
      redactedPreviewHash: _optionalString(map, 'redacted_preview_hash'),
      actorScopeHash: _requiredString(map, 'actor_scope_hash'),
      freshnessRequired: _requiredBool(map, 'freshness_required'),
      requiresReanalysisBeforeExecute: _requiredBool(
        map,
        'requires_reanalysis_before_execute',
      ),
      oneTimeUse: _requiredBool(map, 'one_time_use'),
      status: OperationConfirmationTokenStatus.fromWireName(
        _requiredString(map, 'status'),
      ),
    );
  }
}

/// actor 不变量（token 与 [ActorContext] 保持一致）：
/// - driver / partner / agent 必须有非空 actorId。
/// - agent 必须有 delegatedActorType + 非空 delegatedActorId，且不能委托给
///   agent / unknown。
/// - 非 agent 不得携带 delegated scope。
/// - owner / system / unknown 可省略 actorId。
void _validateActorInvariants({
  required OperationActorType actorType,
  required String? actorId,
  required OperationActorType? delegatedActorType,
  required String? delegatedActorId,
}) {
  final requiresActorId =
      actorType == OperationActorType.driver ||
      actorType == OperationActorType.partner ||
      actorType == OperationActorType.agent;
  if (requiresActorId && (actorId == null || actorId.isEmpty)) {
    throw ArgumentError.value(
      actorId,
      'actorId',
      '${actorType.wireName} token requires non-empty actorId',
    );
  }
  if (actorType == OperationActorType.agent) {
    final hasType = delegatedActorType != null;
    final hasId = delegatedActorId != null && delegatedActorId.isNotEmpty;
    if (hasType != hasId) {
      throw ArgumentError(
        'agent token delegated scope must include both delegatedActorType '
        'and non-empty delegatedActorId, or neither',
      );
    }
    if (!hasType) {
      throw ArgumentError(
        'agent token requires a delegated actor scope',
      );
    }
    if (delegatedActorType == OperationActorType.agent ||
        delegatedActorType == OperationActorType.unknown) {
      throw ArgumentError.value(
        delegatedActorType.wireName,
        'delegatedActorType',
        'agent cannot delegate to agent / unknown',
      );
    }
  } else {
    if (delegatedActorType != null || delegatedActorId != null) {
      throw ArgumentError(
        'delegated actor scope is only valid for agent tokens',
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Validator
// ─────────────────────────────────────────────────────────────────────────────

/// confirm 时校验所需的输入：携带「现场」actor / scope / 指纹 / 当前时间，
/// 与 [token] 比对。inputHash / fullAnalysisHash / redactedPreviewHash 由调用方
/// 用 [OperationConfirmationFingerprint] 预先算好（保持 validator 与 feature 类型解耦）。
class OperationConfirmationTokenValidationInput {
  const OperationConfirmationTokenValidationInput({
    required this.token,
    required this.actor,
    required this.scope,
    required this.operationType,
    required this.operationId,
    required this.inputHash,
    required this.fullAnalysisHash,
    this.redactedPreviewHash,
    required this.now,
    this.sessionId,
  });

  final OperationConfirmationToken token;
  final ActorContext actor;
  final ActorScope scope;
  final OperationType operationType;
  final String operationId;
  final String inputHash;
  final String fullAnalysisHash;
  final String? redactedPreviewHash;
  final DateTime now;
  final String? sessionId;
}

class OperationConfirmationTokenValidationResult {
  OperationConfirmationTokenValidationResult._(this.valid, List<String> errors)
    : errors = List.unmodifiable(errors);

  final bool valid;
  final List<String> errors;

  bool get isValid => valid;

  factory OperationConfirmationTokenValidationResult.valid() {
    return OperationConfirmationTokenValidationResult._(true, const []);
  }

  factory OperationConfirmationTokenValidationResult.invalid(
    List<String> errors,
  ) {
    if (errors.isEmpty) {
      throw ArgumentError.value(
        errors,
        'errors',
        'invalid result must carry at least one error code',
      );
    }
    return OperationConfirmationTokenValidationResult._(false, errors);
  }
}

/// 错误码常量。字符串稳定，便于未来 audit / MCP 机器可读。
abstract final class OperationConfirmationTokenError {
  static const tokenNotIssued = 'token_not_issued';
  static const tokenExpired = 'token_expired';
  static const operationTypeMismatch = 'operation_type_mismatch';
  static const operationIdMismatch = 'operation_id_mismatch';
  static const actorTypeMismatch = 'actor_type_mismatch';
  static const actorIdMismatch = 'actor_id_mismatch';
  static const delegatedActorMismatch = 'delegated_actor_mismatch';
  static const sessionMismatch = 'session_mismatch';
  static const scopeHashMismatch = 'scope_hash_mismatch';
  static const inputHashMismatch = 'input_hash_mismatch';
  static const fullAnalysisHashMismatch = 'full_analysis_hash_mismatch';
  static const redactedPreviewHashMismatch = 'redacted_preview_hash_mismatch';
  static const freshnessNotRequired = 'freshness_not_required';
  static const reanalysisNotRequired = 'reanalysis_not_required';
  static const scopeExpired = 'scope_expired';
  static const actorIdRequired = 'actor_id_required';
  static const delegatedActorRequired = 'delegated_actor_required';
}

/// 无状态确认凭据 validator。
///
/// 只做「凭据与现场是否一致」的判断，不做 IO、不改 token 状态、不强制 one-time-use
/// （后者需落库）。收集**所有**失败原因，便于审计与排错。
class OperationConfirmationTokenValidator {
  const OperationConfirmationTokenValidator();

  OperationConfirmationTokenValidationResult validate(
    OperationConfirmationTokenValidationInput input,
  ) {
    final token = input.token;
    final actor = input.actor;
    final scope = input.scope;
    final errors = <String>[];

    // 1. status 必须 issued。
    if (token.status != OperationConfirmationTokenStatus.issued) {
      errors.add(OperationConfirmationTokenError.tokenNotIssued);
    }

    // 2. 未过期：now < expiresAt。
    if (token.isExpiredAt(input.now)) {
      errors.add(OperationConfirmationTokenError.tokenExpired);
    }

    // 3. freshness 契约。
    if (!token.freshnessRequired) {
      errors.add(OperationConfirmationTokenError.freshnessNotRequired);
    }
    if (!token.requiresReanalysisBeforeExecute) {
      errors.add(OperationConfirmationTokenError.reanalysisNotRequired);
    }

    // 4. operation 身份。
    if (input.operationType != token.operationType) {
      errors.add(OperationConfirmationTokenError.operationTypeMismatch);
    }
    if (input.operationId != token.operationId) {
      errors.add(OperationConfirmationTokenError.operationIdMismatch);
    }

    // 5. actor 身份。
    if (actor.actorType != token.actorType) {
      errors.add(OperationConfirmationTokenError.actorTypeMismatch);
    }
    if (actor.actorId != token.actorId) {
      errors.add(OperationConfirmationTokenError.actorIdMismatch);
    }
    if (actor.delegatedActorType != token.delegatedActorType ||
        actor.delegatedActorId != token.delegatedActorId) {
      errors.add(OperationConfirmationTokenError.delegatedActorMismatch);
    }

    // 6. actorId / delegated 必要性。
    if (actor.requiresActorId &&
        (actor.actorId == null || actor.actorId!.isEmpty)) {
      errors.add(OperationConfirmationTokenError.actorIdRequired);
    }
    if (actor.isAgent && !actor.hasDelegatedScope) {
      errors.add(OperationConfirmationTokenError.delegatedActorRequired);
    }

    // 7. session：token.sessionId 非空 或 agent → 必须与现场 session 一致。
    final sessionMustMatch = token.sessionId != null || actor.isAgent;
    if (sessionMustMatch && input.sessionId != token.sessionId) {
      errors.add(OperationConfirmationTokenError.sessionMismatch);
    }

    // 8. scope：未过期 + scope 指纹一致。
    if (scope.isExpired(input.now)) {
      errors.add(OperationConfirmationTokenError.scopeExpired);
    }
    final scopeHash = OperationConfirmationFingerprint.stableHash(scope.toMap());
    if (scopeHash != token.actorScopeHash) {
      errors.add(OperationConfirmationTokenError.scopeHashMismatch);
    }

    // 9. 内容指纹：input / full analysis / (可选) redacted preview。
    if (input.inputHash != token.inputHash) {
      errors.add(OperationConfirmationTokenError.inputHashMismatch);
    }
    if (input.fullAnalysisHash != token.fullAnalysisHash) {
      errors.add(OperationConfirmationTokenError.fullAnalysisHashMismatch);
    }
    final tokenRedacted = token.redactedPreviewHash;
    if (tokenRedacted != null &&
        input.redactedPreviewHash != tokenRedacted) {
      errors.add(OperationConfirmationTokenError.redactedPreviewHashMismatch);
    }

    if (errors.isEmpty) {
      return OperationConfirmationTokenValidationResult.valid();
    }
    return OperationConfirmationTokenValidationResult.invalid(errors);
  }
}

// ───────────────────────── 内部解析 helper ─────────────────────────

String _requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw ArgumentError.value(
      value,
      key,
      'Missing or empty required string field',
    );
  }
  return value;
}

String? _optionalString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw ArgumentError.value(value, key, 'Expected string or null');
  }
  return value.isEmpty ? null : value;
}

bool _requiredBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! bool) {
    throw ArgumentError.value(value, key, 'Missing required bool field');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw ArgumentError.value(
      value,
      key,
      'Missing required ISO-8601 datetime field',
    );
  }
  return DateTime.parse(value);
}
