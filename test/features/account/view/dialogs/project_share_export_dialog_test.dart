import 'package:asset_ledger/features/account/view/dialogs/project_share_export_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('project detail share button uses curved arrow style', (
    tester,
  ) async {
    var shared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectDetailShareButton(onPressed: () => shared = true),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.reply_rounded));
    expect(icon.size, 32);

    await tester.tap(find.byKey(const Key('project-detail-share-button')));
    expect(shared, isTrue);
  });

  testWidgets('project detail Excel export button calls callback', (
    tester,
  ) async {
    var exported = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectDetailExcelExportButton(
            onPressed: () => exported = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('project-detail-excel-export-button')),
    );
    expect(exported, isTrue);
  });

  testWidgets('name dialog blocks empty and returns trimmed value', (
    tester,
  ) async {
    String? captured = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                captured = await showProjectShareNameDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('分享项目'), findsOneWidget);

    // 空输入：点“生成分享包”不关闭，显示错误
    await tester.tap(find.text('生成分享包'));
    await tester.pump();
    expect(find.text('请输入分享人姓名或包名'), findsOneWidget);
    expect(find.text('分享项目'), findsOneWidget); // 仍开着

    await tester.enterText(find.byType(TextField), '  老王外协  ');
    await tester.tap(find.text('生成分享包'));
    await tester.pumpAndSettle();
    expect(captured, '老王外协'); // trim 后返回

    // 再开一次测试取消
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(captured, isNull);
  });
}
