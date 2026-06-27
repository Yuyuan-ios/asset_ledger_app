import 'package:asset_ledger/patterns/layout/record_card_surface.dart';
import 'package:asset_ledger/tokens/mapper/color_tokens.dart';
import 'package:asset_ledger/tokens/mapper/radius_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses record-card radius and optional chrome', (tester) async {
    var taps = 0;
    final border = Border.all(color: Colors.red, width: 0.5);
    const shadows = [BoxShadow(color: Colors.black12, blurRadius: 2)];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordCardSurface(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            border: border,
            boxShadow: shadows,
            onTap: () => taps += 1,
            child: const Text('content'),
          ),
        ),
      ),
    );

    final surface = tester.widget<Container>(_recordSurfaceContainer());
    final decoration = surface.decoration as BoxDecoration;

    expect(surface.margin, const EdgeInsets.only(bottom: 8));
    expect(decoration.color, SheetColors.background);
    expect(decoration.border, border);
    expect(decoration.boxShadow, shadows);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(RadiusTokens.recordCard),
    );

    await tester.tap(find.text('content'));
    expect(taps, 1);
  });
}

Finder _recordSurfaceContainer() {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    return decoration is BoxDecoration &&
        decoration.borderRadius ==
            BorderRadius.circular(RadiusTokens.recordCard);
  });
}
