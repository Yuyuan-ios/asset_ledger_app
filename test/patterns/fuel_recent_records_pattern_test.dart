import 'package:asset_ledger/data/models/fuel_log.dart';
import 'package:asset_ledger/patterns/fuel/fuel_recent_records_pattern.dart';
import 'package:asset_ledger/tokens/mapper/radius_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fuel recent record title uses spaced display separator', (
    WidgetTester tester,
  ) async {
    final log = FuelLog(
      id: 1,
      deviceId: 1,
      date: 20260521,
      supplier: '何小波',
      liters: 50,
      cost: 400,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FuelRecordsListContent(
            logs: [log],
            leadingBuilder: (_) => const SizedBox(width: 40, height: 40),
            titleBuilder: (log) => log.supplier,
            subtitleBuilder: (_) => 'HITACHI 1#',
            onTap: (_) {},
            onConfirmDelete: null,
            onDelete: null,
          ),
        ),
      ),
    );

    expect(find.text('何小波 · 2026.05.21'), findsOneWidget);
    expect(find.text('何小波•2026.05.21'), findsNothing);
    expect(find.textContaining('•'), findsNothing);
  });

  testWidgets('fuel records list uses record card radius', (
    WidgetTester tester,
  ) async {
    final log = FuelLog(
      id: 1,
      deviceId: 1,
      date: 20260521,
      supplier: '何小波',
      liters: 50,
      cost: 400,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FuelRecordsListContent(
            logs: [log],
            leadingBuilder: (_) => const SizedBox(width: 40, height: 40),
            titleBuilder: (log) => log.supplier,
            subtitleBuilder: (_) => 'HITACHI 1#',
            onTap: (_) {},
            onConfirmDelete: null,
            onDelete: null,
          ),
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
}

Finder _recordCardContainers() {
  return find.byWidgetPredicate((widget) {
    final decoration = widget is Container ? widget.decoration : null;
    return decoration is BoxDecoration &&
        decoration.borderRadius ==
            BorderRadius.circular(RadiusTokens.recordCard);
  });
}
