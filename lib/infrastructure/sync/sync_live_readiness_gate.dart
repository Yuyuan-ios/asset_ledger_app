/// R5.27-B: live cloud push is guarded until the local sync stack and the real
/// cloud transport are both ready. Dry-run preview does not use this gate.
abstract class SyncLiveReadinessGate {
  Future<SyncCloudReadinessResult> check();
}

class DefaultSyncLiveReadinessGate implements SyncLiveReadinessGate {
  const DefaultSyncLiveReadinessGate();

  static const List<String> completedPrerequisites = [
    'restore-push-gate-ready',
    'owner-actor-persistence-ready',
    'noop-cloud-client-dry-run-fallback-hardened',
    'transaction-group-local-sequence-ready',
    'push-ordering-ack-retry-ready',
    'pending-outbox-folding-ready',
    'payload-schema-version-actor-traceability-ready',
    'project-lifecycle-outbox-ready',
    'dry-run-push-preview-ready',
    // Track A（money-fen 收口 A1-A3）：全 App 金额已是「fen 唯一读权威 +
    // NOT NULL + 双写」=实质 primary storage（REAL 仅余冗余影子，无人当权威读）。
    // 故 money-fen-primary-storage 自硬阻断退休、转入已完成前置。物理删 REAL
    // 列（原 A4）降级为日后经类生产备份验证的独立清理，与 live 同步就绪无关。
    'money-fen-primary-storage-ready',
  ];

  static const List<String> hardBlockers = [
    'real-cloud-transport-not-configured',
  ];

  static const List<String> warnings = [
    'delete-meta-lifecycle-deferred',
    'terminal-failed-admin-reset-deferred',
    'persistent-telemetry-deferred',
  ];

  @override
  Future<SyncCloudReadinessResult> check() async {
    return const SyncCloudReadinessResult(
      completedPrerequisites: completedPrerequisites,
      hardBlockers: hardBlockers,
      warnings: warnings,
    );
  }
}

class StaticSyncLiveReadinessGate implements SyncLiveReadinessGate {
  const StaticSyncLiveReadinessGate(this.result);

  const StaticSyncLiveReadinessGate.readyForTest()
    : result = const SyncCloudReadinessResult(
        completedPrerequisites: ['test-live-readiness-ready'],
      );

  StaticSyncLiveReadinessGate.blockedForTest({
    List<String> hardBlockers = const ['test-live-readiness-blocked'],
    List<String> warnings = const [],
  }) : result = SyncCloudReadinessResult(
         completedPrerequisites: ['test-live-readiness-fixture'],
         hardBlockers: hardBlockers,
         warnings: warnings,
       );

  final SyncCloudReadinessResult result;

  @override
  Future<SyncCloudReadinessResult> check() async => result;
}

class SyncCloudReadinessResult {
  const SyncCloudReadinessResult({
    required this.completedPrerequisites,
    this.hardBlockers = const [],
    this.warnings = const [],
  });

  final List<String> completedPrerequisites;
  final List<String> hardBlockers;
  final List<String> warnings;

  bool get isReady => hardBlockers.isEmpty;

  bool get isNotReady => !isReady;

  List<String> get missingPrerequisites => hardBlockers;

  String get blockedReason {
    if (isReady) return 'cloud-live-readiness-ready';
    final buffer = StringBuffer(
      'cloud-live-readiness-blocked: missing prerequisites: '
      '${hardBlockers.join(', ')}',
    );
    if (warnings.isNotEmpty) {
      buffer.write('; warnings: ${warnings.join(', ')}');
    }
    return buffer.toString();
  }
}
