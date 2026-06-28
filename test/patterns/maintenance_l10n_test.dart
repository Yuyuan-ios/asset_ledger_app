import 'dart:async';

import 'package:asset_ledger/components/feedback/app_confirm_dialog.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/data/models/maintenance_record.dart';
import 'package:asset_ledger/features/maintenance/view/maintenance_records_section.dart';
import 'package:asset_ledger/features/maintenance/view/maintenance_page_view_data.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/device/device_picker_pattern.dart';
import 'package:asset_ledger/patterns/maintenance/maintenance_detail_content_pattern.dart';
import 'package:asset_ledger/patterns/timing/exclude_fuel_switch_card_pattern.dart';
import 'package:asset_ledger/tokens/mapper/radius_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders maintenance entry display strings in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: _maintenanceDetailContent(),
      ),
    );
    await tester.pumpAndSettle();

    final uiCopy = _collectUiCopy(tester);
    expect(find.byType(ExcludeFuelSwitchCard), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(uiCopy, contains('公共支出'));
    expect(uiCopy, contains('不属于任何设备'));
    expect(uiCopy, contains('事项（必填）'));
    expect(uiCopy, contains('例如：更换机油/保养/维修'));
    expect(uiCopy, contains('金额（元）'));
    expect(uiCopy, contains('备注（可填）'));
  });

  testWidgets('renders maintenance entry display strings in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        child: _maintenanceDetailContent(),
      ),
    );
    await tester.pumpAndSettle();

    final uiCopy = _collectUiCopy(tester);
    expect(uiCopy, contains('Shared cost'));
    expect(uiCopy, contains('not tied to a device'));
    expect(uiCopy, contains('Service item (required)'));
    expect(uiCopy, contains('Example: oil change / service / repair'));
    expect(uiCopy, contains('Amount (CNY)'));
    expect(uiCopy, contains('Notes (optional)'));
    expect(uiCopy, isNot(contains('事项（必填）')));
  });

  testWidgets('renders maintenance list empty state in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        child: MaintenanceRecordsSection(
          rows: const [],
          onEdit: (_) {},
          onConfirmDelete: (_) async => false,
          onDelete: (_) async => true,
        ),
      ),
    );

    expect(find.text('Recent records (0)'), findsOneWidget);
    expect(find.text('No records'), findsOneWidget);
    expect(find.text('Tap + at the top right to create'), findsOneWidget);
  });

  testWidgets('maintenance records list uses record card radius', (
    tester,
  ) async {
    final record = MaintenanceRecord(
      id: 1,
      deviceId: 1,
      ymd: 20260627,
      item: '保养',
      amount: 880,
    );

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: MaintenanceRecordsContent(
          rows: [
            MaintenanceRecordRowVM(
              record: record,
              title: 'HITACHI 1#',
              subtitle: '保养',
              dateText: '2026.06.27',
              amountText: '¥880',
            ),
          ],
          onEdit: (_) {},
          onConfirmDelete: (_) async => false,
          onDelete: (_) async => true,
        ),
      ),
    );

    final card = tester.widget<Container>(_recordCardContainers().first);
    final decoration = card.decoration as BoxDecoration;

    expect(
      decoration.borderRadius,
      BorderRadius.circular(RadiusTokens.recordCard),
    );
  });

  testWidgets('maintenance records list only draws separators between rows', (
    tester,
  ) async {
    final first = MaintenanceRecord(
      id: 1,
      deviceId: 1,
      ymd: 20260628,
      item: '保养',
      amount: 1980,
    );
    final second = MaintenanceRecord(
      id: 2,
      deviceId: 1,
      ymd: 20260627,
      item: '维修',
      amount: 980,
    );

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: MaintenanceRecordsContent(
          rows: [
            MaintenanceRecordRowVM(
              record: first,
              title: 'HITACHI 1#',
              subtitle: '保养',
              dateText: '2026.06.28',
              amountText: '¥1980',
            ),
            MaintenanceRecordRowVM(
              record: second,
              title: 'HITACHI 1#',
              subtitle: '维修',
              dateText: '2026.06.27',
              amountText: '¥980',
            ),
          ],
          onEdit: (_) {},
          onConfirmDelete: (_) async => false,
          onDelete: (_) async => true,
        ),
      ),
    );

    final listColumn = tester.widget<Column>(_recordListColumn());

    expect(listColumn.children, hasLength(3));
    expect(listColumn.children.first, isNot(isA<Divider>()));
    expect(listColumn.children[1], isA<Divider>());
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('maintenance dismissed row is removed before delete completes', (
    tester,
  ) async {
    final deleteCompleter = Completer<bool>();
    final record = MaintenanceRecord(
      id: 1,
      deviceId: 1,
      ymd: 20260628,
      item: '保养',
      amount: 1980,
    );

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        child: MaintenanceRecordsContent(
          rows: [
            MaintenanceRecordRowVM(
              record: record,
              title: 'HITACHI 1#',
              subtitle: '保养',
              dateText: '2026.06.28',
              amountText: '¥1980',
            ),
          ],
          onEdit: (_) {},
          onConfirmDelete: (_) async => true,
          onDelete: (_) => deleteCompleter.future,
        ),
      ),
    );

    await tester.drag(find.text('保养'), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('保养'), findsNothing);
    expect(tester.takeException(), isNull);

    deleteCompleter.complete(true);
    await tester.pump();
  });

  testWidgets('renders maintenance delete dialog strings in English', (
    tester,
  ) async {
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
                  title: l10n.maintenanceDeleteConfirmTitle,
                  content:
                      '${l10n.maintenanceDeleteConfirmDateLine('2026-06-16')}\n'
                      '${l10n.maintenanceDeleteConfirmItemLine('Oil change')}\n'
                      '${l10n.maintenanceDeleteConfirmAmountLine('980.0')}\n\n'
                      '${l10n.maintenanceDeleteConfirmWarning}',
                  cancelText: l10n.maintenanceCancelAction,
                  confirmText: l10n.maintenanceDeleteConfirmAction,
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

    expect(find.text('Delete service record?'), findsOneWidget);
    expect(find.textContaining('Date: 2026-06-16'), findsOneWidget);
    expect(find.textContaining('Item: Oil change'), findsOneWidget);
    expect(find.textContaining('Amount: 980.0'), findsOneWidget);
    expect(find.textContaining('This cannot be undone.'), findsOneWidget);
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

MaintenanceDetailContent _maintenanceDetailContent() {
  final device = _device();
  return MaintenanceDetailContent(
    initialDeviceId: device.id,
    deviceById: {device.id!: device},
    deviceItems: [DevicePickerItemVm(id: device.id!, label: device.name)],
    itemSuggestions: (_) => const <String>[],
    onCancel: () {},
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

Finder _recordCardContainers() {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    return decoration is BoxDecoration &&
        decoration.borderRadius ==
            BorderRadius.circular(RadiusTokens.recordCard);
  });
}

Finder _recordListColumn() {
  return find.byWidgetPredicate((widget) {
    return widget is Column &&
        widget.children.length == 3 &&
        widget.children[1] is Divider;
  });
}
