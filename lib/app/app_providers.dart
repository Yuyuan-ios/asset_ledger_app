import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../data/repositories/account_payment_repository.dart';
import '../data/repositories/account_project_merge_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/fuel_repository.dart';
import '../data/repositories/maintenance_repository.dart';
import '../data/repositories/project_rate_repository.dart';
import '../data/repositories/timing_repository.dart';
import '../data/services/account_project_merge_service.dart';
import '../features/account/state/account_store.dart';
import '../features/account/state/account_filter_store.dart';
import '../features/account/state/account_payment_store.dart';
import '../features/account/state/project_rate_store.dart';
import '../features/device/state/device_store.dart';
import '../features/fuel/state/fuel_store.dart';
import '../features/maintenance/state/maintenance_store.dart';
import '../features/timing/state/timing_store.dart';

class AppProviders {
  static AppProviderBundle build() {
    final deviceRepository = SqfliteDeviceRepository();
    final timingRepository = SqfliteTimingRepository();
    final fuelRepository = SqfliteFuelRepository();
    final maintenanceRepository = SqfliteMaintenanceRepository();
    final accountPaymentRepository = SqfliteAccountPaymentRepository();
    final projectRateRepository = SqfliteProjectRateRepository();
    final accountProjectMergeRepository =
        SqfliteAccountProjectMergeRepository();
    final accountProjectMergeService = AccountProjectMergeService(
      repository: accountProjectMergeRepository,
    );

    final deviceStore = DeviceStore(deviceRepository);
    final timingStore = TimingStore(timingRepository);
    final fuelStore = FuelStore(fuelRepository);
    final maintenanceStore = MaintenanceStore(maintenanceRepository);
    final paymentStore = AccountPaymentStore(accountPaymentRepository);
    final projectRateStore = ProjectRateStore(projectRateRepository);
    final accountStore = AccountStore(mergeService: accountProjectMergeService);

    return AppProviderBundle(
      deviceStore: deviceStore,
      timingStore: timingStore,
      fuelStore: fuelStore,
      maintenanceStore: maintenanceStore,
      paymentStore: paymentStore,
      projectRateStore: projectRateStore,
      accountStore: accountStore,
      providers: [
        Provider<DeviceRepository>.value(value: deviceRepository),
        Provider<TimingRepository>.value(value: timingRepository),
        Provider<FuelRepository>.value(value: fuelRepository),
        Provider<MaintenanceRepository>.value(value: maintenanceRepository),
        Provider<AccountPaymentRepository>.value(
          value: accountPaymentRepository,
        ),
        Provider<ProjectRateRepository>.value(value: projectRateRepository),
        Provider<AccountProjectMergeRepository>.value(
          value: accountProjectMergeRepository,
        ),
        Provider<AccountProjectMergeService>.value(
          value: accountProjectMergeService,
        ),
        ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
        ChangeNotifierProvider<TimingStore>.value(value: timingStore),
        ChangeNotifierProvider<FuelStore>.value(value: fuelStore),
        ChangeNotifierProvider<MaintenanceStore>.value(value: maintenanceStore),
        ChangeNotifierProvider<AccountPaymentStore>.value(value: paymentStore),
        ChangeNotifierProvider<AccountStore>.value(value: accountStore),
        ChangeNotifierProvider<AccountFilterStore>(
          create: (_) => AccountFilterStore(),
        ),
        ChangeNotifierProvider<ProjectRateStore>.value(value: projectRateStore),
      ],
    );
  }
}

class AppProviderBundle {
  final DeviceStore deviceStore;
  final TimingStore timingStore;
  final FuelStore fuelStore;
  final MaintenanceStore maintenanceStore;
  final AccountPaymentStore paymentStore;
  final ProjectRateStore projectRateStore;
  final AccountStore accountStore;
  final List<SingleChildWidget> providers;

  const AppProviderBundle({
    required this.deviceStore,
    required this.timingStore,
    required this.fuelStore,
    required this.maintenanceStore,
    required this.paymentStore,
    required this.projectRateStore,
    required this.accountStore,
    required this.providers,
  });
}
