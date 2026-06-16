import '../../../app/phone_login_store.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/entities/subscription.dart';

String deviceAccountCenterSubtitle({
  required AppLocalizations l10n,
  required PhoneLoginSession session,
  required SubscriptionSnapshot subscription,
}) {
  if (!session.isAuthenticated) {
    return l10n.deviceAccountCenterLoggedOutSubtitle;
  }

  final entitlement = _subscriptionEntitlementLabel(l10n, subscription);
  final tail = _phoneTail(session.phoneNumber);
  if (tail == null) {
    return l10n.deviceAccountCenterLoggedInSubtitle(entitlement);
  }
  return l10n.deviceAccountCenterLoggedInTailSubtitle(tail, entitlement);
}

String accountCenterAuthTitle(
  AppLocalizations l10n,
  PhoneLoginSession session,
) {
  return session.isAuthenticated
      ? l10n.deviceAccountLoggedInTitle
      : l10n.deviceAccountLoggedOutTitle;
}

String accountCenterAuthSubtitle({
  required AppLocalizations l10n,
  required PhoneLoginSession session,
  required SubscriptionSnapshot subscription,
}) {
  if (!session.isAuthenticated) {
    return l10n.deviceAccountAuthLoggedOutSubtitle;
  }

  final entitlement = _subscriptionEntitlementLabel(l10n, subscription);
  final tail = _phoneTail(session.phoneNumber);
  if (tail == null) return entitlement;
  return l10n.deviceAccountAuthTailSubtitle(tail, entitlement);
}

String purchaseEntitlementSubtitle(
  AppLocalizations l10n,
  SubscriptionSnapshot subscription,
) {
  final entitlement = _subscriptionEntitlementLabel(l10n, subscription);
  final expiry = subscription.expiryDate;
  if (!subscription.allowsProFeatures || expiry == null) return entitlement;
  return l10n.deviceEntitlementExpires(entitlement, _formatDate(expiry));
}

String _subscriptionEntitlementLabel(
  AppLocalizations l10n,
  SubscriptionSnapshot subscription,
) {
  return subscription.allowsProFeatures
      ? l10n.deviceEntitlementPro
      : l10n.deviceEntitlementFree;
}

String? _phoneTail(String? phoneNumber) {
  final trimmed = phoneNumber?.trim();
  if (trimmed == null || trimmed.length < 4) return null;
  return trimmed.substring(trimmed.length - 4);
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
