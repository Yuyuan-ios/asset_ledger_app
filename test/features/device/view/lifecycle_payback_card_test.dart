import 'package:asset_ledger/features/device/domain/services/lifecycle_payback_calculator.dart';
import 'package:asset_ledger/features/device/view/lifecycle_payback_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaybackSegmentBar', () {
    testWidgets('uses one outer clip for surplus tail states', (tester) async {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 250000,
          netReceivedFen: 234724,
          estimatedResidualFen: 20000,
        ),
      );
      expect(result.isPaidBack, isTrue);
      expect(result.tailRatio, greaterThan(0));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 320,
            height: 36,
            child: PaybackSegmentBar(result: result),
          ),
        ),
      );

      final clips = tester.widgetList<ClipRRect>(find.byType(ClipRRect));
      expect(clips, hasLength(1));
      expect(clips.single.child, isA<Row>());

      final roundedSegmentContainers = tester
          .widgetList<Container>(find.byType(Container))
          .where((widget) {
            final decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.borderRadius != null;
          });
      expect(roundedSegmentContainers, isEmpty);
    });
  });
}
