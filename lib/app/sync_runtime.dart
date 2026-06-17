import '../infrastructure/sync/sync_device_registration.dart';
import '../infrastructure/sync/sync_manager.dart';

class SyncRuntime {
  const SyncRuntime.available({
    required this.baseUrl,
    required SyncManager syncManager,
    required SyncDeviceRegistrar deviceRegistrar,
  }) : disabledMessage = null,
       _syncManager = syncManager,
       _deviceRegistrar = deviceRegistrar;

  const SyncRuntime.unavailable(this.disabledMessage)
    : baseUrl = null,
      _syncManager = null,
      _deviceRegistrar = null;

  final String? baseUrl;
  final String? disabledMessage;
  final SyncManager? _syncManager;
  final SyncDeviceRegistrar? _deviceRegistrar;

  bool get isAvailable => _syncManager != null && _deviceRegistrar != null;

  bool get isUnavailable => !isAvailable;

  SyncManager? get syncManager => _syncManager;

  SyncDeviceRegistrar? get deviceRegistrar => _deviceRegistrar;

  Future<SyncDeviceRegistrationResult> registerDeviceIfNeeded() {
    final registrar = _deviceRegistrar;
    if (registrar == null) {
      return Future.value(const SyncDeviceRegistrationResult.unavailable());
    }
    return registrar.registerIfNeeded(syncAvailable: true);
  }
}
