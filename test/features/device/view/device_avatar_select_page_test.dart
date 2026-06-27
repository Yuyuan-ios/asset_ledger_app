import 'package:asset_ledger/features/device/view/device_avatar_select_page.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/layout/bottom_sheet_shell_pattern.dart';
import 'package:asset_ledger/tokens/mapper/bottom_sheet_tokens.dart';
import 'package:asset_ledger/tokens/mapper/color_tokens.dart';
import 'package:asset_ledger/tokens/mapper/timing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'type sheet uses the shared AppBottomSheetShell and drives the CTA',
    (tester) async {
      await tester.pumpWidget(
        _localizedApp(
          home: const DeviceAvatarSelectPage(initialTypeId: 'excavator'),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: excavator selected -> CTA reflects it.
      expect(find.text('下一步：创建挖掘机设备'), findsOneWidget);
      final typeCard = tester.widget<Material>(_deviceTypeCardMaterial());
      final typeCardShape = typeCard.shape as RoundedRectangleBorder;
      expect(typeCardShape.borderRadius, BorderRadius.circular(8));
      expect(
        find.descendant(
          of: find.byType(Scrollable),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );

      final cta = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '下一步：创建挖掘机设备'),
      );
      expect(cta.style?.backgroundColor?.resolve({}), AppColors.brand);
      expect(cta.style?.foregroundColor?.resolve({}), SheetColors.actionOn);
      expect(
        cta.style?.shape?.resolve({}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      );
      expect(
        cta.style?.textStyle?.resolve({})?.fontSize,
        BottomSheetTokens.actionTextSize,
      );
      expect(cta.style?.textStyle?.resolve({})?.fontWeight, FontWeight.w400);

      // Tap the type card (its chevron) to open the type sheet.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      // The sheet reuses the app-wide bottom-sheet shell.
      expect(find.byType(AppBottomSheetShell), findsOneWidget);
      expect(find.text('选择设备类型'), findsOneWidget);

      // Pick 压路机 (a Phase 2 creatable type).
      await tester.tap(find.text('压路机'));
      await tester.pumpAndSettle();

      // Sheet closed, card + CTA now reflect roller.
      expect(find.byType(AppBottomSheetShell), findsNothing);
      expect(find.text('下一步：创建压路机设备'), findsOneWidget);
    },
  );

  testWidgets('brand search header pins while the type card scrolls away', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        home: const DeviceAvatarSelectPage(initialTypeId: 'excavator'),
      ),
    );
    await tester.pumpAndSettle();

    final typeCard = find.byKey(const Key('device-avatar-type-card-container'));
    final searchHeader = find.byKey(const Key('device-brand-search-header'));
    final scrollView = find.byKey(
      const PageStorageKey<String>('device-avatar-brand-scroll'),
    );
    final initialSearchTop = tester.getTopLeft(searchHeader).dy;

    expect(initialSearchTop, greaterThan(tester.getTopLeft(typeCard).dy));

    await tester.drag(scrollView, const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(searchHeader, findsOneWidget);
    final pinnedSearchTop = tester.getTopLeft(searchHeader).dy;
    expect(pinnedSearchTop, lessThan(initialSearchTop));
    expect(pinnedSearchTop, moreOrLessEquals(kToolbarHeight, epsilon: 8));
  });

  testWidgets('empty brand search creates a custom brand from the query', (
    tester,
  ) async {
    AvatarSelectionResult? result;
    await tester.pumpWidget(
      _localizedApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await Navigator.of(context)
                    .push<AvatarSelectionResult>(
                      MaterialPageRoute(
                        builder: (_) => const DeviceAvatarSelectPage(
                          initialTypeId: 'excavator',
                        ),
                      ),
                    );
              },
              child: const Text('打开选择页'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开选择页'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'b');
    await tester.pumpAndSettle();
    final searchFieldElement = tester.element(find.byType(TextField));

    await tester.enterText(find.byType(TextField), 'zzzxcustom');
    await tester.pumpAndSettle();
    expect(
      identical(searchFieldElement, tester.element(find.byType(TextField))),
      isTrue,
    );

    const emptyHintText = '未找到相关品牌，可直接点击下方‘下一步：创建挖掘机设备’按钮，直接创建自定义品牌';
    expect(find.text(emptyHintText), findsOneWidget);
    expect(find.text('使用自定义品牌'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);

    final emptyHint = tester.widget<Text>(find.text(emptyHintText));
    expect(emptyHint.style?.fontSize, TimingTokens.emptyStateTitleFontSize);
    expect(emptyHint.style?.color, TimingColors.textSecondary);

    await tester.tap(find.widgetWithText(FilledButton, '下一步：创建挖掘机设备'));
    await tester.pumpAndSettle();

    expect(result?.brandValue, 'zzzxcustom');
    expect(result?.equipmentType.name, 'excavator');
    expect(result?.deviceTypeId, 'excavator');
  });
}

Finder _deviceTypeCardMaterial() {
  return find.byWidgetPredicate((widget) {
    final shape = widget is Material ? widget.shape : null;
    return shape is RoundedRectangleBorder &&
        shape.side == const BorderSide(color: AppColors.divider);
  }).first;
}

Widget _localizedApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
