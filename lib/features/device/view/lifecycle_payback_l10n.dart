import '../../../l10n/gen/app_localizations.dart';
import '../domain/services/lifecycle_payback_calculator.dart';

/// 把 [LifecyclePaybackResult] 的 status code + 原始数值映射为本地化展示文案。
/// calculator 只产出 code 与原始 paybackRate / lifeCycleProfitFen；
/// 百分比与金额的拼接（含 ICU placeholder）只发生在 UI 层。
String paybackStatusText(AppLocalizations l10n, LifecyclePaybackResult result) {
  switch (result.status) {
    case PaybackStatus.noCost:
      return l10n.deviceLifecyclePaybackNoCostStatus;
    case PaybackStatus.paidBack:
      final rate = result.paybackRate!;
      if (rate >= 2) {
        return l10n.deviceLifecyclePaybackPaidBackMultiplier(
          rate.toStringAsFixed(2),
        );
      }
      if ((rate - 1).abs() < 0.000001) {
        return l10n.deviceLifecyclePaybackPaidBackFull;
      }
      return l10n.deviceLifecyclePaybackPaidBackPercent(
        (rate * 100).toStringAsFixed(1),
      );
    case PaybackStatus.payingBack:
      return l10n.deviceLifecyclePaybackPercentInProgress(
        (result.paybackRate! * 100).toStringAsFixed(1),
      );
  }
}

String paybackResultText(AppLocalizations l10n, LifecyclePaybackResult result) {
  if (result.status == PaybackStatus.noCost) {
    return l10n.deviceLifecyclePaybackNoCostResult;
  }
  final profitFen = result.lifeCycleProfitFen;
  if (profitFen > 0) {
    return l10n.deviceLifecyclePaybackProfit(
      formatLifecycleMoneyFen(profitFen, explicitPlus: true),
    );
  }
  if (profitFen == 0) {
    return l10n.deviceLifecyclePaybackBreakeven;
  }
  return l10n.deviceLifecyclePaybackShortfall(
    formatLifecycleMoneyFen(profitFen.abs()),
  );
}
