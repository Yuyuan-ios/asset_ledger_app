import 'package:asset_ledger/features/device/domain/services/lifecycle_payback_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateLifecyclePayback', () {
    test('treats missing initial cost as unset', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: null,
          netReceivedFen: 5472400,
          estimatedResidualFen: 800000,
        ),
      );

      expect(result.isCostUnset, isTrue);
      expect(result.paybackRate, isNull);
      expect(result.paybackGapSegmentRatio, 0);
      expect(result.gapSegmentRatio, 1);
      expect(result.status, PaybackStatus.noCost);
    });

    test('treats zero initial cost as unset', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 0,
          netReceivedFen: 100000,
          estimatedResidualFen: 50000,
        ),
      );

      expect(result.isCostUnset, isTrue);
      expect(result.isPaidBack, isFalse);
      expect(result.paybackRate, isNull);
      expect(result.gapSegmentRatio, 1);
      expect(result.status, PaybackStatus.noCost);
    });

    test('treats negative initial cost as unset', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: -100000,
          netReceivedFen: 100000,
          estimatedResidualFen: 50000,
        ),
      );

      expect(result.isCostUnset, isTrue);
      expect(result.isPaidBack, isFalse);
      expect(result.paybackRate, isNull);
      expect(result.lifeCycleProfitFen, 0);
    });

    test(
      'calculates exact payback with received principal and full residual',
      () {
        final result = calculateLifecyclePayback(
          const LifecyclePaybackInput(
            initialCostFen: 80000,
            netReceivedFen: 20000,
            estimatedResidualFen: 60000,
          ),
        );

        expect(result.isPaidBack, isTrue);
        expect(result.paybackRate, 1.0);
        expect(result.lifeCycleProfitFen, 0);
        expect(result.receivedPrincipalFen, 20000);
        expect(result.estimatedResidualSegmentFen, 60000);
        expect(result.surplusSegmentFen, 0);
        expect(result.paybackGapFen, 0);
        expect(result.visualTotalFen, 80000);
        expect(result.receivedPrincipalSegmentRatio, 0.25);
        expect(result.estimatedResidualSegmentRatio, 0.75);
        expect(result.surplusSegmentRatio, 0);
        expect(result.paybackGapSegmentRatio, 0);
      },
    );

    test('calculates surplus without capped tail', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 80000,
          netReceivedFen: 60000,
          estimatedResidualFen: 60000,
        ),
      );

      expect(result.isPaidBack, isTrue);
      expect(result.paybackRate, 1.5);
      expect(result.lifeCycleProfitFen, 40000);
      expect(result.receivedPrincipalFen, 20000);
      expect(result.estimatedResidualSegmentFen, 60000);
      expect(result.surplusSegmentFen, 40000);
      expect(result.paybackGapFen, 0);
      expect(result.visualTotalFen, 120000);
      expect(result.receivedPrincipalSegmentRatio, closeTo(1 / 6, 0.0001));
      expect(result.estimatedResidualSegmentRatio, 0.5);
      expect(result.surplusSegmentRatio, closeTo(1 / 3, 0.0001));
      expect(result.paybackGapSegmentRatio, 0);
      expect(result.tailIsCapped, isFalse);
    });

    test('calculates unpaid gap with the same visual denominator', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 80000,
          netReceivedFen: 10000,
          estimatedResidualFen: 20000,
        ),
      );

      expect(result.isPaidBack, isFalse);
      expect(result.paybackRate, 0.375);
      expect(result.lifeCycleProfitFen, -50000);
      expect(result.receivedPrincipalFen, 10000);
      expect(result.estimatedResidualSegmentFen, 20000);
      expect(result.surplusSegmentFen, 0);
      expect(result.paybackGapFen, 50000);
      expect(result.visualTotalFen, 80000);
      expect(result.receivedPrincipalSegmentRatio, 0.125);
      expect(result.estimatedResidualSegmentRatio, 0.25);
      expect(result.surplusSegmentRatio, 0);
      expect(result.paybackGapSegmentRatio, 0.625);
    });

    test('calculates not paid back state', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 6000000,
          netReceivedFen: 4500000,
          estimatedResidualFen: 660000,
        ),
      );

      expect(result.isPaidBack, isFalse);
      expect(result.totalRecoverableFen, 5160000);
      expect(result.lifeCycleProfitFen, -840000);
      expect(result.paybackRate, closeTo(0.86, 0.0001));
      expect(result.receivedPrincipalSegmentRatio, closeTo(0.75, 0.0001));
      expect(result.estimatedResidualSegmentRatio, closeTo(0.11, 0.0001));
      expect(result.paybackGapSegmentRatio, closeTo(0.14, 0.0001));
      expect(result.tailRatio, 0);
      expect(result.status, PaybackStatus.payingBack);
    });

    test('calculates exactly paid back state', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 6000000,
          netReceivedFen: 5200000,
          estimatedResidualFen: 800000,
        ),
      );

      expect(result.isPaidBack, isTrue);
      expect(result.lifeCycleProfitFen, 0);
      expect(result.receivedPrincipalSegmentRatio, closeTo(0.8667, 0.0001));
      expect(result.estimatedResidualSegmentRatio, closeTo(0.1333, 0.0001));
      expect(result.paybackGapSegmentRatio, 0);
      expect(result.tailRatio, 0);
      expect(result.status, PaybackStatus.paidBack);
    });

    test('calculates small paid back surplus with uncapped tail', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 6000000,
          netReceivedFen: 5472400,
          estimatedResidualFen: 800000,
        ),
      );

      expect(result.isPaidBack, isTrue);
      expect(result.totalRecoverableFen, 6272400);
      expect(result.lifeCycleProfitFen, 272400);
      expect(result.paybackRate, closeTo(1.0454, 0.0001));
      expect(
        result.receivedPrincipalSegmentRatio,
        closeTo(5200000 / 6272400, 0.0001),
      );
      expect(
        result.estimatedResidualSegmentRatio,
        closeTo(800000 / 6272400, 0.0001),
      );
      expect(result.surplusSegmentRatio, closeTo(272400 / 6272400, 0.0001));
      expect(result.tailIsCapped, isFalse);
      expect(result.status, PaybackStatus.paidBack);
    });

    test('keeps full residual and uncapped surplus for large surplus', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 80000,
          netReceivedFen: 60000,
          estimatedResidualFen: 60000,
        ),
      );

      expect(result.isPaidBack, isTrue);
      expect(result.lifeCycleProfitFen, 40000);
      expect(result.paybackRate, 1.5);
      expect(result.receivedPrincipalSegmentRatio, closeTo(1 / 6, 0.0001));
      expect(result.estimatedResidualSegmentRatio, 0.5);
      expect(result.surplusSegmentRatio, closeTo(1 / 3, 0.0001));
      expect(result.tailRatio, closeTo(1 / 3, 0.0001));
      expect(result.tailIsCapped, isFalse);
      expect(result.status, PaybackStatus.paidBack);
    });

    test('responds to estimated residual changes', () {
      final lower = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 6000000,
          netReceivedFen: 5400000,
          estimatedResidualFen: 0,
        ),
      );
      final higher = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 6000000,
          netReceivedFen: 5400000,
          estimatedResidualFen: 900000,
        ),
      );

      expect(lower.isPaidBack, isFalse);
      expect(higher.isPaidBack, isTrue);
      expect(lower.status, PaybackStatus.payingBack);
      expect(higher.status, PaybackStatus.paidBack);
    });

    test('responds to initial cost changes', () {
      final lowerCost = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 5000000,
          netReceivedFen: 4500000,
          estimatedResidualFen: 800000,
        ),
      );
      final higherCost = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 7000000,
          netReceivedFen: 4500000,
          estimatedResidualFen: 800000,
        ),
      );

      expect(lowerCost.isPaidBack, isTrue);
      expect(higherCost.isPaidBack, isFalse);
      expect(lowerCost.lifeCycleProfitFen, 300000);
      expect(higherCost.lifeCycleProfitFen, -1700000);
    });

    test('handles zero net received', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 6000000,
          netReceivedFen: 0,
          estimatedResidualFen: 800000,
        ),
      );

      expect(result.receivedPrincipalSegmentRatio, 0);
      expect(result.estimatedResidualSegmentRatio, closeTo(0.1333, 0.0001));
      expect(result.paybackGapSegmentRatio, closeTo(0.8667, 0.0001));
      expect(result.lifeCycleProfitFen, -5200000);
    });

    test('clamps negative visual widths without dropping real amounts', () {
      final result = calculateLifecyclePayback(
        const LifecyclePaybackInput(
          initialCostFen: 6000000,
          netReceivedFen: -100000,
          estimatedResidualFen: 800000,
        ),
      );

      expect(result.totalRecoverableFen, 700000);
      expect(result.lifeCycleProfitFen, -5300000);
      expect(result.receivedPrincipalSegmentRatio, 0);
      expect(result.estimatedResidualSegmentRatio, closeTo(0.1333, 0.0001));
      expect(result.paybackGapSegmentRatio, closeTo(0.8667, 0.0001));
    });
  });

  group('formatLifecycleMoneyFen', () {
    test('formats integer yuan with thousands and optional sign', () {
      expect(formatLifecycleMoneyFen(6000000), '¥60,000');
      expect(formatLifecycleMoneyFen(272400, explicitPlus: true), '+¥2,724');
      expect(formatLifecycleMoneyFen(0, explicitPlus: true), '¥0');
      expect(formatLifecycleMoneyFen(-427600), '-¥4,276');
    });
  });
}
