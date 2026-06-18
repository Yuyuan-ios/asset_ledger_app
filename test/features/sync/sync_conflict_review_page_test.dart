import 'package:asset_ledger/features/sync/sync_conflict_review_controller.dart';
import 'package:asset_ledger/features/sync/sync_conflict_review_page.dart';
import 'package:asset_ledger/infrastructure/sync/sync_conflict_repository.dart';
import 'package:asset_ledger/infrastructure/sync/sync_conflict_resolution_use_case.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  testWidgets('renders pending conflicts in Chinese', (tester) async {
    final controller = _controller();

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: SyncConflictReviewPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('同步冲突复核'), findsOneWidget);
    expect(find.text('计时记录 101'), findsOneWidget);
    expect(find.text('本地当前'), findsOneWidget);
    expect(find.text('远端来袭'), findsOneWidget);
    expect(find.text('设备 1 · 2026-06-01 · 1 h · ¥100.00'), findsOneWidget);
    expect(find.text('设备 1 · 2026-06-01 · 2 h · ¥300.00'), findsOneWidget);
    expect(find.text('用本地'), findsOneWidget);
    expect(find.text('用远端'), findsOneWidget);
  });

  testWidgets('renders pending conflicts in English', (tester) async {
    final controller = _controller();

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        child: SyncConflictReviewPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sync conflict review'), findsOneWidget);
    expect(find.text('Timing record 101'), findsOneWidget);
    expect(find.text('Local current'), findsOneWidget);
    expect(find.text('Remote incoming'), findsOneWidget);
    expect(find.text('Use local'), findsOneWidget);
    expect(find.text('Use remote'), findsOneWidget);
    expect(find.text('同步冲突复核'), findsNothing);
  });

  testWidgets('removes a conflict after choosing remote', (tester) async {
    final resolver = _FakeResolver();
    final controller = _controller(resolver: resolver);

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        child: SyncConflictReviewPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use remote'));
    await tester.pumpAndSettle();

    expect(resolver.remoteResolved, ['timing_record:101:4']);
    expect(find.text('Timing record 101'), findsNothing);
    expect(find.text('No conflicts to review'), findsOneWidget);
  });
}

SyncConflictReviewController _controller({_FakeResolver? resolver}) {
  return SyncConflictReviewController(
    conflictRepository: _FakeConflictRepository([_conflict()]),
    summaryReader: const _FakeSummaryReader(),
    conflictResolver: resolver ?? _FakeResolver(),
  );
}

Widget _localizedApp({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

SyncConflict _conflict() {
  return const SyncConflict(
    id: 'timing_record:101:4',
    entityType: 'timing_record',
    entityId: '101',
    remoteServerSeq: 4,
    remoteBaseVersion: 1,
    remoteNewVersion: 2,
    remotePayloadJson: '{"record":{"id":101}}',
    remotePayloadHash: 'remote-hash',
    remoteDeleted: false,
    conflictReason: 'remote_newer_local_dirty',
    detectedAt: '2026-06-16T09:00:00.000Z',
    status: SyncConflictStatus.pending,
  );
}

class _FakeConflictRepository implements SyncConflictRepository {
  _FakeConflictRepository(this.conflicts);

  final List<SyncConflict> conflicts;

  @override
  Future<bool> insertIfAbsent(SyncConflict conflict) async => false;

  @override
  Future<bool> insertIfAbsentWithExecutor(
    DatabaseExecutor executor,
    SyncConflict conflict,
  ) async => false;

  @override
  Future<List<SyncConflict>> listPending({int limit = 50}) async => conflicts;

  @override
  Future<int?> earliestPendingServerSeq() async {
    if (conflicts.isEmpty) return null;
    return conflicts
        .map((conflict) => conflict.remoteServerSeq)
        .reduce((a, b) => a < b ? a : b);
  }

  @override
  Future<int> markResolved({
    required String id,
    required SyncConflictResolution resolution,
    DateTime? now,
  }) async => 0;

  @override
  Future<int> markResolvedWithExecutor(
    DatabaseExecutor executor, {
    required String id,
    required SyncConflictResolution resolution,
    DateTime? now,
  }) async => 0;
}

class _FakeSummaryReader implements TimingConflictSummaryReader {
  const _FakeSummaryReader();

  @override
  Future<TimingConflictSummary?> localSummary(SyncConflict conflict) async {
    return const TimingConflictSummary(
      deviceId: 1,
      startDate: 20260601,
      hours: 1,
      incomeFen: 10000,
    );
  }

  @override
  TimingConflictSummary remoteSummary(SyncConflict conflict) {
    return const TimingConflictSummary(
      deviceId: 1,
      startDate: 20260601,
      hours: 2,
      incomeFen: 30000,
    );
  }
}

class _FakeResolver implements SyncConflictResolver {
  final remoteResolved = <String>[];
  final localResolved = <String>[];

  @override
  Future<void> useRemote(SyncConflict conflict) async {
    remoteResolved.add(conflict.id);
  }

  @override
  Future<void> useLocal(SyncConflict conflict) async {
    localResolved.add(conflict.id);
  }
}
