import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/features/device/view/device_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editing device keeps breaking unit price when provided', (
    WidgetTester tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    Device? result;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<Device>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const DeviceEditorDialog(
                    device: Device(
                      id: 1,
                      name: 'SANY 1#',
                      brand: 'SANY',
                      model: null,
                      defaultUnitPrice: 120,
                      baseMeterHours: 2000,
                      equipmentType: EquipmentType.excavator,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final breakingField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == '破碎单价（选填）',
    );
    expect(breakingField, findsOneWidget);

    await tester.enterText(breakingField, '60');
    expect(
      tester.widget<TextField>(breakingField).controller?.text,
      '60',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.breakingUnitPrice, 60);
  });
}
