import 'package:asset_ledger/features/device/view/device_avatar_select_page.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/layout/bottom_sheet_shell_pattern.dart';
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
