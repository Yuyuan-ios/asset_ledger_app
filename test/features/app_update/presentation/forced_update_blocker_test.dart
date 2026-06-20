import 'package:asset_ledger/features/app_update/domain/version_gate_decision.dart';
import 'package:asset_ledger/features/app_update/presentation/forced_update_blocker.dart';
import 'package:asset_ledger/features/app_update/presentation/optional_update_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders title content and only update action', (tester) async {
    await _showBlocker(tester);

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('请更新后继续使用。'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '立即更新'), findsOneWidget);
    expect(find.text('稍后再说'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('system back does not dismiss forced blocker', (tester) async {
    await _showBlocker(tester);

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
  });

  testWidgets('update action launches injected URL and stays on blocker', (
    tester,
  ) async {
    final launched = <Uri>[];
    await _showBlocker(
      tester,
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await tester.tap(find.widgetWithText(FilledButton, '立即更新'));
    await tester.pump();

    expect(launched, [Uri.parse('https://example.com/download')]);
    expect(find.text('发现新版本'), findsOneWidget);
  });

  testWidgets('launcher error does not crash forced blocker', (tester) async {
    await _showBlocker(
      tester,
      launcher: (uri) async {
        throw StateError('launcher failed');
      },
    );

    await tester.tap(find.widgetWithText(FilledButton, '立即更新'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('发现新版本'), findsOneWidget);
  });
}

Future<void> _showBlocker(
  WidgetTester tester, {
  UpdateUrlLauncher? launcher,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showForcedUpdateBlocker(
                  context: context,
                  decision: _forcedDecision(),
                  launcher: launcher ?? (_) async => true,
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

VersionGateDecision _forcedDecision() {
  return const VersionGateDecision.forced(
    updateUrl: 'https://example.com/download',
    title: '发现新版本',
    content: '请更新后继续使用。',
  );
}
