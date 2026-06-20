import 'package:asset_ledger/features/app_update/application/update_delivery.dart';
import 'package:asset_ledger/features/app_update/domain/version_gate_decision.dart';
import 'package:asset_ledger/features/app_update/presentation/forced_update_blocker.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  testWidgets('renders Chinese fallback copy from l10n', (tester) async {
    await _showBlocker(
      tester,
      decision: _forcedFallbackDecision(),
      locale: const Locale('zh'),
    );

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('更新以获得更稳定的体验。'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '立即更新'), findsOneWidget);
  });

  testWidgets('renders English fallback copy from l10n', (tester) async {
    await _showBlocker(
      tester,
      decision: _forcedFallbackDecision(),
      locale: const Locale('en'),
    );

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Update for a more stable experience.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Update now'), findsOneWidget);
    expect(find.text('发现新版本'), findsNothing);
    expect(find.text('立即更新'), findsNothing);
  });

  testWidgets('system back does not dismiss forced blocker', (tester) async {
    await _showBlocker(tester);

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
  });

  testWidgets('update action launches injected delivery and stays on blocker', (
    tester,
  ) async {
    final delivery = _SpyUpdateDelivery();
    await _showBlocker(tester, delivery: delivery);

    await tester.tap(find.widgetWithText(FilledButton, '立即更新'));
    await tester.pump();

    expect(delivery.decisions, [_forcedDecision()]);
    expect(find.text('发现新版本'), findsOneWidget);
  });

  testWidgets('delivery launcher error does not crash forced blocker', (
    tester,
  ) async {
    await _showBlocker(
      tester,
      delivery: UpdateDelivery(
        channel: 'official',
        urlLauncher: (uri) async {
          throw StateError('launcher failed');
        },
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '立即更新'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('发现新版本'), findsOneWidget);
  });
}

Future<void> _showBlocker(
  WidgetTester tester, {
  Locale locale = const Locale('zh'),
  VersionGateDecision? decision,
  UpdateDelivery? delivery,
}) async {
  await tester.pumpWidget(
    _localizedApp(
      locale: locale,
      child: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showForcedUpdateBlocker(
                  context: context,
                  decision: decision ?? _forcedDecision(),
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

VersionGateDecision _forcedDecision() {
  return const VersionGateDecision.forced(
    updateUrl: 'https://example.com/download',
    title: '发现新版本',
    content: '请更新后继续使用。',
  );
}

VersionGateDecision _forcedFallbackDecision() {
  return const VersionGateDecision.forced(
    updateUrl: 'https://example.com/download',
    title: null,
    content: null,
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
