import 'package:asset_ledger/core/measure/measure_unit.dart';
import 'package:asset_ledger/features/device/domain/services/device_business_ledger.dart';
import 'package:asset_ledger/features/device/domain/services/lifecycle_payback_calculator.dart';
import 'package:asset_ledger/features/device/view/device_business_ledger_section.dart';
import 'package:asset_ledger/features/device/view/device_editor_dialog.dart';
import 'package:asset_ledger/features/device/view/device_page_content.dart';
import 'package:asset_ledger/features/device/view/privacy_page.dart';
import 'package:asset_ledger/features/device/view/terms_page.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/components/fields/sheet_field_popup_controls.dart';
import 'package:asset_ledger/patterns/device/device_page_header_search_pattern.dart';
import 'package:asset_ledger/patterns/device/device_picker_pattern.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders device page display strings in Chinese', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: Column(
          children: [
            const DevicePageHeaderSearch(),
            DevicePickerPattern(
              vm: DevicePickerVm(
                selectedId: null,
                items: const [],
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ),
    );

    final uiCopy = _collectUiCopy(tester);
    expect(uiCopy, contains('设备'));
    expect(uiCopy, contains('搜索'));
    expect(uiCopy, contains('设备编号'));
    expect(uiCopy, contains('暂无在用设备，请先去“设备”页新增'));
    expect(uiCopy, isNot(contains('+ 新建')));
  });

  testWidgets('renders device page and ledger strings in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        child: Column(
          children: [
            const DevicePageHeaderSearch(),
            DevicePickerPattern(
              vm: DevicePickerVm(
                selectedId: null,
                items: const [],
                onChanged: (_) {},
              ),
            ),
            DeviceBusinessLedgerSection(
              ledgers: [_ledger()],
              amountsFor: (_) => _lifecycleAmounts(),
            ),
          ],
        ),
      ),
    );

    final uiCopy = _collectUiCopy(tester);
    expect(uiCopy, contains('Devices'));
    expect(uiCopy, contains('Search'));
    expect(uiCopy, contains('Device ID'));
    expect(
      uiCopy,
      contains('No active devices. Add one on the Devices page first.'),
    );
    expect(uiCopy, contains('Device operations'));
    expect(uiCopy, contains('SANY 1#'));
    expect(uiCopy, contains('Initial investment ¥2,500'));
    expect(uiCopy, contains('Pending ¥450'));
    expect(uiCopy, contains('Received principal'));
    expect(uiCopy, contains('Estimated resale residual'));
    expect(uiCopy, contains('Payback gap'));
    expect(uiCopy, isNot(contains('+ New')));
    expect(uiCopy, isNot(contains('Surplus')));
    expect(uiCopy, isNot(contains('Income ¥1550 · 2.5h, 3trips')));
    expect(uiCopy, isNot(contains('1 project · Pending ¥450')));
    expect(uiCopy, isNot(contains('设备经营')));
  });

  testWidgets('device picker reuses sheet popup arrows and white menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: DevicePickerPattern(
          vm: DevicePickerVm(
            selectedId: 1,
            items: const [
              DevicePickerItemVm(id: 1, label: 'HITACHI 1#'),
              DevicePickerItemVm(id: 2, label: 'SANY 1#'),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final menu = tester.widget<DropdownMenu<int>>(
      find.byWidgetPredicate((widget) => widget is DropdownMenu<int>),
    );

    expect(menu.trailingIcon, isA<SheetFieldPopupToggleIcon>());
    expect(menu.selectedTrailingIcon, isA<SheetFieldPopupToggleIcon>());
    expect(
      menu.menuStyle?.backgroundColor?.resolve({}),
      SheetColors.background,
    );

    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    expect(find.text('SANY 1#'), findsOneWidget);
  });

  testWidgets('device business section opens lifecycle payback card', (
    tester,
  ) async {
    int? openedDeviceId;
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: DeviceBusinessLedgerSection(
          ledgers: [_ledger()],
          amountsFor: (_) => _lifecycleAmounts(),
          onOpenLifecyclePayback: (ledger) => openedDeviceId = ledger.deviceId,
        ),
      ),
    );

    final uiCopy = _collectUiCopy(tester);
    expect(uiCopy, contains('设备经营'));
    expect(uiCopy, contains('SANY 1#'));
    expect(uiCopy, contains('初始投入 ¥2,500'));
    expect(uiCopy, contains('实收补本额'));
    expect(uiCopy, contains('预计售出残值'));
    expect(uiCopy, contains('未回本缺口'));
    expect(uiCopy, contains('待收 ¥450'));
    expect(uiCopy, isNot(contains('已实收净额')));
    expect(uiCopy, isNot(contains('盈余')));
    expect(uiCopy, isNot(contains('收入 ¥1550 · 2.5小时, 3次')));
    expect(uiCopy, isNot(contains('1 项 · 待收 ¥450')));

    await tester.tap(find.text('SANY 1#'));
    await tester.pump();

    expect(openedDeviceId, 1);
  });

  testWidgets('device page pins title while search scrolls with content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedScaffoldApp(
        locale: const Locale('zh'),
        home: DevicePageContent(
          errorMessage: null,
          isLoading: false,
          onRetryLoad: () {},
          sections: List.generate(
            12,
            (index) => SizedBox(height: 80, child: Text('设备占位 $index')),
          ),
        ),
      ),
    );

    final titleFinder = find.text('设备');
    final searchFinder = find.text('搜索');

    expect(titleFinder, findsOneWidget);
    expect(searchFinder, findsOneWidget);
    expect(find.text('+ 新建'), findsNothing);

    final titleTopBefore = tester.getTopLeft(titleFinder).dy;
    final searchTopBefore = tester.getTopLeft(searchFinder).dy;

    await tester.drag(find.byType(ListView), const Offset(0, -280));
    await tester.pump();

    expect(tester.getTopLeft(titleFinder).dy, titleTopBefore);
    if (searchFinder.evaluate().isEmpty) {
      expect(searchFinder, findsNothing);
    } else {
      expect(tester.getTopLeft(searchFinder).dy, lessThan(searchTopBefore));
    }
  });

  testWidgets('renders device editor strings in English', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        child: const DeviceEditorDialog(),
      ),
    );

    final uiCopy = _collectUiCopy(tester);
    expect(uiCopy, contains('Add device'));
    expect(uiCopy, contains('No brand selected (avatar)'));
    expect(uiCopy, contains('Select'));
    expect(uiCopy, contains('Base meter (>= 0, required)'));
    expect(uiCopy, contains('Default rate (> 0, required)'));
    expect(uiCopy, contains('Breaker rate (optional)'));
    expect(uiCopy, contains('Model (optional)'));
    expect(uiCopy, contains('Cancel'));
    expect(uiCopy, contains('OK'));
  });

  testWidgets('renders device legal pages in both locales', (tester) async {
    await tester.pumpWidget(
      _localizedScaffoldApp(
        locale: const Locale('zh'),
        home: const PrivacyPage(),
      ),
    );
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('1. 适用范围'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('生效日期：2026 年 6 月 9 日'), 600);
    await tester.pumpAndSettle();
    expect(find.text('生效日期：2026 年 6 月 9 日'), findsOneWidget);

    await tester.pumpWidget(
      _localizedScaffoldApp(
        locale: const Locale('en'),
        home: const TermsPage(),
      ),
    );
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('1. Scope and acceptance'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Effective date: 2026-03-17'),
      600,
    );
    await tester.pumpAndSettle();
    expect(find.text('Effective date: 2026-03-17'), findsOneWidget);
    expect(find.text('使用条款'), findsNothing);
  });
}

Widget _localizedApp({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Widget _localizedScaffoldApp({required Locale locale, required Widget home}) {
  return MaterialApp(
    locale: locale,
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

DeviceBusinessLedger _ledger() {
  return const DeviceBusinessLedger(
    deviceId: 1,
    deviceName: 'SANY 1#',
    incomeFen: 155000,
    unitTotals: [
      DeviceBusinessUnitTotal(unit: MeasureUnit.hour, quantityScaled: 2500),
      DeviceBusinessUnitTotal(unit: MeasureUnit.trip, quantityScaled: 3000),
    ],
    projects: [
      DeviceBusinessProjectHistory(
        projectId: 'p1',
        projectName: 'Ding · Site',
        minYmd: 20260103,
        receivableFen: 55000,
        receivedFen: 10000,
        writeOffFen: 0,
        remainingFen: 45000,
        paymentStatus: DeviceBusinessPaymentStatus.partial,
        unitTotals: [
          DeviceBusinessUnitTotal(unit: MeasureUnit.hour, quantityScaled: 2500),
        ],
      ),
    ],
  );
}

LifecyclePaybackAmounts _lifecycleAmounts() {
  return const LifecyclePaybackAmounts(
    initialCostFen: 250000,
    estimatedResidualFen: 100000,
  );
}

String _collectUiCopy(WidgetTester tester) {
  final parts = <String>[];
  for (final widget in tester.allWidgets) {
    if (widget is Text) {
      parts.add(widget.data ?? widget.textSpan?.toPlainText() ?? '');
    } else if (widget is TextField) {
      final decoration = widget.decoration;
      if (decoration == null) continue;
      parts
        ..add(decoration.labelText ?? '')
        ..add(decoration.hintText ?? '')
        ..add(decoration.helperText ?? '');
    }
  }
  return parts.where((part) => part.isNotEmpty).join('\n');
}
