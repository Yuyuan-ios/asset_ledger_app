import 'package:asset_ledger/features/app_update/application/update_delivery.dart';
import 'package:asset_ledger/features/app_update/domain/version_gate_decision.dart';
import 'package:asset_ledger/features/app_update/presentation/optional_update_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders title, content, and action buttons', (tester) async {
    await _showPrompt(tester);

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('更新以获得更稳定的体验。'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('稍后再说'), findsOneWidget);
  });

  testWidgets('later action closes the optional prompt', (tester) async {
    await _showPrompt(tester);

    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsNothing);
  });

  testWidgets('update action launches injected delivery and closes prompt', (
    tester,
  ) async {
    final delivery = _SpyUpdateDelivery();
    await _showPrompt(tester, delivery: delivery);

    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(delivery.decisions, [_optionalDecision()]);
    expect(find.text('发现新版本'), findsNothing);
  });
}

Future<void> _showPrompt(
  WidgetTester tester, {
  UpdateDelivery? delivery,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showOptionalUpdatePrompt(
                  context: context,
                  decision: _optionalDecision(),
                  delivery: delivery ?? _SpyUpdateDelivery(),
                );
              },
              child: const Text('show'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('show'));
  await tester.pumpAndSettle();
}

VersionGateDecision _optionalDecision() {
  return const VersionGateDecision.optional(
    updateUrl: 'https://example.com/download',
    title: '发现新版本',
    content: '更新以获得更稳定的体验。',
  );
}

class _SpyUpdateDelivery implements UpdateDelivery {
  final decisions = <VersionGateDecision>[];

  @override
  UpdateChannelEnvironment get environment =>
      UpdateChannelEnvironment.directStore;

  @override
  Future<void> launch(VersionGateDecision decision) async {
    decisions.add(decision);
  }
}
