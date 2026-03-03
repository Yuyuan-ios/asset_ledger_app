import '../../../data/models/device.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/services/device_service.dart';
import '../../../core/utils/base_store.dart';

class DeviceStore extends BaseStore {
  DeviceStore(this._repository);

  final DeviceRepository _repository;

  // -------------------------------------------------------------------
  // 核心数据
  // -------------------------------------------------------------------
  List<Device> _devices = [];
  bool _loaded = false;

  List<Device> get allDevices => List.unmodifiable(_devices);
  bool get hasLoaded => _loaded;

  List<Device> get activeDevices =>
      List.unmodifiable(_devices.where((d) => d.isActive));

  // =====================================================================
  // 内部防御
  // =====================================================================

  Future<void> _reload() async {
    _devices = _normalizeDevices(await _repository.listAll());
    _loaded = true;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await _reload();
  }

  String _normalizeDeviceName(String name) => name.trim().toUpperCase();

  Device _normalizeDevice(Device d) {
    final normalized = _normalizeDeviceName(d.name);
    return normalized == d.name ? d : d.copyWith(name: normalized);
  }

  List<Device> _normalizeDevices(List<Device> list) {
    return list.map(_normalizeDevice).toList(growable: false);
  }

  // =====================================================================
  // 读
  // =====================================================================

  Future<void> loadAll() async {
    await run(() async {
      await _reload();
    });
  }

  // =====================================================================
  // UI 预览接口
  // =====================================================================

  int previewNextIndex(String brand) {
    return DeviceService.nextIndex(brand: brand, activeDevices: activeDevices);
  }

  String previewNextName(String brand) {
    return DeviceService.nextDisplayName(
      brand: brand,
      activeDevices: activeDevices,
    );
  }

  // =====================================================================
  // 写：新增 / 更新 / 停用 / 启用
  // =====================================================================

  Future<void> insert(Device device) async {
    await writeAndReload(
      write: () async {
        await _ensureLoaded();

        final brand = device.brand.trim();
        if (brand.isEmpty) {
          throw Exception('DeviceStore.insert: brand 不能为空');
        }

        var d = device;

        if (d.name.trim().isEmpty) {
          final autoName = DeviceService.nextDisplayName(
            brand: brand,
            activeDevices: activeDevices,
          );
          d = d.copyWith(name: autoName);
        }

        d = _normalizeDevice(d);

        if (!d.isActive) {
          d = d.copyWith(isActive: true);
        }

        await _repository.insert(d);
      },
      reload: _reload,
    );
  }

  Future<void> update(Device device) async {
    await writeAndReload(
      write: () => _repository.update(_normalizeDevice(device)),
      reload: _reload,
    );
  }

  Future<void> deactivateById(int id) async {
    await writeAndReload(
      write: () => _repository.setActive(id, false),
      reload: _reload,
    );
  }

  Future<void> activateById(int id) async {
    await writeAndReload(
      write: () => _repository.setActive(id, true),
      reload: _reload,
    );
  }

  // =====================================================================
  // 查
  // =====================================================================

  Device? tryFindById(int id) {
    if (!_loaded) return null;
    return _findLoadedById(id);
  }

  Device? findById(int id) {
    if (!_loaded) {
      throw StateError('DeviceStore.findById: devices have not been loaded');
    }
    return _findLoadedById(id);
  }

  Device? _findLoadedById(int id) {
    for (final d in _devices) {
      if (d.id == id) return d;
    }
    return null;
  }
}
