import 'package:asset_ledger/components/feedback/app_toast.dart';
import 'package:asset_ledger/patterns/layout/bottom_sheet_shell_pattern.dart';
import 'package:asset_ledger/tokens/mapper/bottom_sheet_tokens.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showAppBottomSheet hosts toast on the local sheet scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: const ValueKey('root-scaffold'),
          body: Builder(
            builder: (pageContext) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    showAppBottomSheet<void>(
                      context: pageContext,
                      builder: (sheetContext) {
                        return AppBottomSheetShell(
                          title: '测试弹层',
                          scrollable: false,
                          footerEnabled: false,
                          child: Center(
                            child: FilledButton(
                              onPressed: () {
                                AppToast.show(sheetContext, '弹层提示');
                              },
                              child: const Text('显示提示'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('打开弹层'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开弹层'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('显示提示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('弹层提示'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('app-bottom-sheet-feedback-host')),
        matching: find.byType(SnackBar),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('root-scaffold')),
        matching: find.byType(SnackBar),
      ),
      findsNothing,
    );
  });

  testWidgets('openEditorSheet defaults to the shared shell background', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (pageContext) {
              return FilledButton(
                onPressed: () {
                  openEditorSheet<void>(
                    context: pageContext,
                    title: '新建计时',
                    onConfirm: () {},
                    childBuilder: (_) => const SizedBox.shrink(),
                  );
                },
                child: const Text('打开弹层'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开弹层'));
    await tester.pumpAndSettle();

    expect(find.text('新建计时'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) {
        return widget is Material &&
            widget.color == SheetColors.shellBackground &&
            widget.borderRadius != null;
      }),
      findsOneWidget,
    );
  });

  testWidgets('keyboard gap below the action row keeps the sheet background', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844)
      ..viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize()
        ..resetViewInsets();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (pageContext) {
              return FilledButton(
                onPressed: () {
                  openEditorSheet<void>(
                    context: pageContext,
                    title: '新建计时',
                    onConfirm: () {},
                    childBuilder: (_) => const SizedBox.shrink(),
                  );
                },
                child: const Text('打开弹层'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开弹层'));
    await tester.pumpAndSettle();

    final gap = find.byKey(
      const ValueKey('app-bottom-sheet-keyboard-gap-fill'),
    );
    expect(gap, findsOneWidget);
    expect(
      tester.getSize(gap).height,
      260 - BottomSheetTokens.keyboardTopOverlap,
    );

    final fill = tester.widget<ColoredBox>(
      find.ancestor(of: gap, matching: find.byType(ColoredBox)).first,
    );
    expect(fill.color, SheetColors.shellBackground);
  });
}
