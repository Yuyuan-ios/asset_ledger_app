import 'package:asset_ledger/components/fields/app_auto_suggest_field.dart';
import 'package:asset_ledger/tokens/mapper/core_tokens.dart';
import 'package:asset_ledger/tokens/mapper/sheet_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('auto suggest arrow toggles a white suggestion popup', (
    tester,
  ) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AutoSuggestField(
            controller: controller,
            label: '联系人',
            suggestionsBuilder: (_) => const ['我', '余'],
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pump();

    expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    expect(find.text('我'), findsOneWidget);
    expect(_whiteSuggestionPopupMaterials(), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_drop_up));
    await tester.pumpAndSettle();

    expect(find.text('我'), findsNothing);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
  });
}

Finder _whiteSuggestionPopupMaterials() {
  return find.byWidgetPredicate((widget) {
    return widget is Material &&
        widget.color == SheetColors.background &&
        widget.elevation == SheetTokens.suggestMenuElevation;
  });
}
