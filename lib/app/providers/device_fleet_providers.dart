import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../app/cloud_backup_config.dart';
import '../../app/phone_login_store.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/fuel_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/services/backup/cloud_backup_service.dart';
import '../../infrastructure/cloud/http_cloud_backup_key_provider.dart';
import '../../features/device/application/controllers/cloud_backup_controller.dart';
import '../../features/device/application/controllers/local_backup_controller.dart';
import '../../features/device/domain/repositories/local_backup_repository.dart';
import '../../features/device/state/device_store.dart';
import '../../features/fuel/state/fuel_store.dart';
import '../../features/maintenance/state/maintenance_store.dart';
import '../../infrastructure/cloud/cloud_backup_gateway.dart';
import '../../infrastructure/cloud/http_cloud_api_client.dart';
import '../../infrastructure/local/backup/local_backup_repository_adapter.dart';

/// Device / fuel / maintenance composition slice.
class DeviceFleetProviders {
  DeviceFleetProviders._({
    required this.deviceStore,
    required this.fuelStore,
    required this.maintenanceStore,
    required this.localBackupController,
    required this.cloudBackupController,
    required this.providers,
  });

  final DeviceStore deviceStore;
  final FuelStore fuelStore;
  final MaintenanceStore maintenanceStore;
  final LocalBackupController localBackupController;
  final CloudBackupController cloudBackupController;
  final List<SingleChildWidget> providers;

  factory DeviceFleetProviders.build() {
    final deviceRepository = SqfliteDeviceRepository();
    final fuelRepository = SqfliteFuelRepository();
    final maintenanceRepository = SqfliteMaintenanceRepository();
    const localBackupRepository = LocalBackupDataRepository();
    const phoneLoginStore = SharedPreferencesPhoneLoginStore();

    final deviceStore = DeviceStore(deviceRepository);
    final fuelStore = FuelStore(fuelRepository);
    final maintenanceStore = MaintenanceStore(maintenanceRepository);
    const localBackupController = LocalBackupController(localBackupRepository);
    final cloudBackupEndpoint = CloudBackupConfig.current;
    final CloudBackupController cloudBackupController;
    if (cloudBackupEndpoint.isAvailable) {
      // 备份传输与账号密钥下发共用同一鉴权客户端(同 baseUrl + Bearer)。
      final cloudClient = HttpCloudApiClient(
        baseUrl: cloudBackupEndpoint.baseUrl!,
        accessTokenProvider: () async {
          final session = await phoneLoginStore.read();
          return session.isAuthenticated ? session.authToken : null;
        },
      );
      cloudBackupController = CloudBackupController(
        availability: CloudBackupAvailability.available(
          usesBusinessApiFallback: cloudBackupEndpoint.usesBusinessApiFallback,
        ),
        service: CloudBackupService(
          gateway: HttpCloudBackupGateway(cloudClient),
          // 账号绑定客户端加密(OSS 只存密文）:密钥由后端
          // GET /v1/account/backup-key 下发(HMAC 派生的稳定高熵秘密)。
          // 拉取失败(未登录/未配置/网络)→ null → 生产 requireEncryption
          // 拒绝上传明文(PIPL/合规兜底),不静默降级。
          keyProvider: HttpCloudBackupKeyProvider(cloudClient),
          requireEncryption: CloudBackupConfig.isProductionBuild,
        ),
      );
    } else {
      cloudBackupController = CloudBackupController.unavailable(
        cloudBackupEndpoint.disabledMessage ?? '云端备份服务暂未配置',
      );
    }

    return DeviceFleetProviders._(
      deviceStore: deviceStore,
      fuelStore: fuelStore,
      maintenanceStore: maintenanceStore,
      localBackupController: localBackupController,
      cloudBackupController: cloudBackupController,
      providers: [
        Provider<DeviceRepository>.value(value: deviceRepository),
        Provider<FuelRepository>.value(value: fuelRepository),
        Provider<MaintenanceRepository>.value(value: maintenanceRepository),
        Provider<LocalBackupRepository>.value(value: localBackupRepository),
        Provider<LocalBackupController>.value(value: localBackupController),
        Provider<CloudBackupController>.value(value: cloudBackupController),
        ChangeNotifierProvider<DeviceStore>.value(value: deviceStore),
        ChangeNotifierProvider<FuelStore>.value(value: fuelStore),
        ChangeNotifierProvider<MaintenanceStore>.value(value: maintenanceStore),
      ],
    );
  }
}
