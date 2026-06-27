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

  testWidgets(
    'SectionHeader can hide add action without changing title metrics',
    (tester) async {
      const visibleHeaderKey = Key('visible-section-header');
      const hiddenHeaderKey = Key('hidden-section-header');

      await tester.pumpWidget(
        _hostWithChild(
          const Locale('zh'),
          const Column(
            children: [
              SectionHeader(key: visibleHeaderKey, title: '计时'),
              SectionHeader(
                key: hiddenHeaderKey,
                title: '设备',
                showAddButton: false,
              ),
            ],
          ),
        ),
      );

      expect(find.text('+ 新建'), findsOneWidget);
      expect(find.text('设备'), findsOneWidget);

      final visibleHeaderSize = tester.getSize(find.byKey(visibleHeaderKey));
      final hiddenHeaderSize = tester.getSize(find.byKey(hiddenHeaderKey));
      expect(hiddenHeaderSize.height, visibleHeaderSize.height);

      final visibleHeaderTopLeft = tester.getTopLeft(
        find.byKey(visibleHeaderKey),
      );
      final hiddenHeaderTopLeft = tester.getTopLeft(
        find.byKey(hiddenHeaderKey),
      );
      final visibleTitleTopLeft = tester.getTopLeft(find.text('计时'));
      final hiddenTitleTopLeft = tester.getTopLeft(find.text('设备'));
      expect(
        hiddenTitleTopLeft.dx - hiddenHeaderTopLeft.dx,
        visibleTitleTopLeft.dx - visibleHeaderTopLeft.dx,
      );
      expect(
        hiddenTitleTopLeft.dy - hiddenHeaderTopLeft.dy,
        visibleTitleTopLeft.dy - visibleHeaderTopLeft.dy,
      );

      final visibleTitle = tester.widget<Text>(find.text('计时'));
      final hiddenTitle = tester.widget<Text>(find.text('设备'));
      expect(hiddenTitle.style?.fontSize, visibleTitle.style?.fontSize);
      expect(hiddenTitle.style?.height, visibleTitle.style?.height);
    },
  );
}

Widget _host(Locale locale) {
  return _hostWithChild(locale, const SectionHeader());
}

Widget _hostWithChild(Locale locale, Widget child) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}
