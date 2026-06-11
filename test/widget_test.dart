import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asset_ledger/app/app.dart';
import 'package:asset_ledger/app/inbound_share_file_gate.dart';
import 'package:asset_ledger/app/phone_login_gate.dart';
import 'package:asset_ledger/app/router.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('Fleet Ledger smoke test', (WidgetTester tester) async {
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

    // i18n 阶段 A:标题经 onGenerateTitle 走 AppLocalizations key。
    expect(app.onGenerateTitle, isNotNull);
    expect(
      app.localizationsDelegates,
      contains(AppLocalizations.delegate),
    );
    expect(app.debugShowCheckedModeBanner, isFalse);
    final loginGate = app.home;
    expect(loginGate, isA<PhoneLoginGate>());

    final shareGate = (loginGate as PhoneLoginGate).child;
    expect(shareGate, isA<InboundShareFileGate>());
    expect((shareGate as InboundShareFileGate).child, isA<AppRouterEntry>());
  });
}
