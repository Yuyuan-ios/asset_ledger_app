import '../../../data/models/device.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/services/device_service.dart';
import '../../../core/utils/base_store.dart';

class DeviceStore extends BaseStore {
  // -------------------------------------------------------------------
  // 核心数据
  // -------------------------------------------------------------------
  List<Device> _devices = [];

  List<Device> get allDevices => List.unmodifiable(_devices);

  List<Device> get activeDevices =>
      List.unmodifiable(_devices.where((d) => d.isActive));

  // =====================================================================
  // 内部防御
  // =====================================================================

  Future<void> _ensureLoaded() async {
    if (_devices.isNotEmpty) return;
    _devices = _normalizeDevices(await DeviceRepo.listAll());
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
      _devices = _normalizeDevices(await DeviceRepo.listAll());
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
    await run(() async {
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

      await DeviceRepo.insert(d);
      _devices = _normalizeDevices(await DeviceRepo.listAll());
    });
  }

  Future<void> update(Device device) async {
    await run(() async {
      await DeviceRepo.update(_normalizeDevice(device));
      _devices = _normalizeDevices(await DeviceRepo.listAll());
    });
  }

  Future<void> deactivateById(int id) async {
    await run(() async {
      await DeviceRepo.setActive(id, false);
      _devices = _normalizeDevices(await DeviceRepo.listAll());
    });
  }

  Future<void> activateById(int id) async {
    await run(() async {
      await DeviceRepo.setActive(id, true);
      _devices = _normalizeDevices(await DeviceRepo.listAll());
    });
  }

  // =====================================================================
  // 查
  // =====================================================================

  Device? findById(int id) {
    for (final d in _devices) {
      if (d.id == id) return d;
    }
    return null;
  }
}
