import '../data/db/database.dart';
import '../features/account/state/account_payment_store.dart';
import '../features/account/state/account_store.dart';
import '../features/device/state/device_store.dart';
import '../features/fuel/state/fuel_store.dart';
import '../features/maintenance/state/maintenance_store.dart';
import '../features/account/state/project_rate_store.dart';
import '../features/timing/state/timing_external_work_store.dart';
import '../features/timing/state/timing_store.dart';

class AppBootstrap {
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

  /// App Review demo account only: seed the review ledger, then refresh stores
  /// that may have been preloaded before the reviewer completed login.
  static Future<void> seedAppReviewDemoDataAndReload({
    required DeviceStore deviceStore,
    required TimingStore timingStore,
    required FuelStore fuelStore,
    required MaintenanceStore maintenanceStore,
    required ProjectRateStore projectRateStore,
    required AccountStore accountStore,
    required AccountPaymentStore paymentStore,
    required TimingExternalWorkStore timingExternalWorkStore,
  }) async {
    await AppDatabase.seedAppReviewDemoData();
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
