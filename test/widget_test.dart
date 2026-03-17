import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asset_ledger/app/app.dart';
import 'package:asset_ledger/app/router.dart';

void main() {
  testWidgets('机账通 smoke test', (WidgetTester tester) async {
    late MaterialApp app;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            app = const AssetLedgerApp().build(context) as MaterialApp;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(app.title, '机账通');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.home, isA<AppRouterEntry>());
  });
}
