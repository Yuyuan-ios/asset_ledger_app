import 'package:shared_preferences/shared_preferences.dart';

/// R5.21：本机 ownerId 的持久化存储抽象。
///
/// 生产实现走 [SharedPreferencesOwnerIdStore]，复用 subscription / preferences
/// 已有的 shared_preferences 基础设施，避免引入新依赖；测试通过
/// [InMemoryOwnerIdStore] 注入，可在多次 service 重建之间持久或重置。
abstract class OwnerIdStore {
  Future<String?> read();

  Future<void> write(String ownerId);

  Future<void> clear();
}

class SharedPreferencesOwnerIdStore implements OwnerIdStore {
  const SharedPreferencesOwnerIdStore();

  /// 与 subscription cache 的 `subscription.*` 命名风格保持一致；
  /// 改 key 等同于让所有老用户重新生成 ownerId，慎改。
  static const String preferencesKey = 'app.identity.ownerId';

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(preferencesKey);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> write(String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferencesKey, ownerId);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(preferencesKey);
  }
}

/// 测试 / 单元路径用：进程内 Map 模拟持久化。
class InMemoryOwnerIdStore implements OwnerIdStore {
  InMemoryOwnerIdStore({String? initial}) : _value = initial;

  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String ownerId) async {
    _value = ownerId;
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}
