import 'package:asset_ledger/app/sync_lifecycle_gate.dart';
import 'package:asset_ledger/app/sync_production_caller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpGate(
  WidgetTester tester, {
  required List<SyncProductionTrigger> triggers,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SyncLifecycleGate(
        onRun: (trigger) async {
          triggers.add(trigger);
          return const SyncProductionCallResult.unavailable('test');
        },
        child: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('runs once after first frame', (tester) async {
    final triggers = <SyncProductionTrigger>[];

    await _pumpGate(tester, triggers: triggers);

    expect(triggers, [SyncProductionTrigger.appStart]);
  });

  testWidgets('runs when app resumes', (tester) async {
    final triggers = <SyncProductionTrigger>[];

    await _pumpGate(tester, triggers: triggers);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(triggers, [
      SyncProductionTrigger.appStart,
      SyncProductionTrigger.foregroundResume,
    ]);
  });
}
