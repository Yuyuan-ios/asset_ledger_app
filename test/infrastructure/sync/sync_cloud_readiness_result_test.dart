import 'package:asset_ledger/infrastructure/sync/sync_live_readiness_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sync_cloud_readiness_result', () {
    test(
      'default live readiness is blocked only by the cloud transport blocker '
      'after Track A retires the money-fen blocker',
      () async {
        final result = await const DefaultSyncLiveReadinessGate().check();

        // 仍未 ready：未配置 URL 时，唯一硬阻断是真实云传输未配置。
        expect(result.isReady, isFalse);
        expect(result.isNotReady, isTrue);
        expect(
          result.missingPrerequisites,
          contains('real-cloud-transport-not-configured'),
        );
        // Track A 退休后，money-fen 不再是硬阻断。
        expect(
          result.missingPrerequisites,
          isNot(contains('money-fen-primary-storage-not-ready')),
        );
        expect(
          result.completedPrerequisites,
          containsAll(<String>[
            'restore-push-gate-ready',
            'owner-actor-persistence-ready',
            'noop-cloud-client-dry-run-fallback-hardened',
            'transaction-group-local-sequence-ready',
            'push-ordering-ack-retry-ready',
            'pending-outbox-folding-ready',
            'payload-schema-version-actor-traceability-ready',
            'project-lifecycle-outbox-ready',
            'dry-run-push-preview-ready',
            // Track A：fen 成 primary storage 后转入已完成前置。
            'money-fen-primary-storage-ready',
          ]),
        );
        expect(
          result.warnings,
          containsAll(<String>[
            'delete-meta-lifecycle-deferred',
            'terminal-failed-admin-reset-deferred',
          ]),
        );
        expect(
          result.warnings,
          isNot(contains('persistent-telemetry-deferred')),
        );
        expect(
          result.missingPrerequisites,
          isNot(contains('delete-meta-lifecycle-deferred')),
        );
        expect(result.blockedReason, contains('missing prerequisites'));
        expect(
          result.blockedReason,
          isNot(contains('money-fen-primary-storage-not-ready')),
        );
        expect(
          result.blockedReason,
          contains('real-cloud-transport-not-configured'),
        );
      },
    );

    test(
      'configured transport retires the real cloud transport hard blocker',
      () async {
        final result = await const DefaultSyncLiveReadinessGate(
          transportConfigured: true,
        ).check();

        expect(result.isReady, isTrue);
        expect(result.isNotReady, isFalse);
        expect(result.hardBlockers, isEmpty);
        expect(result.missingPrerequisites, isEmpty);
        expect(
          result.completedPrerequisites,
          contains('real-cloud-transport-ready'),
        );
        expect(result.blockedReason, 'cloud-live-readiness-ready');
      },
    );

    test(
      'test-ready gate reports ready without missing prerequisites',
      () async {
        final result = await const StaticSyncLiveReadinessGate.readyForTest()
            .check();

        expect(result.isReady, isTrue);
        expect(result.isNotReady, isFalse);
        expect(result.missingPrerequisites, isEmpty);
        expect(result.hardBlockers, isEmpty);
        expect(
          result.completedPrerequisites,
          contains('test-live-readiness-ready'),
        );
        expect(result.blockedReason, 'cloud-live-readiness-ready');
      },
    );

    test(
      'blocking fixture keeps hard blockers separate from warnings',
      () async {
        final result = await StaticSyncLiveReadinessGate.blockedForTest(
          hardBlockers: ['fixture-hard-blocker'],
          warnings: ['fixture-warning'],
        ).check();

        expect(result.isReady, isFalse);
        expect(result.missingPrerequisites, <String>['fixture-hard-blocker']);
        expect(result.warnings, <String>['fixture-warning']);
        expect(result.blockedReason, contains('fixture-hard-blocker'));
        expect(result.blockedReason, contains('fixture-warning'));
      },
    );
  });
}
