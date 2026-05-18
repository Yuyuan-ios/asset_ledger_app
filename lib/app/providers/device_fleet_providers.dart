import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../data/repositories/device_repository.dart';
import '../../data/repositories/fuel_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../features/device/application/controllers/local_backup_controller.dart';
import '../../features/device/domain/repositories/local_backup_repository.dart';
import '../../features/device/state/device_store.dart';
import '../../features/fuel/state/fuel_store.dart';
import '../../features/maintenance/state/maintenance_store.dart';
import '../../infrastructure/local/backup/local_backup_repository_adapter.dart';

/// Device / fuel / maintenance composition slice.
class DeviceFleetProviders {
  DeviceFleetProviders._({
    required this.deviceStore,
    required this.fuelStore,
    required this.maintenanceStore,
    required this.localBackupController,
    required this.providers,
  });

  final DeviceStore deviceStore;
  final FuelStore fuelStore;
  final MaintenanceStore maintenanceStore;
  final LocalBackupController localBackupController;
  final List<SingleChildWidget> providers;

  factory DeviceFleetProviders.build() {
    final deviceRepository = SqfliteDeviceRepository();
    final fuelRepository = SqfliteFuelRepository();
    final maintenanceRepository = SqfliteMaintenanceRepository();
    const localBackupRepository = LocalBackupDataRepository();

    final deviceStore = DeviceStore(deviceRepository);
    final fuelStore = FuelStore(fuelRepository);
    final maintenanceStore = MaintenanceStore(maintenanceRepository);
    const localBackupController = LocalBackupController(localBackupRepository);

    return DeviceFleetProviders._(
      deviceStore: deviceStore,
      fuelStore: fuelStore,
      maintenanceStore: maintenanceStore,
      localBackupController: localBackupController,
      providers: [
        Provider<DeviceRepository>.value(value: deviceRepository),
        Provider<FuelRepository>.value(value: fuelRepository),
        Provider<MaintenanceRepository>.value(value: maintenanceRepository),
        Provider<LocalBackupRepository>.value(value: localBackupRepository),
        Provider<LocalBackupController>.value(value: localBackupController),
        ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
        ChangeNotifierProvider<FuelStore>.value(value: fuelStore),
        ChangeNotifierProvider<MaintenanceStore>.value(value: maintenanceStore),
      ],
    );
  }
}
