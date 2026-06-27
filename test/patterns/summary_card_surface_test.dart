import 'package:asset_ledger/patterns/layout/summary_card_surface.dart';
import 'package:asset_ledger/tokens/mapper/summary_card_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses shared chrome and optional tap handling', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryCardSurface(
            height: 80,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            onTap: () => taps += 1,
            child: const Text('content'),
          ),
        ),
      ),
    );

    final surface = tester.widget<Container>(_summarySurfaceContainer());
    final decoration = surface.decoration as BoxDecoration;

    expect(tester.getSize(_summarySurfaceContainer()).height, 88);
    expect(surface.margin, const EdgeInsets.only(bottom: 8));
    expect(decoration.color, SummaryCardTokens.cardBackground);
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNull);
    expect(decoration.borderRadius, SummaryCardTokens.cardBorderRadius);

    await tester.tap(find.text('content'));
    expect(taps, 1);
  });
}

Finder _summarySurfaceContainer() {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    return decoration is BoxDecoration &&
        decoration.borderRadius == SummaryCardTokens.cardBorderRadius;
  });
}
