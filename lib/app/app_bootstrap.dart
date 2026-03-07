import '../features/device/state/device_store.dart';
import '../features/fuel/state/fuel_store.dart';
import '../features/account/state/account_payment_store.dart';
import '../features/account/state/project_rate_store.dart';
import '../features/timing/state/timing_store.dart';

class AppBootstrap {
  static Future<void> preload({
    required DeviceStore deviceStore,
    required TimingStore timingStore,
    required FuelStore fuelStore,
    required AccountPaymentStore paymentStore,
    required ProjectRateStore projectRateStore,
  }) async {
    await deviceStore.loadAll();
    await timingStore.loadAll();
    await fuelStore.loadAll();
    await paymentStore.loadAll();
    await projectRateStore.loadAll();
  }
}
