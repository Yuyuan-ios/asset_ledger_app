import '../data/db/database.dart';
import '../features/account/state/account_payment_store.dart';
import '../features/account/state/account_store.dart';
import '../features/device/state/device_store.dart';
import '../features/fuel/state/fuel_store.dart';
import '../features/maintenance/state/maintenance_store.dart';
import '../features/account/state/project_rate_store.dart';
import '../features/timing/state/timing_external_work_store.dart';
import '../features/timing/state/timing_store.dart';
import '../core/config/app_environment.dart';

class AppBootstrap {
  static Future<void> seedDemoDataForRuntimeAccessIfNeeded() async {
    if (!RuntimeGate.shouldSeedDemoData) return;
    await AppDatabase.seedDemoData();
  }

  static Future<void> preload({
    required DeviceStore deviceStore,
    required TimingStore timingStore,
    required FuelStore fuelStore,
    required MaintenanceStore maintenanceStore,
    required ProjectRateStore projectRateStore,
    required AccountStore accountStore,
  }) async {
    await Future.wait([
      deviceStore.loadAll(),
      timingStore.loadAll(),
      fuelStore.loadAll(),
      maintenanceStore.loadAll(),
      projectRateStore.loadAll(),
      accountStore.loadAll(),
    ]);
    await projectRateStore.ensureSnapshotsForTimingRecords(
      timingRecords: timingStore.records,
      devices: deviceStore.allDevices,
    );
  }

  static Future<void> seedDemoDataAndReload({
    required DeviceStore deviceStore,
    required TimingStore timingStore,
    required FuelStore fuelStore,
    required MaintenanceStore maintenanceStore,
    required ProjectRateStore projectRateStore,
    required AccountStore accountStore,
    required AccountPaymentStore paymentStore,
    required TimingExternalWorkStore timingExternalWorkStore,
  }) async {
    await AppDatabase.seedDemoData();
    await Future.wait([
      deviceStore.loadAll(),
      timingStore.loadAll(),
      fuelStore.loadAll(),
      maintenanceStore.loadAll(),
      projectRateStore.loadAll(),
      accountStore.loadAll(),
      paymentStore.loadAll(),
      timingExternalWorkStore.loadAll(),
    ]);
    await projectRateStore.ensureSnapshotsForTimingRecords(
      timingRecords: timingStore.records,
      devices: deviceStore.allDevices,
    );
  }
}
