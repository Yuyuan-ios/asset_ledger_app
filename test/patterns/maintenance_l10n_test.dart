import 'package:asset_ledger/components/feedback/app_confirm_dialog.dart';
import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/features/maintenance/view/maintenance_records_section.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/patterns/device/device_picker_pattern.dart';
import 'package:asset_ledger/patterns/maintenance/maintenance_detail_content_pattern.dart';
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
    expect(uiCopy, contains('公共支出（不属于任何设备）'));
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
    expect(uiCopy, contains('Shared cost (not tied to a device)'));
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
          onDelete: (_) {},
        ),
      ),
    );

    expect(find.text('Recent records (0)'), findsOneWidget);
    expect(find.text('No records'), findsOneWidget);
    expect(find.text('Tap + at the top right to create'), findsOneWidget);
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
    } else if (widget is SwitchListTile) {
      final title = widget.title;
      if (title is Text) {
        parts.add(title.data ?? title.textSpan?.toPlainText() ?? '');
      }
    }
  }
  return parts.where((part) => part.isNotEmpty).join('\n');
}
