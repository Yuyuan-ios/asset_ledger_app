import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asset_ledger/app/app.dart';
import 'package:asset_ledger/app/app_navigator.dart';
import 'package:asset_ledger/app/app_runtime_bootstrap.dart';
import 'package:asset_ledger/app/inbound_share_file_gate.dart';
import 'package:asset_ledger/app/phone_login_gate.dart';
import 'package:asset_ledger/app/router.dart';
import 'package:asset_ledger/app/sync_lifecycle_gate.dart';
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
    expect(app.navigatorKey, same(AppNavigator.key));
    expect(app.onGenerateTitle, isNotNull);
    expect(app.localizationsDelegates, contains(AppLocalizations.delegate));
    expect(app.debugShowCheckedModeBanner, isFalse);
    final loginGate = app.home;
    expect(loginGate, isA<PhoneLoginGate>());

    final bootstrap = (loginGate as PhoneLoginGate).child;
    expect(bootstrap, isA<AppRuntimeBootstrap>());

    final syncGate = (bootstrap as AppRuntimeBootstrap).child;
    expect(syncGate, isA<SyncLifecycleGate>());

    final shareGate = (syncGate as SyncLifecycleGate).child;
    expect(shareGate, isA<InboundShareFileGate>());
    expect((shareGate as InboundShareFileGate).child, isA<AppRouterEntry>());
  });
}
