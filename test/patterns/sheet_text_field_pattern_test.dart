import 'package:asset_ledger/patterns/layout/sheet_text_field_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects zero-like numeric values on tap', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: '0.0');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SheetTextFieldPattern(
            controller: controller,
            labelText: '金额',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, controller.text.length);
  });

  testWidgets('keeps non-zero numeric values editable without force-selecting', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: '5817.1');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SheetTextFieldPattern(
            controller: controller,
            labelText: '基准码表',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(controller.selection.baseOffset, controller.text.length);
    expect(controller.selection.extentOffset, controller.text.length);
  });
}
