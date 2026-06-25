import 'package:asset_ledger/features/device/domain/services/lifecycle_payback_calculator.dart';
import 'package:asset_ledger/features/device/view/lifecycle_payback_l10n.dart';
import 'package:asset_ledger/l10n/gen/app_localizations_zh.dart';
import 'package:flutter_test/flutter_test.dart';

/// Characterization: the localized (zh) status/result copy must be byte-for-byte
/// identical to the legacy strings that lived in the calculator before the
/// code+raw-value refactor (S5b-B).
void main() {
  final l10n = AppLocalizationsZh();

  LifecyclePaybackResult resultFor({
    required int? initialCostFen,
    required int netReceivedFen,
    required int estimatedResidualFen,
  }) {
    return calculateLifecyclePayback(
      LifecyclePaybackInput(
        initialCostFen: initialCostFen,
        netReceivedFen: netReceivedFen,
        estimatedResidualFen: estimatedResidualFen,
      ),
    );
  }

  group('paybackStatusText (zh) — equivalent to legacy copy', () {
    test('unset cost', () {
      expect(
        paybackStatusText(
          l10n,
          resultFor(
            initialCostFen: null,
            netReceivedFen: 5472400,
            estimatedResidualFen: 800000,
          ),
        ),
        '未设置成本',
      );
    });

    test('paying back shows "回本 X%"', () {
      expect(
        paybackStatusText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 4500000,
            estimatedResidualFen: 660000,
          ),
        ),
        '回本 86.0%',
      );
    });

    test('exactly paid back shows "已回本 100%"', () {
      expect(
        paybackStatusText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 5200000,
            estimatedResidualFen: 800000,
          ),
        ),
        '已回本 100%',
      );
    });

    test('paid back below 2x shows "已回本 X%"', () {
      expect(
        paybackStatusText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 5472400,
            estimatedResidualFen: 800000,
          ),
        ),
        '已回本 104.5%',
      );
    });

    test('paid back at exactly 2x shows multiplier', () {
      expect(
        paybackStatusText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 12000000,
            estimatedResidualFen: 0,
          ),
        ),
        '已回本 2.00x',
      );
    });

    test('large surplus shows multiplier "已回本 X.XXx"', () {
      expect(
        paybackStatusText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 10000000,
            estimatedResidualFen: 9080000,
          ),
        ),
        '已回本 3.18x',
      );
    });

    test('responds to residual changes (paying vs paid)', () {
      expect(
        paybackStatusText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 5400000,
            estimatedResidualFen: 0,
          ),
        ),
        '回本 90.0%',
      );
      expect(
        paybackStatusText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 5400000,
            estimatedResidualFen: 900000,
          ),
        ),
        '已回本 105.0%',
      );
    });
  });

  group('paybackResultText (zh) — equivalent to legacy copy', () {
    test('unset cost', () {
      expect(
        paybackResultText(
          l10n,
          resultFor(
            initialCostFen: null,
            netReceivedFen: 5472400,
            estimatedResidualFen: 800000,
          ),
        ),
        '设置后可查看回本进度与预计盈余',
      );
    });

    test('surplus shows "预计盈余 +¥X"', () {
      expect(
        paybackResultText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 5472400,
            estimatedResidualFen: 800000,
          ),
        ),
        '预计盈余 +¥2,724',
      );
      expect(
        paybackResultText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 10000000,
            estimatedResidualFen: 9080000,
          ),
        ),
        '预计盈余 +¥130,800',
      );
      expect(
        paybackResultText(
          l10n,
          resultFor(
            initialCostFen: 5000000,
            netReceivedFen: 4500000,
            estimatedResidualFen: 800000,
          ),
        ),
        '预计盈余 +¥3,000',
      );
    });

    test('exactly paid back shows "已回本，暂无盈余"', () {
      expect(
        paybackResultText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 5200000,
            estimatedResidualFen: 800000,
          ),
        ),
        '已回本，暂无盈余',
      );
    });

    test('shortfall shows "还差 ¥X 回本"', () {
      expect(
        paybackResultText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 4500000,
            estimatedResidualFen: 660000,
          ),
        ),
        '还差 ¥8,400 回本',
      );
      expect(
        paybackResultText(
          l10n,
          resultFor(
            initialCostFen: 7000000,
            netReceivedFen: 4500000,
            estimatedResidualFen: 800000,
          ),
        ),
        '还差 ¥17,000 回本',
      );
      expect(
        paybackResultText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: 0,
            estimatedResidualFen: 800000,
          ),
        ),
        '还差 ¥52,000 回本',
      );
      expect(
        paybackResultText(
          l10n,
          resultFor(
            initialCostFen: 6000000,
            netReceivedFen: -100000,
            estimatedResidualFen: 800000,
          ),
        ),
        '还差 ¥53,000 回本',
      );
    });
  });
}
