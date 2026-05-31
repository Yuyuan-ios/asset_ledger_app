/// 阶段 D Step 25：actor 类型枚举下沉到 core 层。
///
/// 背景：D23 的 [OperationActorType]（当时叫 `OperationAuditActorType`，定义在
/// `lib/data/models/operation_audit_log.dart`）被 core 层的
/// `operation_access_control.dart` 直接 import，触发 custom_lint 规则
/// `no_core_layer_imports_from_upper_layers`（core 不得 import data/app/features）。
///
/// 修复方式：actor 类型本质上是 core 概念，应当由 core 拥有。本文件把枚举下沉到
/// core，data 层的 `OperationAuditActorType` 改为指向本枚举的 typedef（data → core
/// 是允许的依赖方向）。wireName 保持不变（owner / driver / partner / agent /
/// system / unknown），不影响审计 JSON / DB 存储格式。
///
/// 约束：本文件纯 Dart，不 import Flutter / DB / repository / feature。
library;

/// 谁触发了这次操作。
enum OperationActorType {
  owner,
  driver,
  partner,
  agent,
  system,
  unknown;

  String get wireName {
    switch (this) {
      case OperationActorType.owner:
        return 'owner';
      case OperationActorType.driver:
        return 'driver';
      case OperationActorType.partner:
        return 'partner';
      case OperationActorType.agent:
        return 'agent';
      case OperationActorType.system:
        return 'system';
      case OperationActorType.unknown:
        return 'unknown';
    }
  }

  static OperationActorType fromWireName(String wireName) {
    final parsed = tryParse(wireName);
    if (parsed == null) {
      throw ArgumentError.value(
        wireName,
        'wireName',
        'Unknown OperationActorType',
      );
    }
    return parsed;
  }

  static OperationActorType? tryParse(String? wireName) {
    for (final value in OperationActorType.values) {
      if (value.wireName == wireName) return value;
    }
    return null;
  }
}
