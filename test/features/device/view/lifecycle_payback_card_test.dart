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
      expect(result.surplusSegmentRatio, greaterThan(0));

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
      expect(result.tailIsCapped, isFalse);
      expect(layout.receivedPrincipalSegment, isNotNull);
      expect(layout.residualSegment, isNotNull);
      expect(layout.surplusSegment, isNotNull);
      expect(layout.gapSegment, isNull);
      expect(layout.hasSurplusSegment, isTrue);
      expect(layout.segmentDividers, hasLength(2));
      expect(
        layout.receivedPrincipalSegment!.right,
        closeTo(320 * (81364 / 403360), 0.0001),
      );
      expect(
        layout.residualSegment!.left,
        closeTo(layout.receivedPrincipalSegment!.right, 0.0001),
      );
      expect(
        layout.residualSegment!.right,
        closeTo(320 * (250000 / 403360), 0.0001),
      );
      expect(
        layout.surplusSegment!.left,
        closeTo(layout.residualSegment!.right, 0.0001),
      );
      expect(layout.surplusSegment!.right, closeTo(320, 0.0001));
      expect(layout.segmentDividers.first.width, 2);
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
      expect(layout.surplusSegment, isNull);
      expect(layout.gapSegment, isNotNull);
      expect(layout.hasSurplusSegment, isFalse);
      expect(layout.receivedPrincipalSegment!.right, closeTo(128, 0.0001));
      expect(layout.residualSegment!.left, closeTo(128, 0.0001));
      expect(layout.residualSegment!.right, closeTo(192, 0.0001));
      expect(layout.gapSegment!.left, closeTo(192, 0.0001));
      expect(layout.gapSegment!.right, closeTo(320, 0.0001));
      expect(layout.segmentDividers, hasLength(2));
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
        expect(layout.surplusSegment, isNull);
        expect(layout.gapSegment, isNull);
        expect(layout.hasSurplusSegment, isFalse);
        expect(
          layout.residualSegment!.right,
          closeTo(layout.track.right, 0.0001),
        );
        expect(layout.segmentDividers, hasLength(1));
      },
    );

    test('uses scenario B ratios without capped surplus tail', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 80000,
          netReceivedFen: 60000,
          estimatedResidualFen: 60000,
        ),
      );

      final layout = calculatePaybackBarLayout(
        result: result,
        size: const Size(120, 36),
      );

      expect(result.tailIsCapped, isFalse);
      expect(result.receivedPrincipalSegmentRatio, closeTo(1 / 6, 0.0001));
      expect(result.estimatedResidualSegmentRatio, 0.5);
      expect(result.surplusSegmentRatio, closeTo(1 / 3, 0.0001));
      expect(layout.hasSurplusSegment, isTrue);
      expect(layout.receivedPrincipalSegment!.left, 0);
      expect(layout.receivedPrincipalSegment!.right, closeTo(20, 0.0001));
      expect(layout.residualSegment!.left, closeTo(20, 0.0001));
      expect(layout.residualSegment!.right, closeTo(80, 0.0001));
      expect(layout.surplusSegment!.left, closeTo(80, 0.0001));
      expect(layout.surplusSegment!.right, closeTo(120, 0.0001));
      expect(layout.gapSegment, isNull);
      expect(layout.segmentDividers, hasLength(2));
    });

    test('uses direct ratio width for tiny surplus', () {
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
      expect(result.surplusSegmentRatio, closeTo(1000 / 251000, 0.0001));
      expect(layout.hasSurplusSegment, isTrue);
      expect(
        layout.residualSegment!.width,
        closeTo(320 * (2000 / 251000), 0.001),
      );
      expect(
        layout.surplusSegment!.width,
        closeTo(320 * (1000 / 251000), 0.001),
      );
      expect(layout.surplusSegment!.right, closeTo(320, 0.0001));
      expect(layout.segmentDividers, hasLength(2));
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
      expect(layout.receivedPrincipalSegment, isNull);
      expect(layout.residualSegment, isNull);
      expect(layout.surplusSegment, isNull);
      expect(layout.gapSegment, isNull);
      expect(layout.hasSurplusSegment, isFalse);
      expect(layout.segmentDividers, isEmpty);
    });
  });
}
