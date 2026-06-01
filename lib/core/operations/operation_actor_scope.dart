/// 阶段 D Step 29：actor resource scope / visibility scope 纯模型地基。
///
/// 本文件只表达“某 actor 可访问哪些具体资源范围”，不判断字段类别可见性。
/// 字段类别仍由 D23 的 OperationVisibilityPolicy 负责。
///
/// 约束：
/// - 不 import Flutter / DB / repository / use case / feature / provider。
/// - 不做 IO。
/// - 不接生产路径 / MCP / UI / outbox。
library;

import 'operation_access_control.dart';
import 'operation_actor_type.dart';

/// 可被 scope 约束的资源类型。
enum OperationResourceType {
  device,
  project,
  timingRecord,
  externalPackage,
  auditLog,
  report;

  String get wireName {
    switch (this) {
      case OperationResourceType.device:
        return 'device';
      case OperationResourceType.project:
        return 'project';
      case OperationResourceType.timingRecord:
        return 'timing_record';
      case OperationResourceType.externalPackage:
        return 'external_package';
      case OperationResourceType.auditLog:
        return 'audit_log';
      case OperationResourceType.report:
        return 'report';
    }
  }

  static OperationResourceType fromWireName(String wireName) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(
        wireName,
        'wireName',
        'Unknown OperationResourceType',
      );
    }
    return parsed;
  }

  static OperationResourceType? tryParse(String? wireName) {
    for (final value in OperationResourceType.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }
}

/// 统一表达 scope 中的一条具体资源引用。
class OperationResourceRef {
  OperationResourceRef({required this.type, required String id})
    : id = _requiredId(id, 'id');

  final OperationResourceType type;
  final String id;

  Map<String, Object?> toMap() {
    return {'type': type.wireName, 'id': id};
  }

  factory OperationResourceRef.fromMap(Map<String, Object?> map) {
    final rawType = map['type'];
    if (rawType is! String || rawType.isEmpty) {
      throw ArgumentError.value(rawType, 'type', 'Missing required field');
    }
    final rawId = map['id'];
    if (rawId is! String) {
      throw ArgumentError.value(rawId, 'id', 'Missing required field');
    }
    return OperationResourceRef(
      type: OperationResourceType.fromWireName(rawType),
      id: rawId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OperationResourceRef &&
        other.type == type &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}

/// 某 actor 当前会话被授予的具体资源范围。
///
/// 注意：
/// - [isFullOwner] 只应给 owner / agent-as-owner 使用。
/// - driver / partner / agent-as-driver / agent-as-partner 没有 scope 时默认 deny。
/// - 本模型不表达“字段类别可见性”，例如财务 / 利润仍由
///   OperationVisibilityPolicy 判断。
class ActorScope {
  ActorScope._({
    required bool fullOwner,
    this.ownerId,
    this.actorId,
    Iterable<String> allowedDeviceIds = const [],
    Iterable<String> allowedProjectIds = const [],
    Iterable<String> allowedTimingRecordIds = const [],
    Iterable<String> allowedExternalPackageIds = const [],
    this.scopeSource,
    this.grantId,
    this.expiresAt,
  }) : _fullOwner = fullOwner,
       allowedDeviceIds = _normalizeIds(allowedDeviceIds, 'allowedDeviceIds'),
       allowedProjectIds = _normalizeIds(
         allowedProjectIds,
         'allowedProjectIds',
       ),
       allowedTimingRecordIds = _normalizeIds(
         allowedTimingRecordIds,
         'allowedTimingRecordIds',
       ),
       allowedExternalPackageIds = _normalizeIds(
         allowedExternalPackageIds,
         'allowedExternalPackageIds',
       );

  factory ActorScope.fullOwner({
    String? ownerId,
    String? actorId,
    String? scopeSource,
    String? grantId,
    DateTime? expiresAt,
  }) {
    return ActorScope._(
      fullOwner: true,
      ownerId: ownerId,
      actorId: actorId,
      scopeSource: scopeSource,
      grantId: grantId,
      expiresAt: expiresAt,
    );
  }

  factory ActorScope.devices({
    required Iterable<String> deviceIds,
    String? ownerId,
    String? actorId,
    String? scopeSource,
    String? grantId,
    DateTime? expiresAt,
  }) {
    return ActorScope._(
      fullOwner: false,
      ownerId: ownerId,
      actorId: actorId,
      allowedDeviceIds: deviceIds,
      scopeSource: scopeSource,
      grantId: grantId,
      expiresAt: expiresAt,
    );
  }

  factory ActorScope.projects({
    required Iterable<String> projectIds,
    String? ownerId,
    String? actorId,
    String? scopeSource,
    String? grantId,
    DateTime? expiresAt,
  }) {
    return ActorScope._(
      fullOwner: false,
      ownerId: ownerId,
      actorId: actorId,
      allowedProjectIds: projectIds,
      scopeSource: scopeSource,
      grantId: grantId,
      expiresAt: expiresAt,
    );
  }

  factory ActorScope.timingRecords({
    required Iterable<String> timingRecordIds,
    String? ownerId,
    String? actorId,
    String? scopeSource,
    String? grantId,
    DateTime? expiresAt,
  }) {
    return ActorScope._(
      fullOwner: false,
      ownerId: ownerId,
      actorId: actorId,
      allowedTimingRecordIds: timingRecordIds,
      scopeSource: scopeSource,
      grantId: grantId,
      expiresAt: expiresAt,
    );
  }

  factory ActorScope.externalPackages({
    required Iterable<String> externalPackageIds,
    String? ownerId,
    String? actorId,
    String? scopeSource,
    String? grantId,
    DateTime? expiresAt,
  }) {
    return ActorScope._(
      fullOwner: false,
      ownerId: ownerId,
      actorId: actorId,
      allowedExternalPackageIds: externalPackageIds,
      scopeSource: scopeSource,
      grantId: grantId,
      expiresAt: expiresAt,
    );
  }

  factory ActorScope.empty({
    String? ownerId,
    String? actorId,
    String? scopeSource,
    String? grantId,
    DateTime? expiresAt,
  }) {
    return ActorScope._(
      fullOwner: false,
      ownerId: ownerId,
      actorId: actorId,
      scopeSource: scopeSource,
      grantId: grantId,
      expiresAt: expiresAt,
    );
  }

  final bool _fullOwner;
  final String? ownerId;
  final String? actorId;
  final Set<String> allowedDeviceIds;
  final Set<String> allowedProjectIds;
  final Set<String> allowedTimingRecordIds;
  final Set<String> allowedExternalPackageIds;
  final String? scopeSource;
  final String? grantId;
  final DateTime? expiresAt;

  bool get isFullOwner => _fullOwner;

  bool get isEmpty =>
      !isFullOwner &&
      allowedDeviceIds.isEmpty &&
      allowedProjectIds.isEmpty &&
      allowedTimingRecordIds.isEmpty &&
      allowedExternalPackageIds.isEmpty;

  bool get hasDeviceScope => allowedDeviceIds.isNotEmpty;
  bool get hasProjectScope => allowedProjectIds.isNotEmpty;
  bool get hasTimingRecordScope => allowedTimingRecordIds.isNotEmpty;
  bool get hasExternalPackageScope => allowedExternalPackageIds.isNotEmpty;

  bool isExpired(DateTime now) {
    final end = expiresAt;
    if (end == null) return false;
    return !end.isAfter(now);
  }

  Map<String, Object?> toMap() {
    return {
      'full_owner': isFullOwner,
      'owner_id': ownerId,
      'actor_id': actorId,
      'allowed_device_ids': _sorted(allowedDeviceIds),
      'allowed_project_ids': _sorted(allowedProjectIds),
      'allowed_timing_record_ids': _sorted(allowedTimingRecordIds),
      'allowed_external_package_ids': _sorted(allowedExternalPackageIds),
      'scope_source': scopeSource,
      'grant_id': grantId,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  factory ActorScope.fromMap(Map<String, Object?> map) {
    final rawFullOwner = map['full_owner'];
    if (rawFullOwner is! bool) {
      throw ArgumentError.value(
        rawFullOwner,
        'full_owner',
        'Missing required field',
      );
    }
    return ActorScope._(
      fullOwner: rawFullOwner,
      ownerId: _optionalString(map, 'owner_id'),
      actorId: _optionalString(map, 'actor_id'),
      allowedDeviceIds: _requiredStringList(map, 'allowed_device_ids'),
      allowedProjectIds: _requiredStringList(map, 'allowed_project_ids'),
      allowedTimingRecordIds: _requiredStringList(
        map,
        'allowed_timing_record_ids',
      ),
      allowedExternalPackageIds: _requiredStringList(
        map,
        'allowed_external_package_ids',
      ),
      scopeSource: _optionalString(map, 'scope_source'),
      grantId: _optionalString(map, 'grant_id'),
      expiresAt: _optionalDateTime(map, 'expires_at'),
    );
  }
}

/// 语义别名：用于后续 preview redaction / MCP preview-only / driver-partner
/// 可见性过滤接入时表达“具体资源可见范围”。
typedef OperationVisibilityScope = ActorScope;

/// 单次资源范围判断结果。
class OperationScopeDecision {
  const OperationScopeDecision._({
    required this.allowed,
    required this.reason,
    required this.resourceType,
    required this.resourceId,
  });

  final bool allowed;
  final String reason;
  final OperationResourceType resourceType;
  final String resourceId;

  factory OperationScopeDecision.allow({
    required OperationResourceType resourceType,
    required String resourceId,
    String reason = '',
  }) {
    return OperationScopeDecision._(
      allowed: true,
      reason: reason,
      resourceType: resourceType,
      resourceId: _requiredId(resourceId, 'resourceId'),
    );
  }

  factory OperationScopeDecision.deny({
    required OperationResourceType resourceType,
    required String resourceId,
    required String reason,
  }) {
    if (reason.isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'deny reason must not be empty',
      );
    }
    return OperationScopeDecision._(
      allowed: false,
      reason: reason,
      resourceType: resourceType,
      resourceId: _requiredId(resourceId, 'resourceId'),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'allowed': allowed,
      'reason': reason,
      'resource_type': resourceType.wireName,
      'resource_id': resourceId,
    };
  }
}

/// ActorContext + ActorScope 的纯函数范围策略。
class OperationScopePolicy {
  const OperationScopePolicy();

  OperationScopeDecision canAccessResource({
    required ActorContext actor,
    required ActorScope scope,
    required OperationResourceType resourceType,
    required String resourceId,
    required DateTime now,
  }) {
    final id = _requiredId(resourceId, 'resourceId');

    if (scope.isExpired(now)) {
      return OperationScopeDecision.deny(
        resourceType: resourceType,
        resourceId: id,
        reason: 'actor scope has expired',
      );
    }

    if (actor.isUnknown) {
      return OperationScopeDecision.deny(
        resourceType: resourceType,
        resourceId: id,
        reason: 'unknown actor cannot access scoped resources',
      );
    }

    if (actor.isSystem) {
      return OperationScopeDecision.deny(
        resourceType: resourceType,
        resourceId: id,
        reason: 'system actor has no business resource scope in D29',
      );
    }

    if (actor.isAgent && !actor.hasDelegatedScope) {
      return OperationScopeDecision.deny(
        resourceType: resourceType,
        resourceId: id,
        reason: 'agent without delegated scope cannot access scoped resources',
      );
    }

    if (scope.isEmpty) {
      return OperationScopeDecision.deny(
        resourceType: resourceType,
        resourceId: id,
        reason: 'empty actor scope denies resource access by default',
      );
    }

    switch (actor.effectiveActorType) {
      case OperationActorType.owner:
        return _ownerCanAccess(scope, resourceType, id);
      case OperationActorType.driver:
        return _driverCanAccess(scope, resourceType, id);
      case OperationActorType.partner:
        return _partnerCanAccess(scope, resourceType, id);
      case OperationActorType.agent:
      case OperationActorType.system:
      case OperationActorType.unknown:
        return OperationScopeDecision.deny(
          resourceType: resourceType,
          resourceId: id,
          reason:
              'effective actor type ${actor.effectiveActorType.wireName} '
              'cannot access scoped resources',
        );
    }
  }

  OperationScopeDecision _ownerCanAccess(
    ActorScope scope,
    OperationResourceType type,
    String id,
  ) {
    if (scope.isFullOwner) {
      return OperationScopeDecision.allow(
        resourceType: type,
        resourceId: id,
        reason: 'owner full scope allows resource access',
      );
    }
    return _explicitScopeAccess(
      scope: scope,
      resourceType: type,
      resourceId: id,
      actorLabel: 'owner',
    );
  }

  OperationScopeDecision _driverCanAccess(
    ActorScope scope,
    OperationResourceType type,
    String id,
  ) {
    switch (type) {
      case OperationResourceType.device:
        return _setDecision(
          ids: scope.allowedDeviceIds,
          resourceType: type,
          resourceId: id,
          allowReason: 'driver device scope allows resource access',
          denyReason: 'driver cannot access device outside assigned scope',
        );
      case OperationResourceType.timingRecord:
        return _setDecision(
          ids: scope.allowedTimingRecordIds,
          resourceType: type,
          resourceId: id,
          allowReason: 'driver timing record scope allows resource access',
          denyReason:
              'driver cannot access timing record outside assigned scope',
        );
      case OperationResourceType.project:
      case OperationResourceType.externalPackage:
      case OperationResourceType.auditLog:
      case OperationResourceType.report:
        return OperationScopeDecision.deny(
          resourceType: type,
          resourceId: id,
          reason: 'driver cannot access ${type.wireName} resources in D29',
        );
    }
  }

  OperationScopeDecision _partnerCanAccess(
    ActorScope scope,
    OperationResourceType type,
    String id,
  ) {
    switch (type) {
      case OperationResourceType.device:
        return _setDecision(
          ids: scope.allowedDeviceIds,
          resourceType: type,
          resourceId: id,
          allowReason: 'partner shared device scope allows resource access',
          denyReason: 'partner cannot access device outside shared scope',
        );
      case OperationResourceType.externalPackage:
        return _setDecision(
          ids: scope.allowedExternalPackageIds,
          resourceType: type,
          resourceId: id,
          allowReason: 'partner external package scope allows resource access',
          denyReason:
              'partner cannot access external package outside shared scope',
        );
      case OperationResourceType.project:
      case OperationResourceType.timingRecord:
      case OperationResourceType.auditLog:
      case OperationResourceType.report:
        return OperationScopeDecision.deny(
          resourceType: type,
          resourceId: id,
          reason: 'partner cannot access ${type.wireName} resources in D29',
        );
    }
  }

  OperationScopeDecision _explicitScopeAccess({
    required ActorScope scope,
    required OperationResourceType resourceType,
    required String resourceId,
    required String actorLabel,
  }) {
    switch (resourceType) {
      case OperationResourceType.device:
        return _setDecision(
          ids: scope.allowedDeviceIds,
          resourceType: resourceType,
          resourceId: resourceId,
          allowReason:
              '$actorLabel explicit device scope allows resource access',
          denyReason: '$actorLabel explicit scope does not include device',
        );
      case OperationResourceType.project:
        return _setDecision(
          ids: scope.allowedProjectIds,
          resourceType: resourceType,
          resourceId: resourceId,
          allowReason:
              '$actorLabel explicit project scope allows resource access',
          denyReason: '$actorLabel explicit scope does not include project',
        );
      case OperationResourceType.timingRecord:
        return _setDecision(
          ids: scope.allowedTimingRecordIds,
          resourceType: resourceType,
          resourceId: resourceId,
          allowReason:
              '$actorLabel explicit timing record scope allows resource access',
          denyReason:
              '$actorLabel explicit scope does not include timing record',
        );
      case OperationResourceType.externalPackage:
        return _setDecision(
          ids: scope.allowedExternalPackageIds,
          resourceType: resourceType,
          resourceId: resourceId,
          allowReason:
              '$actorLabel explicit external package scope allows resource access',
          denyReason:
              '$actorLabel explicit scope does not include external package',
        );
      case OperationResourceType.auditLog:
      case OperationResourceType.report:
        return OperationScopeDecision.deny(
          resourceType: resourceType,
          resourceId: resourceId,
          reason:
              '$actorLabel explicit partial scope does not grant '
              '${resourceType.wireName} access',
        );
    }
  }

  OperationScopeDecision _setDecision({
    required Set<String> ids,
    required OperationResourceType resourceType,
    required String resourceId,
    required String allowReason,
    required String denyReason,
  }) {
    if (ids.contains(resourceId)) {
      return OperationScopeDecision.allow(
        resourceType: resourceType,
        resourceId: resourceId,
        reason: allowReason,
      );
    }
    return OperationScopeDecision.deny(
      resourceType: resourceType,
      resourceId: resourceId,
      reason: denyReason,
    );
  }
}

String _requiredId(String value, String fieldName) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, fieldName, 'must not be empty');
  }
  return trimmed;
}

Set<String> _normalizeIds(Iterable<String> values, String fieldName) {
  final result = <String>{};
  for (final value in values) {
    result.add(_requiredId(value, fieldName));
  }
  return Set.unmodifiable(result);
}

List<String> _sorted(Set<String> values) {
  return values.toList()..sort();
}

String? _optionalString(Map<String, Object?> map, String key) {
  final raw = map[key];
  if (raw == null) return null;
  if (raw is! String) {
    throw ArgumentError.value(raw, key, 'Expected string or null');
  }
  return raw.isEmpty ? null : raw;
}

DateTime? _optionalDateTime(Map<String, Object?> map, String key) {
  final raw = map[key];
  if (raw == null) return null;
  if (raw is! String || raw.isEmpty) {
    throw ArgumentError.value(raw, key, 'Expected ISO-8601 string or null');
  }
  return DateTime.parse(raw);
}

List<String> _requiredStringList(Map<String, Object?> map, String key) {
  final raw = map[key];
  if (raw is! List) {
    throw ArgumentError.value(raw, key, 'Missing required string list field');
  }
  return [
    for (final value in raw)
      if (value is String)
        value
      else
        throw ArgumentError.value(value, key, 'Expected string item'),
  ];
}
