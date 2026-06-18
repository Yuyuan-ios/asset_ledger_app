import '../infrastructure/sync/sync_live_readiness_gate.dart';
import '../infrastructure/sync/sync_manager.dart';
import '../infrastructure/sync/sync_telemetry.dart';
import 'sync_runtime.dart';

enum SyncProductionTrigger { appStart, foregroundResume, manual }

enum SyncProductionCallStatus {
  unavailable,
  blocked,
  completed,
  skippedBusy,
  failed,
}

class SyncProductionCallResult {
  const SyncProductionCallResult._({
    required this.status,
    this.reason,
    this.pullResult,
    this.pushResult,
  });

  const SyncProductionCallResult.unavailable(String? reason)
    : this._(status: SyncProductionCallStatus.unavailable, reason: reason);

  const SyncProductionCallResult.blocked(String reason)
    : this._(status: SyncProductionCallStatus.blocked, reason: reason);

  const SyncProductionCallResult.completed({
    required SyncPullResult pullResult,
    required SyncPushResult pushResult,
  }) : this._(
         status: SyncProductionCallStatus.completed,
         pullResult: pullResult,
         pushResult: pushResult,
       );

  const SyncProductionCallResult.skippedBusy()
    : this._(status: SyncProductionCallStatus.skippedBusy);

  const SyncProductionCallResult.failed(String reason)
    : this._(status: SyncProductionCallStatus.failed, reason: reason);

  final SyncProductionCallStatus status;
  final String? reason;
  final SyncPullResult? pullResult;
  final SyncPushResult? pushResult;
}

class SyncProductionCaller {
  SyncProductionCaller({
    required SyncRuntime runtime,
    required SyncLiveReadinessGate liveReadinessGate,
    SyncTelemetryStore telemetryStore = const NoOpSyncTelemetryStore(),
    DateTime Function()? now,
  }) : _runtime = runtime,
       _liveReadinessGate = liveReadinessGate,
       _telemetryStore = telemetryStore,
       _now = now ?? DateTime.now;

  final SyncRuntime _runtime;
  final SyncLiveReadinessGate _liveReadinessGate;
  final SyncTelemetryStore _telemetryStore;
  final DateTime Function() _now;
  bool _running = false;

  Future<SyncProductionCallResult> runOnce({
    SyncProductionTrigger trigger = SyncProductionTrigger.manual,
  }) async {
    if (_running) {
      const result = SyncProductionCallResult.skippedBusy();
      await _recordTelemetry(trigger, result);
      return result;
    }
    _running = true;
    late final SyncProductionCallResult result;
    try {
      final manager = _runtime.syncManager;
      if (_runtime.isUnavailable || manager == null) {
        result = SyncProductionCallResult.unavailable(_runtime.disabledMessage);
      } else {
        final readiness = await _liveReadinessGate.check();
        if (readiness.isNotReady) {
          result = SyncProductionCallResult.blocked(readiness.blockedReason);
        } else {
          await _runtime.registerDeviceIfNeeded();
          final pullResult = await manager.pullPending();
          late final SyncPushResult pushResult;
          try {
            pushResult = await manager.pushPending(mode: SyncPushMode.live);
            result = SyncProductionCallResult.completed(
              pullResult: pullResult,
              pushResult: pushResult,
            );
          } on SyncPushBlockedException catch (error) {
            result = SyncProductionCallResult.blocked(error.reason);
          }
        }
      }
    } catch (error) {
      result = SyncProductionCallResult.failed(error.toString());
    } finally {
      _running = false;
    }
    await _recordTelemetry(trigger, result);
    return result;
  }

  Future<void> _recordTelemetry(
    SyncProductionTrigger trigger,
    SyncProductionCallResult result,
  ) async {
    try {
      await _telemetryStore.write(_telemetryFor(trigger, result));
    } catch (_) {
      // Telemetry must not change the sync outcome reported to callers.
    }
  }

  SyncTelemetry _telemetryFor(
    SyncProductionTrigger trigger,
    SyncProductionCallResult result,
  ) {
    final pullResult = result.pullResult;
    final pushResult = result.pushResult;
    return SyncTelemetry(
      trigger: trigger.name,
      status: _telemetryStatus(result.status),
      pullApplied: pullResult?.applied ?? 0,
      pullConflicts: pullResult?.conflicts.length ?? 0,
      pushPushed: pushResult?.pushed ?? 0,
      pushFailed: pushResult?.failed ?? 0,
      reason: result.status == SyncProductionCallStatus.failed
          ? null
          : result.reason,
      error: result.status == SyncProductionCallStatus.failed
          ? result.reason
          : null,
      timestamp: _now().toUtc().toIso8601String(),
    );
  }

  SyncTelemetryStatus _telemetryStatus(SyncProductionCallStatus status) {
    switch (status) {
      case SyncProductionCallStatus.unavailable:
        return SyncTelemetryStatus.unavailable;
      case SyncProductionCallStatus.blocked:
        return SyncTelemetryStatus.blocked;
      case SyncProductionCallStatus.completed:
        return SyncTelemetryStatus.completed;
      case SyncProductionCallStatus.skippedBusy:
        return SyncTelemetryStatus.skippedBusy;
      case SyncProductionCallStatus.failed:
        return SyncTelemetryStatus.failed;
    }
  }
}
