import '../features/device/state/device_store.dart';
import '../features/fuel/state/fuel_store.dart';
import '../features/maintenance/state/maintenance_store.dart';
import '../features/account/state/project_rate_store.dart';
import '../features/timing/state/timing_store.dart';

class AppBootstrap {
  static Future<void> preload({
    required DeviceStore deviceStore,
    required TimingStore timingStore,
    required FuelStore fuelStore,
    required MaintenanceStore maintenanceStore,
    required ProjectRateStore projectRateStore,
  }) async {
    await Future.wait([
      deviceStore.loadAll(),
      timingStore.loadAll(),
      fuelStore.loadAll(),
      maintenanceStore.loadAll(),
      projectRateStore.loadAll(),
    ]);
  }
}
