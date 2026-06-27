import 'package:asset_ledger/components/feedback/app_confirm_dialog.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/features/device/domain/services/lifecycle_payback_calculator.dart';
import 'package:asset_ledger/features/device/view/lifecycle_payback_card.dart';
import 'package:asset_ledger/features/fuel/model/fuel_efficiency_agg.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/device/device_picker_pattern.dart';
import 'package:asset_ledger/patterns/fuel/fuel_detail_content_pattern.dart';
import 'package:asset_ledger/patterns/fuel/fuel_efficiency_summary_pattern.dart';
import 'package:asset_ledger/patterns/fuel/fuel_recent_records_pattern.dart';
import 'package:asset_ledger/patterns/fuel/fuel_supplier_filter_pattern.dart';
import 'package:asset_ledger/tokens/mapper/device_tokens.dart';
import 'package:asset_ledger/tokens/mapper/summary_card_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders fuel entry display strings in Chinese', (tester) async {
    await tester.pumpWidget(
      _localizedApp(locale: const Locale('zh'), child: _fuelDetailContent()),
    );
    await tester.pumpAndSettle();

    final uiCopy = _collectUiCopy(tester);
    expect(uiCopy, contains('供应人（必填）'));
    expect(uiCopy, contains('例如：中石化 / 充电站'));
    expect(uiCopy, contains('油电用量（升/度）'));
    expect(uiCopy, contains('金额（元）'));
  });

  testWidgets('renders fuel entry display strings in English', (tester) async {
    await tester.pumpWidget(
      _localizedApp(locale: const Locale('en'), child: _fuelDetailContent()),
    );
    await tester.pumpAndSettle();

    final uiCopy = _collectUiCopy(tester);
    expect(uiCopy, contains('Supplier (required)'));
    expect(uiCopy, contains('Example: Sinopec / charging station'));
    expect(uiCopy, contains('Energy amount (L/kWh)'));
    expect(uiCopy, contains('Amount (CNY)'));
    expect(uiCopy, isNot(contains('供应人（必填）')));
  });

  testWidgets('renders fuel list empty state in English', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        child: FuelRecentRecordsSection(
          logs: const [],
          leadingBuilder: (_) => const SizedBox(width: 40, height: 40),
          titleBuilder: (_) => '',
          subtitleBuilder: (_) => '',
          onTap: (_) {},
        ),
      ),
    );

    expect(find.text('Recent records (0)'), findsOneWidget);
    expect(find.text('No records'), findsOneWidget);
    expect(find.text('Tap + at the top right to create'), findsOneWidget);
  });

  testWidgets('renders fuel efficiency and filter strings in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: FuelEfficiencySummary(
                byDevice: const <int, FuelEfficiencyAgg>{},
                deviceNameOf: (_) => '',
              ),
            ),
            FuelSupplierFilter(
              controller: TextEditingController(),
              suggestionsBuilder: (_) => const <String>[],
              onChanged: (_) {},
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    );

    final uiCopy = _collectUiCopy(tester);
    expect(find.text('Energy efficiency by device'), findsOneWidget);
    expect(
      find.text('No data yet. Add energy and timing records first'),
      findsOneWidget,
    );
    expect(uiCopy, contains('Filter: supplier'));
    expect(uiCopy, isNot(contains('Type a keyword to filter (optional)')));
  });

  testWidgets('renders dedicated fuel supplier filter field chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: FuelSupplierFilter(
          controller: TextEditingController(),
          suggestionsBuilder: (_) => const <String>[],
          onChanged: (_) {},
          onSelected: (_) {},
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    final enabledBorder = textField.decoration?.enabledBorder;

    expect(textField.decoration?.labelText, isNull);
    expect(textField.decoration?.hintText, '筛选：供应人');
    expect(enabledBorder, isA<OutlineInputBorder>());
    expect(
      (enabledBorder! as OutlineInputBorder).borderRadius,
      BorderRadius.circular(8),
    );
  });

  testWidgets('renders fuel efficiency total timing text', (tester) async {
    final agg = FuelEfficiencyAgg(deviceId: 1)
      ..totalLiters = 40
      ..totalCost = 400
      ..totalHours = 10
      ..totalTimingHours = 13.5;

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: SizedBox(
          height: 120,
          child: FuelEfficiencySummary(
            byDevice: {1: agg},
            deviceNameOf: (_) => 'SANY 1#',
          ),
        ),
      ),
    );

    expect(find.text('SANY 1#'), findsOneWidget);
    expect(find.text('13.5 h'), findsOneWidget);
    expect(find.text('4.0 L/h'), findsOneWidget);
    expect(find.text('40.0 ¥/h'), findsOneWidget);
  });

  testWidgets('renders fuel efficiency lifecycle divider only when provided', (
    tester,
  ) async {
    final first = FuelEfficiencyAgg(deviceId: 1)
      ..totalLiters = 40
      ..totalCost = 400
      ..totalHours = 10
      ..totalTimingHours = 10;
    final second = FuelEfficiencyAgg(deviceId: 2)
      ..totalLiters = 12
      ..totalCost = 120
      ..totalHours = 6
      ..totalTimingHours = 6;
    final result = calculateLifecyclePayback(
      const LifecyclePaybackInput(
        initialCostFen: 80000,
        netReceivedFen: 60000,
        estimatedResidualFen: 60000,
      ),
    );
    const dividerKey = ValueKey('fuel-efficiency-business-segment-divider-1');
    const barKey = ValueKey('fuel-efficiency-business-segment-divider-bar-1');

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: SizedBox(
          height: 180,
          child: FuelEfficiencySummary(
            byDevice: {1: first, 2: second},
            deviceNameOf: (id) => id == 1 ? 'SANY 1#' : 'CAT 2#',
            businessSegmentDividerBuilder: (id) {
              if (id != 1) return null;
              return DeviceLifecycleSegmentDivider(
                key: dividerKey,
                barKey: barKey,
                result: result,
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(dividerKey), findsOneWidget);
    expect(find.byKey(barKey), findsOneWidget);
    expect(tester.getSize(find.byKey(barKey)).height, 2);
    expect(
      tester
          .getTopLeft(find.byKey(barKey))
          .dy
          .compareTo(tester.getBottomLeft(find.text('SANY 1#')).dy),
      greaterThan(0),
    );
    expect(
      find.byKey(const ValueKey('fuel-efficiency-business-segment-divider-2')),
      findsNothing,
    );
    expect(find.byType(DeviceLifecycleSegmentDivider), findsOneWidget);
    expect(result.surplusSegmentRatio, closeTo(1 / 3, 0.0001));
    expect(
      tester.getSize(find.byKey(barKey)).height,
      LifecyclePaybackTokens.deviceEfficiencyBusinessSegmentDividerHeight,
    );
  });

  testWidgets('centers multiple fuel efficiency rows vertically', (
    tester,
  ) async {
    final first = FuelEfficiencyAgg(deviceId: 1)
      ..totalLiters = 40
      ..totalCost = 400
      ..totalHours = 10
      ..totalTimingHours = 10;
    final second = FuelEfficiencyAgg(deviceId: 2)
      ..totalLiters = 12
      ..totalCost = 120
      ..totalHours = 6
      ..totalTimingHours = 6;
    const summaryKey = ValueKey('fuel-efficiency-summary');

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: SizedBox(
          key: summaryKey,
          height: 220,
          child: FuelEfficiencySummary(
            byDevice: {1: first, 2: second},
            deviceNameOf: (id) => id == 1 ? 'SANY 1#' : 'CAT 2#',
          ),
        ),
      ),
    );

    final titleBottom = tester.getBottomLeft(find.text('设备油电效率')).dy;
    final bodyTop = titleBottom + SummaryCardTokens.titleToContentGap;
    final bodyBottom = tester.getBottomLeft(find.byKey(summaryKey)).dy;
    final bodyCenterY = bodyTop + (bodyBottom - bodyTop) / 2;
    final rowsCenterY =
        (tester.getTopLeft(find.text('SANY 1#')).dy +
            tester.getBottomLeft(find.text('CAT 2#')).dy) /
        2;

    expect(rowsCenterY, closeTo(bodyCenterY, 6));
  });

  testWidgets('renders fuel delete dialog strings in English', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                final l10n = AppLocalizations.of(context);
                showAppConfirmDialog(
                  context: context,
                  title: l10n.fuelDeleteConfirmTitle,
                  content: l10n.fuelDeleteConfirmContent,
                  cancelText: l10n.fuelCancelAction,
                  confirmText: l10n.fuelDeleteConfirmAction,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete energy record?'), findsOneWidget);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
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
    home: Scaffold(body: child),
  );
}

FuelDetailContent _fuelDetailContent() {
  final device = _device();
  return FuelDetailContent(
    logs: const [],
    activeDevices: [device],
    deviceById: {device.id!: device},
    deviceItems: [DevicePickerItemVm(id: device.id!, label: device.name)],
    supplierSuggestions: (_) => const <String>[],
    onToast: (_) {},
    onSubmit: (_) async {},
  );
}

Device _device() {
  return Device(
    id: 1,
    name: 'SANY 1#',
    brand: 'SANY',
    defaultUnitPrice: 100,
    baseMeterHours: 0,
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
