import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum SyncTelemetryStatus {
  unavailable,
  blocked,
  completed,
  skippedBusy,
  failed,
}

class SyncTelemetry {
  const SyncTelemetry({
    required this.trigger,
    required this.status,
    required this.timestamp,
    this.pullApplied = 0,
    this.pullConflicts = 0,
    this.pushPushed = 0,
    this.pushFailed = 0,
    this.reason,
    this.error,
  });

  final String trigger;
  final SyncTelemetryStatus status;
  final int pullApplied;
  final int pullConflicts;
  final int pushPushed;
  final int pushFailed;
  final String? reason;
  final String? error;
  final String timestamp;

  Map<String, Object?> toJson() {
    return {
      'trigger': trigger,
      'status': status.name,
      'pullApplied': pullApplied,
      'pullConflicts': pullConflicts,
      'pushPushed': pushPushed,
      'pushFailed': pushFailed,
      if (reason != null) 'reason': reason,
      if (error != null) 'error': error,
      'timestamp': timestamp,
    };
  }

  static SyncTelemetry? fromJson(Map<String, Object?> json) {
    final trigger = json['trigger'];
    final status = _statusFromName(json['status']);
    final timestamp = json['timestamp'];
    if (trigger is! String || trigger.isEmpty) return null;
    if (status == null) return null;
    if (timestamp is! String || timestamp.isEmpty) return null;

    return SyncTelemetry(
      trigger: trigger,
      status: status,
      pullApplied: _intValue(json['pullApplied']),
      pullConflicts: _intValue(json['pullConflicts']),
      pushPushed: _intValue(json['pushPushed']),
      pushFailed: _intValue(json['pushFailed']),
      reason: _stringValue(json['reason']),
      error: _stringValue(json['error']),
      timestamp: timestamp,
    );
  }

  static SyncTelemetryStatus? _statusFromName(Object? value) {
    if (value is! String) return null;
    for (final status in SyncTelemetryStatus.values) {
      if (status.name == value) return status;
    }
    return null;
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String? _stringValue(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }
}

abstract class SyncTelemetryStore {
  Future<SyncTelemetry?> read();

  Future<void> write(SyncTelemetry telemetry);
}

class NoOpSyncTelemetryStore implements SyncTelemetryStore {
  const NoOpSyncTelemetryStore();

  @override
  Future<SyncTelemetry?> read() async => null;

  @override
  Future<void> write(SyncTelemetry telemetry) async {}
}

class SharedPreferencesSyncTelemetryStore implements SyncTelemetryStore {
  const SharedPreferencesSyncTelemetryStore();

  static const String key = 'sync.telemetry.lastResult.v1';

  @override
  Future<SyncTelemetry?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return SyncTelemetry.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(SyncTelemetry telemetry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(telemetry.toJson()));
  }
}
