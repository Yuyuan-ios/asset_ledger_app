import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../infrastructure/cloud/api_client.dart';
import '../../infrastructure/cloud/http_cloud_api_client.dart';
import '../../infrastructure/sync/sync_device_registration.dart';
import '../../infrastructure/sync/sync_live_readiness_gate.dart';
import '../../infrastructure/sync/sync_manager.dart';
import '../../infrastructure/sync/sync_repositories.dart';
import '../../infrastructure/sync/sync_state_repository.dart';
import '../../infrastructure/sync/sync_telemetry.dart';
import '../../features/app_update/domain/version_gate_decision.dart';
import '../identity/app_identity_service.dart';
import '../phone_login_store.dart';
import '../app_runtime_metadata.dart';
import '../sync_production_caller.dart';
import '../sync_runtime.dart';
import '../sync_transport_config.dart';

typedef SyncCloudApiClientFactory =
    CloudApiClient Function({
      required String baseUrl,
      required Future<String?> Function() accessTokenProvider,
      Future<String?> Function()? appVersionProvider,
      String? platform,
      void Function(VersionGateDecision decision)? onUpgradeRequired,
    });

class SyncProviders {
  SyncProviders._({
    required this.runtime,
    required this.caller,
    required this.providers,
  });

  final SyncRuntime runtime;
  final SyncProductionCaller caller;
  final List<SingleChildWidget> providers;

  factory SyncProviders.build({
    SyncTransportEndpointConfig? endpointConfig,
    PhoneLoginStore phoneLoginStore = const SharedPreferencesPhoneLoginStore(),
    SyncCloudApiClientFactory cloudApiClientFactory = _createHttpCloudApiClient,
    SyncDeviceRegistrationStore registrationStore =
        const SharedPreferencesSyncDeviceRegistrationStore(),
    SyncTelemetryStore telemetryStore =
        const SharedPreferencesSyncTelemetryStore(),
    SyncLiveReadinessGate? liveReadinessGate,
    String Function()? deviceIdProvider,
    void Function(VersionGateDecision decision)? onUpgradeRequired,
  }) {
    final config = endpointConfig ?? SyncTransportConfig.current;
    final gate =
        liveReadinessGate ??
        DefaultSyncLiveReadinessGate(transportConfigured: config.isAvailable);
    if (!config.isAvailable) {
      final runtime = SyncRuntime.unavailable(
        config.disabledMessage ?? '同步服务暂未配置',
      );
      final caller = SyncProductionCaller(
        runtime: runtime,
        liveReadinessGate: gate,
        telemetryStore: telemetryStore,
      );
      return SyncProviders._(
        runtime: runtime,
        caller: caller,
        providers: [
          Provider<SyncRuntime>.value(value: runtime),
          Provider<SyncProductionCaller>.value(value: caller),
          Provider<SyncTelemetryStore>.value(value: telemetryStore),
        ],
      );
    }

    final currentDeviceId =
        deviceIdProvider ?? () => AppIdentityService.instance.currentDeviceId;
    final deviceId = currentDeviceId().trim();
    final cloudClient = cloudApiClientFactory(
      baseUrl: config.baseUrl!,
      accessTokenProvider: () async {
        final session = await phoneLoginStore.read();
        return session.isAuthenticated ? session.authToken : null;
      },
      appVersionProvider: AppRuntimeMetadata.cloudApiVersionHeader,
      platform: AppRuntimeMetadata.platform,
      onUpgradeRequired: onUpgradeRequired,
    );
    final syncManager = SyncManager(
      outboxRepository: const LocalSyncOutboxRepository(),
      apiClient: cloudClient,
      syncStateRepository: const LocalSyncStateRepository(),
      liveReadinessGate: gate,
      localDeviceId: deviceId.isEmpty ? null : deviceId,
    );
    final deviceRegistrar = SyncDeviceRegistrar(
      apiClient: cloudClient,
      registrationStore: registrationStore,
      deviceIdProvider: () => deviceId,
    );
    final runtime = SyncRuntime.available(
      baseUrl: config.baseUrl!,
      syncManager: syncManager,
      deviceRegistrar: deviceRegistrar,
    );
    final caller = SyncProductionCaller(
      runtime: runtime,
      liveReadinessGate: gate,
      telemetryStore: telemetryStore,
    );

    return SyncProviders._(
      runtime: runtime,
      caller: caller,
      providers: [
        Provider<SyncRuntime>.value(value: runtime),
        Provider<SyncProductionCaller>.value(value: caller),
        Provider<SyncManager>.value(value: syncManager),
        Provider<SyncDeviceRegistrar>.value(value: deviceRegistrar),
        Provider<SyncTelemetryStore>.value(value: telemetryStore),
      ],
    );
  }

  static CloudApiClient _createHttpCloudApiClient({
    required String baseUrl,
    required Future<String?> Function() accessTokenProvider,
    Future<String?> Function()? appVersionProvider,
    String? platform,
    void Function(VersionGateDecision decision)? onUpgradeRequired,
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
