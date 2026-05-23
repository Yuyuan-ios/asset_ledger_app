import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asset_ledger/app/app.dart';
import 'package:asset_ledger/app/inbound_share_file_gate.dart';
import 'package:asset_ledger/app/router.dart';

void main() {
  testWidgets('FleetLedger smoke test', (WidgetTester tester) async {
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

    expect(app.title, 'FleetLedger');
    expect(app.debugShowCheckedModeBanner, isFalse);
    final gate = app.home;
    expect(gate, isA<InboundShareFileGate>());
    expect((gate as InboundShareFileGate).child, isA<AppRouterEntry>());
  });
}
