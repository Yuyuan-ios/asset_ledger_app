import 'package:asset_ledger/features/app_update/application/update_prompt_coordinator.dart';
import 'package:asset_ledger/features/app_update/domain/version_gate_decision.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'first timing entry checks as cold start and optional shows once',
    (WidgetTester tester) async {
      final coldStartFlags = <bool>[];
      var showCalls = 0;
      final coordinator = UpdatePromptCoordinator(
        checkVersion: ({required bool isColdStart}) async {
          coldStartFlags.add(isColdStart);
          return _optionalDecision();
        },
        showPrompt: (context, decision) async {
          showCalls++;
        },
      );
      final context = await _pumpContext(tester);

      await coordinator.onTimingPageEntered(context);
      await coordinator.onTimingPageEntered(context);

      expect(coldStartFlags, [true, false]);
      expect(showCalls, 1);
    },
  );

  testWidgets('forced decision does not show prompt', (tester) async {
    var showCalls = 0;
    final coordinator = UpdatePromptCoordinator(
      checkVersion: ({required bool isColdStart}) async {
        return const VersionGateDecision.forced(
          updateUrl: 'https://example.com/download',
          title: '发现新版本',
          content: '请更新',
        );
      },
      showPrompt: (context, decision) async {
        showCalls++;
      },
    );

    await coordinator.onTimingPageEntered(await _pumpContext(tester));

    expect(showCalls, 0);
  });

  testWidgets('none decision does not show prompt', (tester) async {
    var showCalls = 0;
    final coordinator = UpdatePromptCoordinator(
      checkVersion: ({required bool isColdStart}) async {
        return const VersionGateDecision.none();
      },
      showPrompt: (context, decision) async {
        showCalls++;
      },
    );

    await coordinator.onTimingPageEntered(await _pumpContext(tester));

    expect(showCalls, 0);
  });

  testWidgets('service error is fail-open and does not show prompt', (
    tester,
  ) async {
    var showCalls = 0;
    final coordinator = UpdatePromptCoordinator(
      checkVersion: ({required bool isColdStart}) async {
        throw StateError('version check failed');
      },
      showPrompt: (context, decision) async {
        showCalls++;
      },
    );

    await coordinator.onTimingPageEntered(await _pumpContext(tester));

    expect(showCalls, 0);
  });

  testWidgets('no-op coordinator does not show prompt', (tester) async {
    final coordinator = UpdatePromptCoordinator.noop();

    await coordinator.onTimingPageEntered(await _pumpContext(tester));

    expect(tester.takeException(), isNull);
  });
}

VersionGateDecision _optionalDecision() {
  return const VersionGateDecision.optional(
    updateUrl: 'https://example.com/download',
    title: '发现新版本',
    content: '更新以获得更稳定的体验。',
  );
}

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}
