import 'package:asset_ledger/features/device/domain/services/lifecycle_payback_calculator.dart';
import 'package:asset_ledger/features/device/view/lifecycle_payback_card.dart';
import 'package:asset_ledger/features/device/view/lifecycle_payback_l10n.dart';
import 'package:asset_ledger/l10n/gen/app_localizations_zh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsZh();

  group('PaybackSegmentBar', () {
    testWidgets('uses a painter instead of rounded segment widgets', (
      tester,
    ) async {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 250000,
          netReceivedFen: 234724,
          estimatedResidualFen: 168636,
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

      expect(find.byType(CustomPaint), findsOneWidget);
      expect(find.byType(ClipRRect), findsNothing);
      expect(find.byType(Row), findsNothing);
      expect(find.byType(Stack), findsNothing);
    });

    test('renders surplus state as square rect segments', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 250000,
          netReceivedFen: 234724,
          estimatedResidualFen: 168636,
        ),
      );

      final layout = calculatePaybackBarLayout(
        result: result,
        size: const Size(320, 36),
      );

      expect(paybackStatusText(l10n, result), '已回本 161.3%');
      expect(paybackResultText(l10n, result), '预计盈余 +¥1,534');
      expect(result.tailIsCapped, isTrue);
      expect(layout.netSegment, isNotNull);
      expect(layout.residualSegment, isNotNull);
      expect(layout.tailSegment, isNotNull);
      expect(layout.hasProfitTail, isTrue);
      expect(layout.paybackDivider, isNotNull);
      expect(layout.residualGapDivider, isNull);
      expect(layout.netSegment!.right, closeTo(240.3574, 0.0001));
      expect(
        layout.residualSegment!.right,
        closeTo(layout.tailSegment!.left, 0.0001),
      );
      expect(layout.tailSegment!.left, closeTo(256, 0.0001));
      expect(layout.tailSegment!.right, closeTo(320, 0.0001));
      expect(layout.paybackDivider!.left, closeTo(255, 0.0001));
      expect(layout.paybackDivider!.width, 2);
    });

    test('keeps residual square before the unpaid gap', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 250000,
          netReceivedFen: 100000,
          estimatedResidualFen: 50000,
        ),
      );

      final layout = calculatePaybackBarLayout(
        result: result,
        size: const Size(320, 36),
      );

      expect(result.isPaidBack, isFalse);
      expect(layout.tailSegment, isNull);
      expect(layout.hasProfitTail, isFalse);
      expect(layout.netSegment!.right, closeTo(128, 0.0001));
      expect(layout.residualSegment!.left, closeTo(128, 0.0001));
      expect(layout.residualSegment!.right, closeTo(192, 0.0001));
      expect(layout.netResidualDivider, isNotNull);
      expect(layout.residualGapDivider, isNotNull);
      expect(layout.paybackDivider, isNull);
    });

    test(
      'allows residual to reach the outer right edge when exactly paid back',
      () {
        final result = calculateLifecyclePayback(
          const LifecyclePaybackInput(
            initialCostFen: 250000,
            netReceivedFen: 200000,
            estimatedResidualFen: 50000,
          ),
        );

        final layout = calculatePaybackBarLayout(
          result: result,
          size: const Size(320, 36),
        );

        expect(paybackResultText(l10n, result), '已回本，暂无盈余');
        expect(layout.tailSegment, isNull);
        expect(layout.hasProfitTail, isFalse);
        expect(
          layout.residualSegment!.right,
          closeTo(layout.track.right, 0.0001),
        );
        expect(layout.netResidualDivider, isNotNull);
        expect(layout.residualGapDivider, isNull);
        expect(layout.paybackDivider, isNull);
      },
    );

    test('caps large surplus tails without adding residual width', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 250000,
          netReceivedFen: 400000,
          estimatedResidualFen: 30000,
        ),
      );

      final layout = calculatePaybackBarLayout(
        result: result,
        size: const Size(320, 36),
      );

      expect(result.tailIsCapped, isTrue);
      expect(layout.hasProfitTail, isTrue);
      expect(layout.netSegment!.right, closeTo(256, 0.0001));
      expect(layout.residualSegment, isNull);
      expect(layout.tailSegment!.left, closeTo(256, 0.0001));
      expect(layout.tailSegment!.right, closeTo(320, 0.0001));
      expect(layout.paybackDivider, isNotNull);
    });

    test('uses ratio-based square tail width for tiny surplus', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 250000,
          netReceivedFen: 249000,
          estimatedResidualFen: 2000,
        ),
      );

      final layout = calculatePaybackBarLayout(
        result: result,
        size: const Size(320, 36),
      );

      expect(result.isPaidBack, isTrue);
      expect(result.lifeCycleProfitFen, 1000);
      expect(layout.hasProfitTail, isTrue);
      expect(layout.tailSegment!.width, closeTo(1.275, 0.001));
      expect(layout.tailSegment!.right, 320);
      expect(layout.paybackDivider, isNotNull);
    });

    test('leaves only the track for unset costs', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: null,
          netReceivedFen: 100000,
          estimatedResidualFen: 50000,
        ),
      );

      final layout = calculatePaybackBarLayout(
        result: result,
        size: const Size(320, 36),
      );

      expect(result.isCostUnset, isTrue);
      expect(layout.track, const Rect.fromLTWH(0, 0, 320, 36));
      expect(layout.netSegment, isNull);
      expect(layout.residualSegment, isNull);
      expect(layout.tailSegment, isNull);
      expect(layout.hasProfitTail, isFalse);
      expect(layout.paybackDivider, isNull);
    });
  });
}
