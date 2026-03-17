import 'package:asset_ledger/data/models/device.dart';
import 'package:asset_ledger/patterns/device/device_editor_fields_group_pattern.dart';
import 'package:asset_ledger/tokens/mapper/sheet_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses decimal keyboard for meter and price fields', (
    WidgetTester tester,
  ) async {
    final baseMeterController = TextEditingController();
    final unitPriceController = TextEditingController();
    final breakingUnitPriceController = TextEditingController();
    final modelController = TextEditingController();
    addTearDown(baseMeterController.dispose);
    addTearDown(unitPriceController.dispose);
    addTearDown(breakingUnitPriceController.dispose);
    addTearDown(modelController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceEditorFieldsGroup(
            baseMeterController: baseMeterController,
            unitPriceController: unitPriceController,
            breakingUnitPriceController: breakingUnitPriceController,
            modelController: modelController,
            equipmentType: EquipmentType.excavator,
          ),
        ),
      ),
    );

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(
      fields[0].keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
    expect(
      fields[1].keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
  });

  testWidgets('shows breaking price hint for excavators', (
    WidgetTester tester,
  ) async {
    final baseMeterController = TextEditingController();
    final unitPriceController = TextEditingController();
    final breakingUnitPriceController = TextEditingController();
    final modelController = TextEditingController();
    addTearDown(baseMeterController.dispose);
    addTearDown(unitPriceController.dispose);
    addTearDown(breakingUnitPriceController.dispose);
    addTearDown(modelController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceEditorFieldsGroup(
            baseMeterController: baseMeterController,
            unitPriceController: unitPriceController,
            breakingUnitPriceController: breakingUnitPriceController,
            modelController: modelController,
            equipmentType: EquipmentType.excavator,
          ),
        ),
      ),
    );

    expect(find.text('不填写默认没有破碎模式'), findsOneWidget);

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    final decoration = fields[2].decoration!;
    expect(decoration.hintText, '不填写默认没有破碎模式');
    expect(decoration.hintStyle?.fontSize, SheetTokens.fieldLabelSize);
  });
}
