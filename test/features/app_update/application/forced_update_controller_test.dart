import 'package:asset_ledger/features/app_update/application/forced_update_controller.dart';
import 'package:asset_ledger/features/app_update/domain/version_gate_decision.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signals forced blocker once through navigator context', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shown = <VersionGateDecision>[];
    final controller = ForcedUpdateController(
      navigatorKey: navigatorKey,
      showForcedBlocker: (context, decision) async {
        expect(context.mounted, isTrue);
        shown.add(decision);
      },
    );

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );

    controller.signalUpgradeRequired(_forcedDecision('first'));
    controller.signalUpgradeRequired(_forcedDecision('second'));
    await tester.pump();

    expect(shown, hasLength(1));
    expect(shown.single.content, 'first');
  });

  testWidgets('stores pending decision when navigator context is unavailable', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shown = <VersionGateDecision>[];
    final controller = ForcedUpdateController(
      navigatorKey: navigatorKey,
      showForcedBlocker: (context, decision) async {
        shown.add(decision);
      },
    );

    controller.signalUpgradeRequired(_forcedDecision('pending'));
    expect(shown, isEmpty);

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );
    controller.signalUpgradeRequired(_forcedDecision('new'));
    await tester.pump();

    expect(shown, hasLength(1));
    expect(shown.single.content, 'pending');
  });
}

VersionGateDecision _forcedDecision(String content) {
  return VersionGateDecision.forced(
    updateUrl: 'https://example.com/download',
    title: '发现新版本',
    content: content,
  );
}
