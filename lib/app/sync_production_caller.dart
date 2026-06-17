import '../infrastructure/sync/sync_live_readiness_gate.dart';
import '../infrastructure/sync/sync_manager.dart';
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
  }) : _runtime = runtime,
       _liveReadinessGate = liveReadinessGate;

  final SyncRuntime _runtime;
  final SyncLiveReadinessGate _liveReadinessGate;
  bool _running = false;

  Future<SyncProductionCallResult> runOnce({
    SyncProductionTrigger trigger = SyncProductionTrigger.manual,
  }) async {
    if (_running) {
      return const SyncProductionCallResult.skippedBusy();
    }
    _running = true;
    try {
      final manager = _runtime.syncManager;
      if (_runtime.isUnavailable || manager == null) {
        return SyncProductionCallResult.unavailable(_runtime.disabledMessage);
      }

      final readiness = await _liveReadinessGate.check();
      if (readiness.isNotReady) {
        return SyncProductionCallResult.blocked(readiness.blockedReason);
      }

      await _runtime.registerDeviceIfNeeded();
      final pullResult = await manager.pullPending();
      late final SyncPushResult pushResult;
      try {
        pushResult = await manager.pushPending(mode: SyncPushMode.live);
      } on SyncPushBlockedException catch (error) {
        return SyncProductionCallResult.blocked(error.reason);
      }
      return SyncProductionCallResult.completed(
        pullResult: pullResult,
        pushResult: pushResult,
      );
    } catch (error) {
      return SyncProductionCallResult.failed(error.toString());
    } finally {
      _running = false;
    }
  }
}
