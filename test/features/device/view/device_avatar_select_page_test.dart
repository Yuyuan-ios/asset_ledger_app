import 'package:asset_ledger/features/device/view/device_avatar_select_page.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/layout/bottom_sheet_shell_pattern.dart';
import 'package:asset_ledger/tokens/mapper/bottom_sheet_tokens.dart';
import 'package:asset_ledger/tokens/mapper/color_tokens.dart';
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
