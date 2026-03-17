import 'package:asset_ledger/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppRouterEntry lazily builds tabs and warms deferred stores after first frame', (
    WidgetTester tester,
  ) async {
    final buildCounts = List<int>.filled(5, 0);
    var warmupCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
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

    await tester.tap(find.bySemanticsLabel('账户'));
    await tester.pump();

    expect(buildCounts, [1, 0, 1, 0, 0]);
    expect(find.text('page-2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('设备'));
    await tester.pump();

    expect(buildCounts, [1, 0, 1, 0, 1]);
    expect(find.text('page-4'), findsOneWidget);
  });
}
