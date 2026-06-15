import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/timing/tab_bar_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// i18n 切片:底部导航文案走 AppLocalizations(不再硬编码)。
Widget _host(Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh'), Locale('en')],
    home: Scaffold(
      body: ComponentTabBar(currentIndex: 0, onTap: (_) {}),
    ),
  );
}

void main() {
  testWidgets('renders localized zh nav labels (含 §10.4 油电)', (tester) async {
    await tester.pumpWidget(_host(const Locale('zh')));
    await tester.pumpAndSettle();

    expect(find.text('计时'), findsOneWidget);
    expect(find.text('油电'), findsOneWidget);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('维保'), findsOneWidget);
    expect(find.text('设备'), findsOneWidget);
  });

  testWidgets('renders localized en nav labels', (tester) async {
    await tester.pumpWidget(_host(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Timing'), findsOneWidget);
    expect(find.text('Energy'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Service'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
  });
}
