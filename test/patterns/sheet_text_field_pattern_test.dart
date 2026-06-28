import 'package:asset_ledger/components/fields/app_auto_suggest_field.dart';
import 'package:asset_ledger/components/fields/app_date_field.dart';
import 'package:asset_ledger/components/fields/sheet_input_decoration.dart';
import 'package:asset_ledger/patterns/layout/sheet_text_field_pattern.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:asset_ledger/tokens/mapper/sheet_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds shared white field shell decoration', (
    WidgetTester tester,
  ) async {
    late InputDecoration decoration;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            decoration = buildSheetInputDecoration(
              context,
              labelText: '金额',
              hintText: '请输入',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(decoration.filled, isTrue);
    expect(decoration.fillColor, SheetColors.background);
    expect(
      decoration.constraints,
      const BoxConstraints(minHeight: SheetTokens.fieldHeight),
    );
    expect(decoration.floatingLabelBehavior, FloatingLabelBehavior.always);
    expect(decoration.labelStyle?.color, SheetColors.fieldLabel);
    expect(decoration.labelStyle?.color, const Color(0xB0000000));
    expect(SheetTokens.fieldRadius, RadiusTokens.input);

    final border = decoration.border as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(RadiusTokens.input));
    expect(border.borderSide.color, SheetColors.fieldBorder);
    expect(border.borderSide.color, const Color(0x1A000000));
  });

  testWidgets('date and suggestion fields reuse the shared white shell', (
    WidgetTester tester,
  ) async {
    final dateController = TextEditingController(text: '2026.06.28');
    final suggestController = TextEditingController(text: '中石化');
    addTearDown(dateController.dispose);
    addTearDown(suggestController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SheetDateField(controller: dateController, onPickDate: () {}),
              AutoSuggestField(
                controller: suggestController,
                label: '供应人',
                hint: '例如：中石化',
                suggestionsBuilder: (_) => const ['中石化'],
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, hasLength(2));
    for (final field in fields) {
      expect(field.decoration?.filled, isTrue);
      expect(field.decoration?.fillColor, SheetColors.background);
      expect(
        field.decoration?.constraints,
        const BoxConstraints(minHeight: SheetTokens.fieldHeight),
      );
    }
  });

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

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.filled, isTrue);
    expect(field.decoration?.fillColor, SheetColors.background);
    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, controller.text.length);
  });

  testWidgets(
    'keeps non-zero numeric values editable without force-selecting',
    (WidgetTester tester) async {
      final controller = TextEditingController(text: '5817.1');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SheetTextFieldPattern(
              controller: controller,
              labelText: '基准码表',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(controller.selection.baseOffset, controller.text.length);
      expect(controller.selection.extentOffset, controller.text.length);
    },
  );
}
