import 'dart:math';

import '../../core/operations/operation_access_control.dart';
import '../../core/operations/operation_actor_type.dart';

/// 本机身份服务：生成并持有当前设备的唯一 owner 身份。
///
/// 当前实现使用内存中 UUID（各 session 不同），未来可扩展到 sqflite 持久化
/// 或其他持久设备标识。
class AppIdentityService {
  AppIdentityService._() : _ownerId = _generateOwnerId();

  static final AppIdentityService _instance = AppIdentityService._();

  /// 获取单例
  static AppIdentityService get instance => _instance;

  /// 本机 ownerId（当前 session 的 UUID）
  final String _ownerId;

  static String _generateOwnerId() {
    // UUIDv4-like 随机字符串
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    // Format as UUID
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final parts = <String>[];
    for (var i = 0; i < 16; i++) {
      parts.add(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return '${parts[0]}${parts[1]}${parts[2]}${parts[3]}-'
        '${parts[4]}${parts[5]}-'
        '${parts[6]}${parts[7]}-'
        '${parts[8]}${parts[9]}-'
        '${parts[10]}${parts[11]}${parts[12]}${parts[13]}${parts[14]}${parts[15]}';
  }

  /// 返回当前设备的 ActorContext，固定 actorType=owner。
  ///
  /// 本机手动操作允许 actorId 为空（本机就是 owner）。
  /// sessionId 为空，未来 MCP / Operator Work Link 场景可扩展。
  /// 支持 future 扩展：delegatedActorType / delegatedActorId / scope hash。
  ActorContext currentActorContext() {
    return ActorContext(
      actorType: OperationActorType.owner,
      actorId: _ownerId,
      sessionId: null,
    );
  }
}
