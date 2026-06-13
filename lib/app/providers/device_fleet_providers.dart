import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../app/cloud_backup_config.dart';
import '../../app/phone_login_store.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/fuel_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/services/backup/cloud_backup_service.dart';
import '../../infrastructure/cloud/cloud_backup_cipher.dart';
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
    final cloudBackupController = cloudBackupEndpoint.isAvailable
        ? CloudBackupController(
            availability: CloudBackupAvailability.available(
              usesBusinessApiFallback:
                  cloudBackupEndpoint.usesBusinessApiFallback,
            ),
            service: CloudBackupService(
              gateway: HttpCloudBackupGateway(
                HttpCloudApiClient(
                  baseUrl: cloudBackupEndpoint.baseUrl!,
                  accessTokenProvider: () async {
                    final session = await phoneLoginStore.read();
                    return session.isAuthenticated ? session.authToken : null;
                  },
                ),
              ),
              // 账号绑定客户端加密（OSS 只存密文）。账号密钥须由账号服务在
              // 登录时下发的高熵稳定秘密——当前后端未部署/未下发,提供者返回
              // null;生产口径 requireEncryption=true 时拒绝上传明文,避免业务
              // 数据明文上云(PIPL/合规)。后端就绪后在此接入真实账号密钥来源。
              keyProvider: CallbackCloudBackupKeyProvider(
                _resolveAccountBackupSecret,
              ),
              requireEncryption: CloudBackupConfig.isProductionBuild,
            ),
          )
        : CloudBackupController.unavailable(
            cloudBackupEndpoint.disabledMessage ?? '云端备份服务暂未配置',
          );

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

/// 账号绑定的备份密钥来源（后端集成点）。
///
/// 账号绑定派生要求账号服务在登录时下发一份**高熵稳定**的备份秘密（不是手机号、
/// 不是会轮换的 authToken）。后端就绪后在此返回该秘密;当前未部署/未下发,返回
/// null —— 生产口径下会拒绝上传明文(见 CloudBackupService.requireEncryption)。
Future<String?> _resolveAccountBackupSecret() async => null;
