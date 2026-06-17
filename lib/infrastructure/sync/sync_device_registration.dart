import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/api_client.dart';

enum SyncDeviceRegistrationStatus {
  unavailable,
  alreadyRegistered,
  registered,
  failed,
}

class SyncDeviceRegistrationResult {
  const SyncDeviceRegistrationResult._({
    required this.status,
    this.deviceId,
    this.error,
  });

  const SyncDeviceRegistrationResult.unavailable()
    : this._(status: SyncDeviceRegistrationStatus.unavailable);

  const SyncDeviceRegistrationResult.alreadyRegistered(String deviceId)
    : this._(
        status: SyncDeviceRegistrationStatus.alreadyRegistered,
        deviceId: deviceId,
      );

  const SyncDeviceRegistrationResult.registered(String deviceId)
    : this._(
        status: SyncDeviceRegistrationStatus.registered,
        deviceId: deviceId,
      );

  const SyncDeviceRegistrationResult.failed({String? deviceId, String? error})
    : this._(
        status: SyncDeviceRegistrationStatus.failed,
        deviceId: deviceId,
        error: error,
      );

  final SyncDeviceRegistrationStatus status;
  final String? deviceId;
  final String? error;

  bool get registeredNow => status == SyncDeviceRegistrationStatus.registered;

  bool get isFailure => status == SyncDeviceRegistrationStatus.failed;
}

abstract class SyncDeviceRegistrationStore {
  Future<bool> isRegistered(String deviceId);

  Future<void> markRegistered(String deviceId);
}

class SharedPreferencesSyncDeviceRegistrationStore
    implements SyncDeviceRegistrationStore {
  const SharedPreferencesSyncDeviceRegistrationStore();

  static const String _keyPrefix = 'sync.device_registration.registered.';

  @override
  Future<bool> isRegistered(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(deviceId)) ?? false;
  }

  @override
  Future<void> markRegistered(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(deviceId), true);
  }

  static String _key(String deviceId) => '$_keyPrefix$deviceId';
}

class InMemorySyncDeviceRegistrationStore
    implements SyncDeviceRegistrationStore {
  final Set<String> _registered = <String>{};

  @override
  Future<bool> isRegistered(String deviceId) async {
    return _registered.contains(deviceId);
  }

  @override
  Future<void> markRegistered(String deviceId) async {
    _registered.add(deviceId);
  }
}

class SyncDeviceRegistrar {
  const SyncDeviceRegistrar({
    required CloudApiClient apiClient,
    required SyncDeviceRegistrationStore registrationStore,
    required String Function() deviceIdProvider,
    String Function()? nameProvider,
  }) : _apiClient = apiClient,
       _registrationStore = registrationStore,
       _deviceIdProvider = deviceIdProvider,
       _nameProvider = nameProvider;

  static const String defaultDeviceName = 'Fleet Ledger App';

  final CloudApiClient _apiClient;
  final SyncDeviceRegistrationStore _registrationStore;
  final String Function() _deviceIdProvider;
  final String Function()? _nameProvider;

  Future<SyncDeviceRegistrationResult> registerIfNeeded({
    required bool syncAvailable,
  }) async {
    if (!syncAvailable) {
      return const SyncDeviceRegistrationResult.unavailable();
    }

    final deviceId = _deviceIdProvider().trim();
    if (deviceId.isEmpty) {
      return const SyncDeviceRegistrationResult.failed(
        error: 'missing_device_id',
      );
    }

    try {
      if (await _registrationStore.isRegistered(deviceId)) {
        return SyncDeviceRegistrationResult.alreadyRegistered(deviceId);
      }

      final response = await _apiClient.send(
        ApiRequest(
          method: 'POST',
          path: '/sync/devices',
          bodyJson: jsonEncode(<String, Object?>{
            'device_id': deviceId,
            'name': _resolvedName(),
          }),
        ),
      );

      if (!response.isSuccess) {
        final err = response.error;
        return SyncDeviceRegistrationResult.failed(
          deviceId: deviceId,
          error: err == null
              ? 'http_${response.statusCode}'
              : '${err.code}: ${err.message}',
        );
      }

      await _registrationStore.markRegistered(deviceId);
      return SyncDeviceRegistrationResult.registered(deviceId);
    } catch (error) {
      return SyncDeviceRegistrationResult.failed(
        deviceId: deviceId,
        error: error.toString(),
      );
    }
  }

  String _resolvedName() {
    final raw = _nameProvider?.call().trim();
    if (raw == null || raw.isEmpty) return defaultDeviceName;
    return raw;
  }
}
