import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../domain/entities/subscription.dart';

String subscriptionRestoreOutcomeMessage(
  AppLocalizations l10n,
  SubscriptionRestoreOutcome outcome,
) {
  final reason = outcome.reason;
  return switch (outcome.kind) {
    SubscriptionRestoreOutcomeKind.restoredPro =>
      l10n.deviceRestoreResultRestoredPro,
    SubscriptionRestoreOutcomeKind.restoredMax =>
      l10n.deviceRestoreResultRestoredMax,
    SubscriptionRestoreOutcomeKind.noActivePurchase =>
      l10n.deviceRestoreResultNoPurchase,
    SubscriptionRestoreOutcomeKind.failed => l10n.deviceRestoreResultFailed(
      reason == null || reason.isEmpty
          ? l10n.deviceRestoreResultNoPurchase
          : reason,
    ),
    SubscriptionRestoreOutcomeKind.unavailable =>
      l10n.deviceRestoreResultUnavailable(
        reason == null || reason.isEmpty
            ? l10n.deviceUpgradePurchaseUnavailable
            : reason,
      ),
  };
}

void showSubscriptionRestoreSnackBar(
  BuildContext context,
  SubscriptionRestoreOutcome outcome,
) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(subscriptionRestoreOutcomeMessage(l10n, outcome)),
        duration: const Duration(seconds: 2),
      ),
    );
}
