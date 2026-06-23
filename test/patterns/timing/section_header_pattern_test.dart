import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/timing/section_header_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SectionHeader keeps Chinese timing defaults', (tester) async {
    await tester.pumpWidget(_host(const Locale('zh')));

    expect(find.text('计时'), findsOneWidget);
    expect(find.text('+ 新建'), findsOneWidget);
  });

  testWidgets('SectionHeader localizes default copy in English', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const Locale('en')));

    expect(find.text('Timing'), findsOneWidget);
    expect(find.text('+ New'), findsOneWidget);
  });
}

Widget _host(Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: SectionHeader()),
  );
}
