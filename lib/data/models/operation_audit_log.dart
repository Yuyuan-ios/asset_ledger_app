import 'dart:convert';

import '../../core/operations/operation_actor_type.dart';
import '../../core/operations/operation_models.dart';

/// 阶段 D Step 3：本地操作审计记录。
///
/// append-only 语义在 repository 层强制（无 update / delete），本模型只表达
/// 数据形态。两份快照字段（preview / before / after）为字符串 JSON，便于
/// 未来 audit 工具 / MCP / diff 报表读取；本轮 before/after 暂未启用。
///
/// 与 [OperationPreview] / [OperationExecutionResult] 的关系：
/// - [operationId] 对应 preview / result 的 operationId；
/// - [operationType] 对应 preview.operationType；
/// - [previewSnapshotJson] 存储 preview.toMap() 的 JSON 形式；
/// - [result] 与 [errorMessage] 对应执行结果的成功 / 失败 / 取消语义。

/// 谁触发了这次操作。
///
/// D25：actor 类型枚举已下沉到 core（[OperationActorType]），以解除 core → data
/// 的非法依赖。这里保留 `OperationAuditActorType` 作为 typedef 别名，确保既有
/// 审计 / repository / 适配层代码与测试零改动；wireName 与 DB 存储格式不变。
typedef OperationAuditActorType = OperationActorType;

/// 操作进入系统的渠道。
enum OperationAuditSource {
  app,
  mcp,
  import,
  restore,
  system,
  test;

  String get wireName {
    switch (this) {
      case OperationAuditSource.app:
        return 'app';
      case OperationAuditSource.mcp:
        return 'mcp';
      case OperationAuditSource.import:
        return 'import';
      case OperationAuditSource.restore:
        return 'restore';
      case OperationAuditSource.system:
        return 'system';
      case OperationAuditSource.test:
        return 'test';
    }
  }

  static OperationAuditSource fromWireName(String wireName) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(
        wireName,
        'wireName',
        'Unknown OperationAuditSource',
      );
    }
    return parsed;
  }

  static OperationAuditSource? tryParse(String? wireName) {
    for (final value in OperationAuditSource.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }
}

/// 执行结局（不是 [OperationExecutionResult] 的克隆——审计还要表达"已取消"）。
enum OperationAuditResult {
  success,
  failure,
  cancelled;

  String get wireName {
    switch (this) {
      case OperationAuditResult.success:
        return 'success';
      case OperationAuditResult.failure:
        return 'failure';
      case OperationAuditResult.cancelled:
        return 'cancelled';
    }
  }

  static OperationAuditResult fromWireName(String wireName) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(
        wireName,
        'wireName',
        'Unknown OperationAuditResult',
      );
    }
    return parsed;
  }

  static OperationAuditResult? tryParse(String? wireName) {
    for (final value in OperationAuditResult.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }
}

class OperationAuditLog {
  const OperationAuditLog({
    required this.id,
    required this.operationId,
    required this.operationType,
    this.actorId,
    required this.actorType,
    required this.source,
    required this.createdAt,
    this.entityRefs = const [],
    this.preview,
    this.beforeSnapshotJson,
    this.afterSnapshotJson,
    required this.confirmed,
    required this.result,
    this.errorMessage,
  })  : assert(id != '', 'id must not be empty'),
        assert(operationId != '', 'operationId must not be empty');

  /// 审计记录自身 id（建议 UUID）。
  final String id;

  /// 对应 [OperationPreview.operationId] / [OperationExecutionResult.operationId]。
  final String operationId;
  final OperationType operationType;

  /// 触发者 id（未来用户 / 设备 / agent）；D3 通常为 null。
  final String? actorId;
  final OperationAuditActorType actorType;
  final OperationAuditSource source;
  final DateTime createdAt;

  /// 受影响实体列表。落库时序列化为 JSON 字符串存入 `entity_refs_json` 列。
  final List<OperationEntityRef> entityRefs;

  /// preview 快照；为 null 时落库 `preview_snapshot_json` 为 NULL。
  final OperationPreview? preview;

  /// before/after 状态快照（D3 暂未启用，留 schema 与字段，可空）。
  final String? beforeSnapshotJson;
  final String? afterSnapshotJson;

  final bool confirmed;
  final OperationAuditResult result;
  final String? errorMessage;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'operation_id': operationId,
      'operation_type': operationType.wireName,
      'actor_id': actorId,
      'actor_type': actorType.wireName,
      'source': source.wireName,
      'created_at': createdAt.toUtc().toIso8601String(),
      'entity_refs_json': jsonEncode(
        entityRefs.map((e) => e.toMap()).toList(),
      ),
      'preview_snapshot_json':
          preview == null ? null : jsonEncode(preview!.toMap()),
      'before_snapshot_json': beforeSnapshotJson,
      'after_snapshot_json': afterSnapshotJson,
      'confirmed': confirmed ? 1 : 0,
      'result': result.wireName,
      'error_message': errorMessage,
    };
  }

  factory OperationAuditLog.fromMap(Map<String, Object?> map) {
    final entityRefsJson = _requiredString(map, 'entity_refs_json');
    final previewJson = map['preview_snapshot_json'] as String?;
    return OperationAuditLog(
      id: _requiredString(map, 'id'),
      operationId: _requiredString(map, 'operation_id'),
      operationType: OperationType.fromWireName(
        _requiredString(map, 'operation_type'),
      ),
      actorId: map['actor_id'] as String?,
      actorType: OperationAuditActorType.fromWireName(
        _requiredString(map, 'actor_type'),
      ),
      source: OperationAuditSource.fromWireName(_requiredString(map, 'source')),
      createdAt: DateTime.parse(_requiredString(map, 'created_at')),
      entityRefs: _decodeEntityRefs(entityRefsJson),
      preview: previewJson == null
          ? null
          : OperationPreview.fromMap(
              Map<String, Object?>.from(jsonDecode(previewJson) as Map),
            ),
      beforeSnapshotJson: map['before_snapshot_json'] as String?,
      afterSnapshotJson: map['after_snapshot_json'] as String?,
      confirmed: _intToBool(map['confirmed'], 'confirmed'),
      result: OperationAuditResult.fromWireName(
        _requiredString(map, 'result'),
      ),
      errorMessage: map['error_message'] as String?,
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

bool _intToBool(Object? raw, String key) {
  if (raw is int) {
    if (raw == 0) return false;
    if (raw == 1) return true;
  }
  throw ArgumentError.value(raw, key, 'Expected 0 or 1');
}

List<OperationEntityRef> _decodeEntityRefs(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) {
    throw ArgumentError.value(
      json,
      'entity_refs_json',
      'Expected JSON array',
    );
  }
  return decoded
      .map((e) => OperationEntityRef.fromMap(Map<String, Object?>.from(e as Map)))
      .toList(growable: false);
}
