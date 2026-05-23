import 'package:asset_ledger/patterns/timing/external_work_records_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(List<Widget> slivers) => MaterialApp(
  home: Scaffold(body: CustomScrollView(slivers: slivers)),
);

void main() {
  testWidgets('empty state keeps import entry out of the content area', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        buildTimingExternalWorkRecordSlivers(
          items: const [],
          expandedAggregateKeys: const {},
          onToggleAggregate: (_) {},
        ),
      ),
    );

    expect(find.text('从他人分享的 .jzt 文件导入后，会显示在这里'), findsOneWidget);
    expect(find.text('导入项目外协包'), findsNothing);
    // 主文案使用 .jzt，不暴露 .jztshare 扩展名（regression）
    expect(find.textContaining('.jztshare'), findsNothing);
  });
}
