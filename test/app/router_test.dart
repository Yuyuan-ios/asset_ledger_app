import 'package:asset_ledger/app/router.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'AppRouterEntry lazily builds tabs and warms deferred stores after first frame',
    (WidgetTester tester) async {
      final buildCounts = List<int>.filled(5, 0);
      var warmupCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          // 镜像生产 app.dart 的本地化装配:底部导航文案走 AppLocalizations。
          // 固定 zh,使既有断言(find.text('账户'))稳定。
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          home: AppRouterEntry(
            pageBuilders: List.generate(
              5,
              (index) => () {
                buildCounts[index]++;
                return Text('page-$index', textDirection: TextDirection.ltr);
              },
            ),
            deferredWarmup: (_) async {
              warmupCalls++;
            },
          ),
        ),
      );

      expect(buildCounts, [1, 0, 0, 0, 0]);
      expect(warmupCalls, 1);
      expect(find.text('page-0'), findsOneWidget);
      expect(find.text('page-2'), findsNothing);

      await tester.tap(find.text('账户'));
      await tester.pump();

      expect(buildCounts, [1, 0, 1, 0, 0]);
      expect(find.text('page-2'), findsOneWidget);

      await tester.tap(find.text('设备'));
      await tester.pump();

      expect(buildCounts, [1, 0, 1, 0, 1]);
      expect(find.text('page-4'), findsOneWidget);
    },
  );
}
