import 'dart:math';

import '../../core/operations/operation_access_control.dart';
import '../../core/operations/operation_actor_type.dart';
import 'owner_id_store.dart';

/// 本机身份服务：生成并持有当前设备的唯一 owner 身份。
///
/// R5.21：ownerId 现已通过 [OwnerIdStore] 持久化（生产走 SharedPreferences）。
/// - 应用启动时（如 `main.dart`）必须 `await AppIdentityService.initialize()`；
///   该方法幂等：首次会读 store，缺失则生成 UUID 并 write 回去；之后任意
///   一次重启或 service 重新构造，都会读到同一个 ownerId。
/// - 未调用 [initialize] 时（例如旧的纯同步测试），`currentActorContext()`
///   会回退到老的 in-memory UUID 生成器，保留旧测试与历史调用方的兼容性。
/// - `resetForTest` 用于测试之间隔离：清掉单例缓存的 _ownerId、丢弃旧 store，
///   重新跑一次 initialize；从而测试可以模拟"应用第二次启动应读到同一个 id"
///   或"清空存储后会生成新 id"。
class AppIdentityService {
  AppIdentityService._({String? ownerId, String Function()? generator})
    : _ownerId = ownerId ?? (generator ?? _generateOwnerId)();

  static AppIdentityService _instance = AppIdentityService._();

  /// 获取单例
  static AppIdentityService get instance => _instance;

  /// 本机 ownerId：在 [initialize] 之后为持久化值；在未 initialize 的兜底
  /// 路径下为首次构造时生成的 in-memory UUID。
  final String _ownerId;

  /// Track B sync 使用的本机 device_id。
  ///
  /// 设备注册沿用既有 app_identity 持久化 ID，不另造第二套本机身份。
  String get currentDeviceId => _ownerId;

  /// 应用启动时调用，幂等：首次会读 [store]；缺失时生成新 UUID 并 write。
  /// 已有持久化值的实例会直接复用，不重写。
  ///
  /// 重复调用安全：只在「单例 _ownerId 仍是首次构造时的 in-memory 值」且 store
  /// 中已有持久化值的情况下，把单例切换到持久化值。生产入口保证只调用一次。
  static Future<void> initialize({
    OwnerIdStore? store,
    String Function()? generator,
  }) async {
    final activeStore = store ?? const SharedPreferencesOwnerIdStore();
    final activeGenerator = generator ?? _generateOwnerId;
    final existing = await activeStore.read();
    if (existing != null && existing.isNotEmpty) {
      _instance = AppIdentityService._(
        ownerId: existing,
        generator: activeGenerator,
      );
      return;
    }
    final generated = activeGenerator();
    await activeStore.write(generated);
    _instance = AppIdentityService._(
      ownerId: generated,
      generator: activeGenerator,
    );
  }

  /// 仅供测试使用：按提供的 [store] / [generator] 重新跑一次 [initialize]，
  /// 让单例切换到新 store 决定的 ownerId。
  ///
  /// 实现上只调用 [initialize]：initialize 自己会重新读 store 并重新写
  /// _instance，因此不需要先手工构造一个"未初始化"过渡态——那样会让 generator
  /// 在被 initialize 读到 store 之前先空跑一次，破坏"持久 id 唯一来源是 store"
  /// 的不变量。
  static Future<void> resetForTest({
    OwnerIdStore? store,
    String Function()? generator,
  }) async {
    await initialize(store: store, generator: generator);
  }

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
