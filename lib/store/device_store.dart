import '../models/device.dart';
import '../repos/device_repo.dart';
import '../services/device_service.dart';
import 'base_store.dart';

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
    _devices = await DeviceRepo.listAll();
  }

  // =====================================================================
  // 读
  // =====================================================================

  Future<void> loadAll() async {
    await run(() async {
      _devices = await DeviceRepo.listAll();
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

      if (!d.isActive) {
        d = d.copyWith(isActive: true);
      }

      await DeviceRepo.insert(d);
      _devices = await DeviceRepo.listAll();
    });
  }

  Future<void> update(Device device) async {
    await run(() async {
      await DeviceRepo.update(device);
      _devices = await DeviceRepo.listAll();
    });
  }

  Future<void> deactivateById(int id) async {
    await run(() async {
      await DeviceRepo.setActive(id, false);
      _devices = await DeviceRepo.listAll();
    });
  }

  Future<void> activateById(int id) async {
    await run(() async {
      await DeviceRepo.setActive(id, true);
      _devices = await DeviceRepo.listAll();
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
