import 'package:asset_ledger/features/app_update/application/update_delivery.dart';
import 'package:asset_ledger/features/app_update/domain/version_gate_decision.dart';
import 'package:asset_ledger/features/app_update/presentation/optional_update_prompt.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders title, content, and action buttons', (tester) async {
    await _showPrompt(tester);

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('更新以获得更稳定的体验。'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('稍后再说'), findsOneWidget);
  });

  testWidgets('renders Chinese fallback copy from l10n', (tester) async {
    await _showPrompt(
      tester,
      decision: _optionalFallbackDecision(),
      locale: const Locale('zh'),
    );

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('更新以获得更稳定的体验。'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('稍后再说'), findsOneWidget);
  });

  testWidgets('renders English fallback copy from l10n', (tester) async {
    await _showPrompt(
      tester,
      decision: _optionalFallbackDecision(),
      locale: const Locale('en'),
    );

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Update for a more stable experience.'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('发现新版本'), findsNothing);
    expect(find.text('立即更新'), findsNothing);
    expect(find.text('稍后再说'), findsNothing);
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
                showOptionalUpdatePrompt(
                  context: context,
                  decision: decision ?? _optionalDecision(),
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

VersionGateDecision _optionalDecision() {
  return const VersionGateDecision.optional(
    updateUrl: 'https://example.com/download',
    title: '发现新版本',
    content: '更新以获得更稳定的体验。',
  );
}

VersionGateDecision _optionalFallbackDecision() {
  return const VersionGateDecision.optional(
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
