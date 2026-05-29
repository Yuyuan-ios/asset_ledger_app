/// 阶段 D Step 1：operation 纯模型地基。
///
/// 这组模型是未来 `parse -> disambiguate -> preview -> confirm -> execute ->
/// audit` 链路与 MCP 工具的统一契约。AI / MCP 将来只能走 preview + confirm +
/// audit，不允许直接改账，因此这里需要一个稳定、可序列化、可被审计快照的纯
/// 模型层。
///
/// 约束（本文件刻意保持纯净）：
/// - 不 import Flutter / DB / repository / use case / feature。
/// - 不做 IO，不依赖 Provider / BuildContext / sqflite。
/// - enum 通过显式 [wireName] 字符串序列化，不依赖 Dart enum index，也不依赖
///   标识符改名。
/// - 模型只“表达”，不替业务做决策（例如不根据 riskLevel 强行改写
///   requiresConfirmation）。
library;

/// 业务操作类型。新增写操作时在此登记，保证 preview / audit / MCP 口径一致。
enum OperationType {
  saveTimingRecord,
  deleteTimingRecord,
  settleProject,
  writeOffProject,
  linkExternalWork,
  unlinkExternalWork,
  importExternalWork,
  restoreBackup,
  generic;

  /// 稳定 wire 码（snake_case），用于序列化 / 审计快照 / MCP，不随 enum 顺序或
  /// 标识符改名而变化。
  String get wireName {
    switch (this) {
      case OperationType.saveTimingRecord:
        return 'save_timing_record';
      case OperationType.deleteTimingRecord:
        return 'delete_timing_record';
      case OperationType.settleProject:
        return 'settle_project';
      case OperationType.writeOffProject:
        return 'write_off_project';
      case OperationType.linkExternalWork:
        return 'link_external_work';
      case OperationType.unlinkExternalWork:
        return 'unlink_external_work';
      case OperationType.importExternalWork:
        return 'import_external_work';
      case OperationType.restoreBackup:
        return 'restore_backup';
      case OperationType.generic:
        return 'generic';
    }
  }

  /// 严格解析：未知 wire 码抛 [ArgumentError]。
  static OperationType fromWireName(String wireName) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(wireName, 'wireName', 'Unknown OperationType');
    }
    return parsed;
  }

  /// 宽松解析：未知 / null 返回 null（调用方决定是否回落到 [generic]）。
  static OperationType? tryParse(String? wireName) {
    for (final value in OperationType.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }
}

/// 操作风险等级。用于 preview / 确认门槛 / 展示标记。
enum OperationRiskLevel {
  low,
  medium,
  high,
  critical;

  String get wireName {
    switch (this) {
      case OperationRiskLevel.low:
        return 'low';
      case OperationRiskLevel.medium:
        return 'medium';
      case OperationRiskLevel.high:
        return 'high';
      case OperationRiskLevel.critical:
        return 'critical';
    }
  }

  /// 显式等级序（不依赖 enum index）：critical > high > medium > low。
  int get rank {
    switch (this) {
      case OperationRiskLevel.low:
        return 0;
      case OperationRiskLevel.medium:
        return 1;
      case OperationRiskLevel.high:
        return 2;
      case OperationRiskLevel.critical:
        return 3;
    }
  }

  /// 当前等级是否不低于 [other]。
  bool isAtLeast(OperationRiskLevel other) => rank >= other.rank;

  static OperationRiskLevel fromWireName(String wireName) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(
        wireName,
        'wireName',
        'Unknown OperationRiskLevel',
      );
    }
    return parsed;
  }

  static OperationRiskLevel? tryParse(String? wireName) {
    for (final value in OperationRiskLevel.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }
}

/// 单条影响项的严重度（用于 preview UI / MCP 输出标记）。
enum OperationImpactSeverity {
  info,
  warning,
  destructive;

  String get wireName {
    switch (this) {
      case OperationImpactSeverity.info:
        return 'info';
      case OperationImpactSeverity.warning:
        return 'warning';
      case OperationImpactSeverity.destructive:
        return 'destructive';
    }
  }

  static OperationImpactSeverity fromWireName(String wireName) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(
        wireName,
        'wireName',
        'Unknown OperationImpactSeverity',
      );
    }
    return parsed;
  }

  static OperationImpactSeverity? tryParse(String? wireName) {
    for (final value in OperationImpactSeverity.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }
}

/// 指向某个业务实体的引用（计时记录 / 项目 / 设备 / 外协包 …）。
///
/// D1 刻意通用：用 [entityType] + [entityId] 表达，不绑定具体 feature。
class OperationEntityRef {
  const OperationEntityRef({
    required this.entityType,
    required this.entityId,
    this.label = '',
    this.projectId,
    this.deviceId,
  }) : assert(entityType != '', 'entityType must not be empty'),
       assert(entityId != '', 'entityId must not be empty');

  final String entityType;
  final String entityId;
  final String label;
  final String? projectId;
  final String? deviceId;

  Map<String, Object?> toMap() {
    return {
      'entity_type': entityType,
      'entity_id': entityId,
      'label': label,
      'project_id': projectId,
      'device_id': deviceId,
    };
  }

  factory OperationEntityRef.fromMap(Map<String, Object?> map) {
    return OperationEntityRef(
      entityType: _requiredString(map, 'entity_type'),
      entityId: _requiredString(map, 'entity_id'),
      label: _optionalString(map, 'label') ?? '',
      projectId: _optionalString(map, 'project_id'),
      deviceId: _optionalString(map, 'device_id'),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OperationEntityRef &&
        other.entityType == entityType &&
        other.entityId == entityId &&
        other.label == label &&
        other.projectId == projectId &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode =>
      Object.hash(entityType, entityId, label, projectId, deviceId);

  @override
  String toString() =>
      'OperationEntityRef($entityType:$entityId, label: $label)';
}

/// 一条影响说明：标题 + 描述 + 严重度 + 受影响实体集合。
class OperationImpactItem {
  const OperationImpactItem({
    required this.title,
    this.description = '',
    this.severity = OperationImpactSeverity.info,
    this.affectedEntities = const [],
    this.code,
  });

  final String title;
  final String description;
  final OperationImpactSeverity severity;
  final List<OperationEntityRef> affectedEntities;
  final String? code;

  bool get isDestructive => severity == OperationImpactSeverity.destructive;

  Map<String, Object?> toMap() {
    return {
      'title': title,
      'description': description,
      'severity': severity.wireName,
      'affected_entities': affectedEntities.map((e) => e.toMap()).toList(),
      'code': code,
    };
  }

  factory OperationImpactItem.fromMap(Map<String, Object?> map) {
    return OperationImpactItem(
      title: _requiredString(map, 'title'),
      description: _optionalString(map, 'description') ?? '',
      // 未知 severity 宽松回落到 info（不崩溃）。
      severity:
          OperationImpactSeverity.tryParse(map['severity'] as String?) ??
          OperationImpactSeverity.info,
      affectedEntities: _entityRefListFromMap(map['affected_entities']),
      code: _optionalString(map, 'code'),
    );
  }
}

/// 一次操作的预览：标题 / 摘要 / 警告 / 受影响实体 / 影响项 / 风险等级 /
/// 是否需要确认。是 confirm 步骤与 audit preview 快照的载体。
class OperationPreview {
  const OperationPreview({
    required this.operationId,
    required this.operationType,
    this.title = '',
    this.summary = '',
    this.warnings = const [],
    this.affectedEntities = const [],
    this.impactItems = const [],
    this.requiresConfirmation = false,
    this.riskLevel = OperationRiskLevel.low,
  });

  final String operationId;
  final OperationType operationType;
  final String title;
  final String summary;
  final List<String> warnings;
  final List<OperationEntityRef> affectedEntities;
  final List<OperationImpactItem> impactItems;

  /// 由调用方（业务侧）决定，模型不自动改写。
  final bool requiresConfirmation;
  final OperationRiskLevel riskLevel;

  bool get hasWarnings => warnings.isNotEmpty;

  bool get hasDestructiveImpact => impactItems.any((item) => item.isDestructive);

  /// 顾问性判断：风险达到 high 及以上时“建议”确认。仅表达，不等于
  /// [requiresConfirmation]，也不替业务做决策。
  bool get suggestsConfirmation =>
      riskLevel.isAtLeast(OperationRiskLevel.high);

  Map<String, Object?> toMap() {
    return {
      'operation_id': operationId,
      'operation_type': operationType.wireName,
      'title': title,
      'summary': summary,
      'warnings': List<String>.from(warnings),
      'affected_entities': affectedEntities.map((e) => e.toMap()).toList(),
      'impact_items': impactItems.map((e) => e.toMap()).toList(),
      'requires_confirmation': requiresConfirmation,
      'risk_level': riskLevel.wireName,
    };
  }

  factory OperationPreview.fromMap(Map<String, Object?> map) {
    final rawType = map['operation_type'];
    if (rawType == null) {
      throw ArgumentError.value(
        null,
        'operation_type',
        'Missing required field',
      );
    }
    return OperationPreview(
      operationId: _requiredString(map, 'operation_id'),
      // 未知 operation_type 宽松回落到 generic（不崩溃）；缺失才报错。
      operationType:
          OperationType.tryParse(rawType as String?) ?? OperationType.generic,
      title: _optionalString(map, 'title') ?? '',
      summary: _optionalString(map, 'summary') ?? '',
      warnings: _stringListFromMap(map['warnings']),
      affectedEntities: _entityRefListFromMap(map['affected_entities']),
      impactItems: _impactItemListFromMap(map['impact_items']),
      requiresConfirmation: (map['requires_confirmation'] as bool?) ?? false,
      riskLevel:
          OperationRiskLevel.tryParse(map['risk_level'] as String?) ??
          OperationRiskLevel.low,
    );
  }
}

/// 一次操作执行后的结果。成功 / 失败语义由工厂保证：
/// - [OperationExecutionResult.success]：error 必为 null。
/// - [OperationExecutionResult.failure]：error 必非空。
class OperationExecutionResult {
  const OperationExecutionResult._({
    required this.success,
    required this.operationId,
    required this.operationType,
    required this.affectedEntities,
    required this.userMessage,
    required this.auditId,
    required this.error,
  });

  final bool success;
  final String operationId;
  final OperationType? operationType;
  final List<OperationEntityRef> affectedEntities;
  final String userMessage;

  /// 审计条目 id。D1 未接 audit，故通常为 null。
  final String? auditId;

  /// 失败原因；成功时为 null。
  final String? error;

  factory OperationExecutionResult.success({
    required String operationId,
    OperationType? operationType,
    List<OperationEntityRef> affectedEntities = const [],
    String userMessage = '',
    String? auditId,
  }) {
    return OperationExecutionResult._(
      success: true,
      operationId: operationId,
      operationType: operationType,
      affectedEntities: affectedEntities,
      userMessage: userMessage,
      auditId: auditId,
      error: null,
    );
  }

  factory OperationExecutionResult.failure({
    required String operationId,
    required String error,
    OperationType? operationType,
    List<OperationEntityRef> affectedEntities = const [],
    String userMessage = '',
    String? auditId,
  }) {
    if (error.isEmpty) {
      throw ArgumentError.value(error, 'error', 'failure error must not be empty');
    }
    return OperationExecutionResult._(
      success: false,
      operationId: operationId,
      operationType: operationType,
      affectedEntities: affectedEntities,
      userMessage: userMessage,
      auditId: auditId,
      error: error,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'success': success,
      'operation_id': operationId,
      'operation_type': operationType?.wireName,
      'affected_entities': affectedEntities.map((e) => e.toMap()).toList(),
      'user_message': userMessage,
      'audit_id': auditId,
      'error': error,
    };
  }

  factory OperationExecutionResult.fromMap(Map<String, Object?> map) {
    final success = map['success'];
    if (success is! bool) {
      throw ArgumentError.value(success, 'success', 'Missing required bool field');
    }
    final operationId = _requiredString(map, 'operation_id');
    final operationType = OperationType.tryParse(
      map['operation_type'] as String?,
    );
    final affectedEntities = _entityRefListFromMap(map['affected_entities']);
    final userMessage = _optionalString(map, 'user_message') ?? '';
    final auditId = _optionalString(map, 'audit_id');
    final error = _optionalString(map, 'error');

    if (success) {
      return OperationExecutionResult.success(
        operationId: operationId,
        operationType: operationType,
        affectedEntities: affectedEntities,
        userMessage: userMessage,
        auditId: auditId,
      );
    }
    if (error == null || error.isEmpty) {
      throw ArgumentError.value(
        error,
        'error',
        'failure result must carry a non-empty error',
      );
    }
    return OperationExecutionResult.failure(
      operationId: operationId,
      error: error,
      operationType: operationType,
      affectedEntities: affectedEntities,
      userMessage: userMessage,
      auditId: auditId,
    );
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
  return value is String ? value : null;
}

List<String> _stringListFromMap(Object? raw) {
  if (raw == null) return const [];
  return (raw as List).map((e) => e as String).toList(growable: false);
}

List<OperationEntityRef> _entityRefListFromMap(Object? raw) {
  if (raw == null) return const [];
  return (raw as List)
      .map((e) => OperationEntityRef.fromMap(Map<String, Object?>.from(e as Map)))
      .toList(growable: false);
}

List<OperationImpactItem> _impactItemListFromMap(Object? raw) {
  if (raw == null) return const [];
  return (raw as List)
      .map((e) => OperationImpactItem.fromMap(Map<String, Object?>.from(e as Map)))
      .toList(growable: false);
}
