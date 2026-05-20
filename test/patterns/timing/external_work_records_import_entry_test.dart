import 'package:asset_ledger/patterns/timing/external_work_records_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(List<Widget> slivers) => MaterialApp(
  home: Scaffold(body: CustomScrollView(slivers: slivers)),
);

void main() {
  testWidgets('empty state shows .jzt import entry and fires callback', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        buildTimingExternalWorkRecordSlivers(
          items: const [],
          onImportShareFile: () => tapped = true,
        ),
      ),
    );

    expect(find.text('从他人分享的 .jzt 文件导入后，会显示在这里'), findsOneWidget);
    final btn = find.byKey(const Key('timing-external-work-import-share-file'));
    expect(btn, findsOneWidget);
    expect(find.text('导入项目外协包'), findsOneWidget);
    // 主文案使用 .jzt，不暴露 .jztshare 扩展名（regression）
    expect(find.textContaining('.jztshare'), findsNothing);

    await tester.tap(btn);
    expect(tapped, isTrue);
  });

  testWidgets('no import callback keeps existing empty state unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(buildTimingExternalWorkRecordSlivers(items: const [])),
    );

    expect(find.text('暂无项目外协记录'), findsOneWidget);
    expect(
      find.byKey(const Key('timing-external-work-import-share-file')),
      findsNothing,
    );
  });
}
