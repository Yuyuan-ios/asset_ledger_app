/// 阶段 D Step 23：actor / permission / visibility 纯模型地基。
///
/// 为未来 MCP / Agent / 驾驶员 / 合伙人 / 老板端的权限与可见性提供统一的
/// 纯模型契约，但**本轮不接业务路径、不接 DB、不接 UI、不接 MCP**。
///
/// 约束（本文件刻意保持纯净）：
/// - 不 import Flutter / DB / repository / use case / feature / provider。
/// - 不做 IO。
/// - enum 通过显式 [wireName] 字符串序列化，不依赖 Dart enum index，也不依赖
///   标识符改名。
/// - 模型只“表达”规则与决定，不去落库或拦截真实写路径。
/// - agent 默认不是超级用户：必须显式被委托（delegatedActorType + actorId）
///   才能拿到对应 actor 的低风险权限；execute 类写操作 D23 阶段一律 deny。
/// - owner / driver / partner / agent / system / unknown 复用既有
///   [OperationAuditActorType]，避免再发明一套 actor 枚举。
library;

import '../../data/models/operation_audit_log.dart' show OperationAuditActorType;

// ─────────────────────────────────────────────────────────────────────────────
// ActorContext
// ─────────────────────────────────────────────────────────────────────────────

/// 描述“谁在发起这次操作”的上下文。
///
/// 复用 [OperationAuditActorType] 作为 actor 类型枚举。
///
/// 业务规则（D23 第一版）：
/// - owner 本地手动操作可允许 [actorId] 为空（本机就是 owner）。
/// - driver / partner / agent 原则上必须携带 [actorId]，否则视为非法 actor。
/// - agent 必须绑定 delegated actor scope（[delegatedActorType] +
///   [delegatedActorId]），否则不视为有效的代理身份。
/// - system 可 [actorId] 为空（迁移 / 后台任务）。
/// - unknown 仅用于 legacy 兼容，不应作为新写操作的 actor。
/// - import 不应作为 actor，import 是 [source]（参见
///   [OperationAuditSource]，本模型不直接耦合）。
class ActorContext {
  ActorContext({
    required this.actorType,
    this.actorId,
    this.delegatedActorType,
    this.delegatedActorId,
    this.sessionId,
    this.source,
  }) {
    if (requiresActorId && (actorId == null || actorId!.isEmpty)) {
      throw ArgumentError.value(
        actorId,
        'actorId',
        '${actorType.wireName} actor requires non-empty actorId',
      );
    }
    if (actorType == OperationAuditActorType.agent) {
      // agent 的 delegated scope 必须成对出现：要么都给，要么都不给。
      final hasType = delegatedActorType != null;
      final hasId = delegatedActorId != null && delegatedActorId!.isNotEmpty;
      if (hasType != hasId) {
        throw ArgumentError(
          'agent delegated actor scope must include both '
          'delegatedActorType and non-empty delegatedActorId, or neither',
        );
      }
      if (delegatedActorType == OperationAuditActorType.agent) {
        throw ArgumentError.value(
          delegatedActorType!.wireName,
          'delegatedActorType',
          'agent cannot delegate to another agent',
        );
      }
      if (delegatedActorType == OperationAuditActorType.unknown) {
        throw ArgumentError.value(
          delegatedActorType!.wireName,
          'delegatedActorType',
          'agent cannot delegate to unknown actor',
        );
      }
    } else {
      if (delegatedActorType != null || delegatedActorId != null) {
        throw ArgumentError(
          'delegated actor scope is only valid for agent actors',
        );
      }
    }
  }

  final OperationAuditActorType actorType;
  final String? actorId;

  /// 仅 agent 使用：被委托代表的真实 actor 类型（owner / driver / partner /
  /// system）。
  final OperationAuditActorType? delegatedActorType;

  /// 仅 agent 使用：被委托代表的真实 actor id。
  final String? delegatedActorId;

  /// 当前会话标识（MCP session / app session 等）；D23 暂不强约束。
  final String? sessionId;

  /// 来源备注（例如 `mcp`, `app`, `import`），与
  /// [OperationAuditSource] 同语义但本模型不强耦合。
  final String? source;

  bool get isOwner => actorType == OperationAuditActorType.owner;
  bool get isDriver => actorType == OperationAuditActorType.driver;
  bool get isPartner => actorType == OperationAuditActorType.partner;
  bool get isAgent => actorType == OperationAuditActorType.agent;
  bool get isSystem => actorType == OperationAuditActorType.system;
  bool get isUnknown => actorType == OperationAuditActorType.unknown;

  /// driver / partner / agent 必须携带 [actorId]；owner / system / unknown
  /// 可不携带。
  bool get requiresActorId {
    switch (actorType) {
      case OperationAuditActorType.driver:
      case OperationAuditActorType.partner:
      case OperationAuditActorType.agent:
        return true;
      case OperationAuditActorType.owner:
      case OperationAuditActorType.system:
      case OperationAuditActorType.unknown:
        return false;
    }
  }

  /// agent 是否已经被显式委托给某个真实 actor scope。
  bool get hasDelegatedScope =>
      isAgent &&
      delegatedActorType != null &&
      delegatedActorId != null &&
      delegatedActorId!.isNotEmpty;

  /// 用于鉴权 / 可见性判断的“有效 actor 类型”：
  /// agent 带 delegated scope 时返回 delegated 类型，否则返回原始 [actorType]。
  OperationAuditActorType get effectiveActorType {
    if (isAgent && hasDelegatedScope) {
      return delegatedActorType!;
    }
    return actorType;
  }

  Map<String, Object?> toMap() {
    return {
      'actor_type': actorType.wireName,
      'actor_id': actorId,
      'delegated_actor_type': delegatedActorType?.wireName,
      'delegated_actor_id': delegatedActorId,
      'session_id': sessionId,
      'source': source,
    };
  }

  factory ActorContext.fromMap(Map<String, Object?> map) {
    final rawType = map['actor_type'];
    if (rawType is! String || rawType.isEmpty) {
      throw ArgumentError.value(rawType, 'actor_type', 'Missing required field');
    }
    final actorType = OperationAuditActorType.fromWireName(rawType);
    final rawDelegatedType = map['delegated_actor_type'];
    final delegatedActorType = rawDelegatedType is String && rawDelegatedType.isNotEmpty
        ? OperationAuditActorType.fromWireName(rawDelegatedType)
        : null;
    return ActorContext(
      actorType: actorType,
      actorId: _optionalString(map, 'actor_id'),
      delegatedActorType: delegatedActorType,
      delegatedActorId: _optionalString(map, 'delegated_actor_id'),
      sessionId: _optionalString(map, 'session_id'),
      source: _optionalString(map, 'source'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permission
// ─────────────────────────────────────────────────────────────────────────────

/// 操作动作枚举。区分只读 / preview / 写 / 高风险写。
enum OperationPermissionAction {
  // 只读
  readDevice,
  readTimingRecord,
  readProject,
  readExternalWork,
  readAudit,

  // preview / export
  previewSaveTimingRecord,
  exportDeviceWorkHours,

  // 写
  executeSaveTimingRecord,
  deleteTimingRecord,
  settleProject,
  writeOffProject,
  linkExternalWork,
  importExternalWork,
  restoreBackup;

  String get wireName {
    switch (this) {
      case OperationPermissionAction.readDevice:
        return 'read_device';
      case OperationPermissionAction.readTimingRecord:
        return 'read_timing_record';
      case OperationPermissionAction.readProject:
        return 'read_project';
      case OperationPermissionAction.readExternalWork:
        return 'read_external_work';
      case OperationPermissionAction.readAudit:
        return 'read_audit';
      case OperationPermissionAction.previewSaveTimingRecord:
        return 'preview_save_timing_record';
      case OperationPermissionAction.exportDeviceWorkHours:
        return 'export_device_work_hours';
      case OperationPermissionAction.executeSaveTimingRecord:
        return 'execute_save_timing_record';
      case OperationPermissionAction.deleteTimingRecord:
        return 'delete_timing_record';
      case OperationPermissionAction.settleProject:
        return 'settle_project';
      case OperationPermissionAction.writeOffProject:
        return 'write_off_project';
      case OperationPermissionAction.linkExternalWork:
        return 'link_external_work';
      case OperationPermissionAction.importExternalWork:
        return 'import_external_work';
      case OperationPermissionAction.restoreBackup:
        return 'restore_backup';
    }
  }

  static OperationPermissionAction fromWireName(String wireName) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(
        wireName,
        'wireName',
        'Unknown OperationPermissionAction',
      );
    }
    return parsed;
  }

  static OperationPermissionAction? tryParse(String? wireName) {
    for (final value in OperationPermissionAction.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }

  bool get isReadOnly {
    switch (this) {
      case OperationPermissionAction.readDevice:
      case OperationPermissionAction.readTimingRecord:
      case OperationPermissionAction.readProject:
      case OperationPermissionAction.readExternalWork:
      case OperationPermissionAction.readAudit:
        return true;
      case OperationPermissionAction.previewSaveTimingRecord:
      case OperationPermissionAction.exportDeviceWorkHours:
      case OperationPermissionAction.executeSaveTimingRecord:
      case OperationPermissionAction.deleteTimingRecord:
      case OperationPermissionAction.settleProject:
      case OperationPermissionAction.writeOffProject:
      case OperationPermissionAction.linkExternalWork:
      case OperationPermissionAction.importExternalWork:
      case OperationPermissionAction.restoreBackup:
        return false;
    }
  }

  bool get isPreview => this == OperationPermissionAction.previewSaveTimingRecord;

  bool get isWrite {
    switch (this) {
      case OperationPermissionAction.executeSaveTimingRecord:
      case OperationPermissionAction.deleteTimingRecord:
      case OperationPermissionAction.settleProject:
      case OperationPermissionAction.writeOffProject:
      case OperationPermissionAction.linkExternalWork:
      case OperationPermissionAction.importExternalWork:
      case OperationPermissionAction.restoreBackup:
        return true;
      case OperationPermissionAction.readDevice:
      case OperationPermissionAction.readTimingRecord:
      case OperationPermissionAction.readProject:
      case OperationPermissionAction.readExternalWork:
      case OperationPermissionAction.readAudit:
      case OperationPermissionAction.previewSaveTimingRecord:
      case OperationPermissionAction.exportDeviceWorkHours:
        return false;
    }
  }

  bool get isHighRisk {
    switch (this) {
      case OperationPermissionAction.deleteTimingRecord:
      case OperationPermissionAction.settleProject:
      case OperationPermissionAction.writeOffProject:
      case OperationPermissionAction.linkExternalWork:
      case OperationPermissionAction.importExternalWork:
      case OperationPermissionAction.restoreBackup:
        return true;
      case OperationPermissionAction.readDevice:
      case OperationPermissionAction.readTimingRecord:
      case OperationPermissionAction.readProject:
      case OperationPermissionAction.readExternalWork:
      case OperationPermissionAction.readAudit:
      case OperationPermissionAction.previewSaveTimingRecord:
      case OperationPermissionAction.exportDeviceWorkHours:
      case OperationPermissionAction.executeSaveTimingRecord:
        return false;
    }
  }
}

/// 单次权限判断的结果。
///
/// 语义：
/// - [allowed] = false：禁止执行。
/// - [allowed] = true 且 [requiresConfirmation] = false：可以直接执行
///   （此判断与业务路径上的 preview/confirm/audit 链路不冲突，仍由具体
///   command 决定是否走 preview，本模型只表达权限准入）。
/// - [allowed] = true 且 [requiresConfirmation] = true：原则允许，但必须
///   先走 preview + confirm + audit 才可执行。
class OperationPermissionDecision {
  const OperationPermissionDecision._({
    required this.allowed,
    required this.reason,
    required this.action,
    required this.actorType,
    required this.requiresConfirmation,
  });

  final bool allowed;
  final String reason;
  final OperationPermissionAction action;
  final OperationAuditActorType actorType;
  final bool requiresConfirmation;

  factory OperationPermissionDecision.allow({
    required OperationPermissionAction action,
    required OperationAuditActorType actorType,
    bool requiresConfirmation = false,
    String reason = '',
  }) {
    return OperationPermissionDecision._(
      allowed: true,
      reason: reason,
      action: action,
      actorType: actorType,
      requiresConfirmation: requiresConfirmation,
    );
  }

  factory OperationPermissionDecision.deny({
    required OperationPermissionAction action,
    required OperationAuditActorType actorType,
    required String reason,
  }) {
    if (reason.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'deny reason must not be empty');
    }
    return OperationPermissionDecision._(
      allowed: false,
      reason: reason,
      action: action,
      actorType: actorType,
      requiresConfirmation: false,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'allowed': allowed,
      'reason': reason,
      'action': action.wireName,
      'actor_type': actorType.wireName,
      'requires_confirmation': requiresConfirmation,
    };
  }
}

/// 纯函数权限策略（D23 第一版）。
///
/// 不接生产路径：调用方只能拿到“是/否/是否需要确认”，是否真的写入仍由
/// command + audit 链路保证。
class OperationPermissionPolicy {
  const OperationPermissionPolicy();

  OperationPermissionDecision canPerform({
    required ActorContext actor,
    required OperationPermissionAction action,
  }) {
    // unknown：法外身份，全 deny。
    if (actor.isUnknown) {
      return OperationPermissionDecision.deny(
        action: action,
        actorType: actor.actorType,
        reason: 'unknown actor cannot perform any action',
      );
    }

    // agent 没有 delegated scope：全 deny（防止 agent 当超级用户）。
    if (actor.isAgent && !actor.hasDelegatedScope) {
      return OperationPermissionDecision.deny(
        action: action,
        actorType: actor.actorType,
        reason: 'agent without delegated scope cannot perform any action',
      );
    }

    // agent 的 execute / 高风险写：一律 deny（D23 阶段保守）。
    if (actor.isAgent && (action.isWrite)) {
      return OperationPermissionDecision.deny(
        action: action,
        actorType: actor.actorType,
        reason: 'agent cannot directly execute write actions; '
            'use preview + confirm + audit via the real actor',
      );
    }

    // system：第一版除只读 audit 外保守 deny；后续 maintenance 再放开。
    if (actor.isSystem) {
      if (action == OperationPermissionAction.readAudit) {
        return OperationPermissionDecision.allow(
          action: action,
          actorType: actor.actorType,
          reason: 'system may read audit log',
        );
      }
      return OperationPermissionDecision.deny(
        action: action,
        actorType: actor.actorType,
        reason: 'system actor is not allowed to perform business actions in D23',
      );
    }

    // 之后按“有效 actor 类型”判断（agent 已委托则按 delegated actor 算）。
    final effective = actor.effectiveActorType;

    switch (effective) {
      case OperationAuditActorType.owner:
        return _evaluateForOwner(actor, action);
      case OperationAuditActorType.driver:
        return _evaluateForDriver(actor, action);
      case OperationAuditActorType.partner:
        return _evaluateForPartner(actor, action);
      case OperationAuditActorType.agent:
      case OperationAuditActorType.system:
      case OperationAuditActorType.unknown:
        // 不应到达：上方已处理。
        return OperationPermissionDecision.deny(
          action: action,
          actorType: actor.actorType,
          reason: 'effective actor type ${effective.wireName} not allowed',
        );
    }
  }

  OperationPermissionDecision _evaluateForOwner(
    ActorContext actor,
    OperationPermissionAction action,
  ) {
    // owner 是完整权限主体。
    // 但 agent 委托到 owner 时仍不允许 execute 类写操作（已在 caller 拦截）。
    final requiresConfirmation = action.isHighRisk;
    return OperationPermissionDecision.allow(
      action: action,
      actorType: actor.actorType,
      requiresConfirmation: requiresConfirmation,
      reason: requiresConfirmation
          ? 'owner may perform but high-risk requires preview + confirm + audit'
          : 'owner may perform',
    );
  }

  OperationPermissionDecision _evaluateForDriver(
    ActorContext actor,
    OperationPermissionAction action,
  ) {
    switch (action) {
      case OperationPermissionAction.readDevice:
      case OperationPermissionAction.readTimingRecord:
      case OperationPermissionAction.previewSaveTimingRecord:
      case OperationPermissionAction.exportDeviceWorkHours:
        return OperationPermissionDecision.allow(
          action: action,
          actorType: actor.actorType,
          reason: 'driver may read / preview within own scope',
        );
      case OperationPermissionAction.readProject:
      case OperationPermissionAction.readExternalWork:
      case OperationPermissionAction.readAudit:
        return OperationPermissionDecision.deny(
          action: action,
          actorType: actor.actorType,
          reason: 'driver cannot see project / external work / audit details',
        );
      case OperationPermissionAction.executeSaveTimingRecord:
        return OperationPermissionDecision.deny(
          action: action,
          actorType: actor.actorType,
          reason: 'driver submissions go through review workflow, '
              'direct execute is not allowed in D23',
        );
      case OperationPermissionAction.deleteTimingRecord:
      case OperationPermissionAction.settleProject:
      case OperationPermissionAction.writeOffProject:
      case OperationPermissionAction.linkExternalWork:
      case OperationPermissionAction.importExternalWork:
      case OperationPermissionAction.restoreBackup:
        return OperationPermissionDecision.deny(
          action: action,
          actorType: actor.actorType,
          reason: 'driver cannot perform delete / settle / write-off / '
              'external link / import / restore',
        );
    }
  }

  OperationPermissionDecision _evaluateForPartner(
    ActorContext actor,
    OperationPermissionAction action,
  ) {
    switch (action) {
      case OperationPermissionAction.readDevice:
      case OperationPermissionAction.readTimingRecord:
      case OperationPermissionAction.exportDeviceWorkHours:
        return OperationPermissionDecision.allow(
          action: action,
          actorType: actor.actorType,
          reason: 'partner may read / export within shared device scope',
        );
      case OperationPermissionAction.readProject:
      case OperationPermissionAction.readExternalWork:
      case OperationPermissionAction.readAudit:
        return OperationPermissionDecision.deny(
          action: action,
          actorType: actor.actorType,
          reason: 'partner cannot see project / external work / audit details',
        );
      case OperationPermissionAction.previewSaveTimingRecord:
      case OperationPermissionAction.executeSaveTimingRecord:
        return OperationPermissionDecision.deny(
          action: action,
          actorType: actor.actorType,
          reason: 'partner is read-only for timing records',
        );
      case OperationPermissionAction.deleteTimingRecord:
      case OperationPermissionAction.settleProject:
      case OperationPermissionAction.writeOffProject:
      case OperationPermissionAction.linkExternalWork:
      case OperationPermissionAction.importExternalWork:
      case OperationPermissionAction.restoreBackup:
        return OperationPermissionDecision.deny(
          action: action,
          actorType: actor.actorType,
          reason: 'partner cannot perform finance / destructive actions',
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Visibility
// ─────────────────────────────────────────────────────────────────────────────

/// 可见性维度。围绕“某 actor 能不能看到某类信息”而非具体字段。
enum OperationVisibilityCapability {
  deviceName,
  timingBasic,
  projectLabel,
  contactSite,
  financialAmount,
  payment,
  writeOff,
  profit,
  externalWorkSource,
  auditDetail,
  exportDeviceWorkHours;

  String get wireName {
    switch (this) {
      case OperationVisibilityCapability.deviceName:
        return 'device_name';
      case OperationVisibilityCapability.timingBasic:
        return 'timing_basic';
      case OperationVisibilityCapability.projectLabel:
        return 'project_label';
      case OperationVisibilityCapability.contactSite:
        return 'contact_site';
      case OperationVisibilityCapability.financialAmount:
        return 'financial_amount';
      case OperationVisibilityCapability.payment:
        return 'payment';
      case OperationVisibilityCapability.writeOff:
        return 'write_off';
      case OperationVisibilityCapability.profit:
        return 'profit';
      case OperationVisibilityCapability.externalWorkSource:
        return 'external_work_source';
      case OperationVisibilityCapability.auditDetail:
        return 'audit_detail';
      case OperationVisibilityCapability.exportDeviceWorkHours:
        return 'export_device_work_hours';
    }
  }

  static OperationVisibilityCapability fromWireName(String wireName) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(
        wireName,
        'wireName',
        'Unknown OperationVisibilityCapability',
      );
    }
    return parsed;
  }

  static OperationVisibilityCapability? tryParse(String? wireName) {
    for (final value in OperationVisibilityCapability.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }

  bool get isFinancialSensitive {
    switch (this) {
      case OperationVisibilityCapability.financialAmount:
      case OperationVisibilityCapability.payment:
      case OperationVisibilityCapability.writeOff:
      case OperationVisibilityCapability.profit:
        return true;
      case OperationVisibilityCapability.deviceName:
      case OperationVisibilityCapability.timingBasic:
      case OperationVisibilityCapability.projectLabel:
      case OperationVisibilityCapability.contactSite:
      case OperationVisibilityCapability.externalWorkSource:
      case OperationVisibilityCapability.auditDetail:
      case OperationVisibilityCapability.exportDeviceWorkHours:
        return false;
    }
  }

  bool get isProjectSensitive {
    switch (this) {
      case OperationVisibilityCapability.projectLabel:
      case OperationVisibilityCapability.contactSite:
      case OperationVisibilityCapability.externalWorkSource:
        return true;
      case OperationVisibilityCapability.deviceName:
      case OperationVisibilityCapability.timingBasic:
      case OperationVisibilityCapability.financialAmount:
      case OperationVisibilityCapability.payment:
      case OperationVisibilityCapability.writeOff:
      case OperationVisibilityCapability.profit:
      case OperationVisibilityCapability.auditDetail:
      case OperationVisibilityCapability.exportDeviceWorkHours:
        return false;
    }
  }

  bool get isExport => this == OperationVisibilityCapability.exportDeviceWorkHours;
}

class OperationVisibilityDecision {
  const OperationVisibilityDecision._({
    required this.visible,
    required this.reason,
    required this.capability,
    required this.actorType,
  });

  final bool visible;
  final String reason;
  final OperationVisibilityCapability capability;
  final OperationAuditActorType actorType;

  factory OperationVisibilityDecision.visible({
    required OperationVisibilityCapability capability,
    required OperationAuditActorType actorType,
    String reason = '',
  }) {
    return OperationVisibilityDecision._(
      visible: true,
      reason: reason,
      capability: capability,
      actorType: actorType,
    );
  }

  factory OperationVisibilityDecision.hidden({
    required OperationVisibilityCapability capability,
    required OperationAuditActorType actorType,
    required String reason,
  }) {
    if (reason.isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'hidden reason must not be empty',
      );
    }
    return OperationVisibilityDecision._(
      visible: false,
      reason: reason,
      capability: capability,
      actorType: actorType,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'visible': visible,
      'reason': reason,
      'capability': capability.wireName,
      'actor_type': actorType.wireName,
    };
  }
}

/// 纯函数可见性策略（D23 第一版）。
///
/// agent 不因为 [OperationAuditActorType.agent] 本身就拥有任何敏感可见性，
/// 必须显式委托。
class OperationVisibilityPolicy {
  const OperationVisibilityPolicy();

  OperationVisibilityDecision canSee({
    required ActorContext actor,
    required OperationVisibilityCapability capability,
  }) {
    if (actor.isUnknown) {
      return OperationVisibilityDecision.hidden(
        capability: capability,
        actorType: actor.actorType,
        reason: 'unknown actor cannot see any capability',
      );
    }

    if (actor.isAgent && !actor.hasDelegatedScope) {
      return OperationVisibilityDecision.hidden(
        capability: capability,
        actorType: actor.actorType,
        reason: 'agent without delegated scope cannot see any capability',
      );
    }

    if (actor.isSystem) {
      return OperationVisibilityDecision.hidden(
        capability: capability,
        actorType: actor.actorType,
        reason: 'system actor cannot see business data in D23',
      );
    }

    final effective = actor.effectiveActorType;

    switch (effective) {
      case OperationAuditActorType.owner:
        return OperationVisibilityDecision.visible(
          capability: capability,
          actorType: actor.actorType,
          reason: 'owner sees everything',
        );
      case OperationAuditActorType.driver:
        return _evaluateForDriver(actor, capability);
      case OperationAuditActorType.partner:
        return _evaluateForPartner(actor, capability);
      case OperationAuditActorType.agent:
      case OperationAuditActorType.system:
      case OperationAuditActorType.unknown:
        return OperationVisibilityDecision.hidden(
          capability: capability,
          actorType: actor.actorType,
          reason: 'effective actor type ${effective.wireName} cannot see this',
        );
    }
  }

  OperationVisibilityDecision _evaluateForDriver(
    ActorContext actor,
    OperationVisibilityCapability capability,
  ) {
    switch (capability) {
      case OperationVisibilityCapability.deviceName:
      case OperationVisibilityCapability.timingBasic:
      case OperationVisibilityCapability.exportDeviceWorkHours:
        return OperationVisibilityDecision.visible(
          capability: capability,
          actorType: actor.actorType,
          reason: 'driver sees own device + timing basics + work-hour export',
        );
      case OperationVisibilityCapability.projectLabel:
      case OperationVisibilityCapability.contactSite:
        return OperationVisibilityDecision.hidden(
          capability: capability,
          actorType: actor.actorType,
          reason: 'driver does not see project labels or contact sites in D23',
        );
      case OperationVisibilityCapability.financialAmount:
      case OperationVisibilityCapability.payment:
      case OperationVisibilityCapability.writeOff:
      case OperationVisibilityCapability.profit:
        return OperationVisibilityDecision.hidden(
          capability: capability,
          actorType: actor.actorType,
          reason: 'driver cannot see financial / profit information',
        );
      case OperationVisibilityCapability.externalWorkSource:
        return OperationVisibilityDecision.hidden(
          capability: capability,
          actorType: actor.actorType,
          reason: 'driver cannot see external work source / customer info',
        );
      case OperationVisibilityCapability.auditDetail:
        return OperationVisibilityDecision.hidden(
          capability: capability,
          actorType: actor.actorType,
          reason: 'driver cannot see audit details',
        );
    }
  }

  OperationVisibilityDecision _evaluateForPartner(
    ActorContext actor,
    OperationVisibilityCapability capability,
  ) {
    switch (capability) {
      case OperationVisibilityCapability.deviceName:
      case OperationVisibilityCapability.timingBasic:
      case OperationVisibilityCapability.exportDeviceWorkHours:
        return OperationVisibilityDecision.visible(
          capability: capability,
          actorType: actor.actorType,
          reason: 'partner sees shared device + timing basics + work-hour export',
        );
      case OperationVisibilityCapability.projectLabel:
      case OperationVisibilityCapability.contactSite:
        return OperationVisibilityDecision.hidden(
          capability: capability,
          actorType: actor.actorType,
          reason: 'partner does not see project labels or contact sites in D23',
        );
      case OperationVisibilityCapability.financialAmount:
      case OperationVisibilityCapability.payment:
      case OperationVisibilityCapability.writeOff:
      case OperationVisibilityCapability.profit:
        return OperationVisibilityDecision.hidden(
          capability: capability,
          actorType: actor.actorType,
          reason: 'partner cannot see boss-side financial / profit data',
        );
      case OperationVisibilityCapability.externalWorkSource:
        return OperationVisibilityDecision.hidden(
          capability: capability,
          actorType: actor.actorType,
          reason: 'partner cannot see external work source / customer info',
        );
      case OperationVisibilityCapability.auditDetail:
        return OperationVisibilityDecision.hidden(
          capability: capability,
          actorType: actor.actorType,
          reason: 'partner cannot see audit details',
        );
    }
  }
}

// ───────────────────────── 内部解析 helper ─────────────────────────

String? _optionalString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String && value.isEmpty) return null;
  return value is String ? value : null;
}
