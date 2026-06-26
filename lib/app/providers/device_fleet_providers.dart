import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../core/operations/operation_access_control.dart';
import '../../app/cloud_backup_config.dart';
import '../../app/app_runtime_metadata.dart';
import '../../app/phone_login_store.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/fuel_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/services/backup/cloud_backup_service.dart';
import '../../data/services/subscription_service.dart';
import '../../infrastructure/cloud/http_cloud_backup_key_provider.dart';
import '../../features/device/application/controllers/cloud_backup_controller.dart';
import '../../features/device/application/controllers/local_backup_controller.dart';
import '../../features/device/domain/repositories/local_backup_repository.dart';
import '../../features/device/state/device_store.dart';
import '../../features/fuel/state/fuel_store.dart';
import '../../features/maintenance/state/maintenance_store.dart';
import '../../infrastructure/cloud/cloud_backup_gateway.dart';
import '../../infrastructure/cloud/api_client.dart';
import '../../infrastructure/cloud/http_cloud_api_client.dart';
import '../../infrastructure/local/backup/local_backup_repository_adapter.dart';
import '../../infrastructure/local/fuel/local_fuel_log_write_use_case.dart';
import '../../infrastructure/local/maintenance/local_maintenance_record_write_use_case.dart';

typedef DeviceFleetCloudApiClientFactory =
    CloudApiClient Function({
      required String baseUrl,
      required Future<String?> Function() accessTokenProvider,
      Future<String?> Function()? appVersionProvider,
      String? platform,
      UpgradeRequiredCallback? onUpgradeRequired,
    });

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

  factory DeviceFleetProviders.build({
    ActorContext? actorContext,
    CloudBackupEndpointConfig? endpointConfig,
    DeviceFleetCloudApiClientFactory cloudApiClientFactory =
        _createHttpCloudApiClient,
    UpgradeRequiredCallback? onUpgradeRequired,
  }) {
    final actorProvider = actorContext == null ? null : () => actorContext;
    final deviceRepository = SqfliteDeviceRepository();
    final fuelRepository = SqfliteFuelRepository();
    final maintenanceRepository = SqfliteMaintenanceRepository();
    const localBackupRepository = LocalBackupDataRepository();
    const phoneLoginStore = SharedPreferencesPhoneLoginStore();

    final deviceStore = DeviceStore(deviceRepository);
    final fuelWriteUseCase = LocalFuelLogWriteUseCase(
      fuelRepository: fuelRepository,
      actorProvider: actorProvider,
    );
    final fuelStore = FuelStore(fuelRepository, writeUseCase: fuelWriteUseCase);
    final maintenanceWriteUseCase = LocalMaintenanceRecordWriteUseCase(
      maintenanceRepository: maintenanceRepository,
      actorProvider: actorProvider,
    );
    final maintenanceStore = MaintenanceStore(
      maintenanceRepository,
      writeUseCase: maintenanceWriteUseCase,
    );
    const localBackupController = LocalBackupController(localBackupRepository);
    final cloudBackupEndpoint = endpointConfig ?? CloudBackupConfig.current;
    final CloudBackupController cloudBackupController;
    if (cloudBackupEndpoint.isAvailable) {
      // 备份传输与账号密钥下发共用同一鉴权客户端(同 baseUrl + Bearer)。
      final cloudClient = cloudApiClientFactory(
        baseUrl: cloudBackupEndpoint.baseUrl!,
        accessTokenProvider: () async {
          final session = await phoneLoginStore.read();
          return session.isAuthenticated ? session.authToken : null;
        },
        appVersionProvider: AppRuntimeMetadata.cloudApiVersionHeader,
        platform: AppRuntimeMetadata.platform,
        onUpgradeRequired: onUpgradeRequired,
      );
      cloudBackupController = CloudBackupController(
        availability: CloudBackupAvailability.available(
          usesBusinessApiFallback: cloudBackupEndpoint.usesBusinessApiFallback,
        ),
        canUseCloudBackup: () => SubscriptionService.canUseCloudBackup,
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
      // server 下发文案(nullable)透传给 controller;view 层缺省时兜底为
      // 本地化的 deviceCloudBackupNotConfigured。
      cloudBackupController = CloudBackupController.unavailable(
        cloudBackupEndpoint.disabledMessage,
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

  static CloudApiClient _createHttpCloudApiClient({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
    Future<String?> Function()? appVersionProvider,
    String? platform,
    UpgradeRequiredCallback? onUpgradeRequired,
  }) {
    return HttpCloudApiClient(
      baseUrl: baseUrl,
      accessTokenProvider: accessTokenProvider,
      appVersionProvider: appVersionProvider,
      platform: platform,
      onUpgradeRequired: onUpgradeRequired,
    );
  }
}
