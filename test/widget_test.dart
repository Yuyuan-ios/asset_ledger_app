import 'package:flutter_test/flutter_test.dart';
import 'package:asset_ledger/main.dart';

void main() {
  testWidgets('Asset Ledger smoke test', (WidgetTester tester) async {
    // 只验证：App 能启动、能 pump 一帧，不崩溃
    await tester.pumpWidget(const AssetLedgerApp());
    await tester.pump();
    expect(find.text('计时'), findsWidgets); // 你主页AppBar里有“计时”，用于简单断言
  });
}
