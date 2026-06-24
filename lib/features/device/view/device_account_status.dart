import '../../../app/phone_login_store.dart';
import '../domain/entities/subscription.dart';

String deviceAccountCenterSubtitle({
  required PhoneLoginSession session,
  required SubscriptionSnapshot subscription,
}) {
  if (!session.isAuthenticated) {
    return '未登录 · 登录后可备份与同步';
  }

  final entitlement = _subscriptionEntitlementLabel(subscription);
  final tail = _phoneTail(session.phoneNumber);
  if (tail == null) return '已登录 · $entitlement';
  return '已登录 · 尾号 $tail · $entitlement';
}

String accountCenterAuthTitle(PhoneLoginSession session) {
  return session.isAuthenticated ? '已登录' : '未登录';
}

String accountCenterAuthSubtitle({
  required PhoneLoginSession session,
  required SubscriptionSnapshot subscription,
}) {
  if (!session.isAuthenticated) {
    return '登录后可备份、恢复与同步数据';
  }

  final entitlement = _subscriptionEntitlementLabel(subscription);
  final tail = _phoneTail(session.phoneNumber);
  if (tail == null) return entitlement;
  return '尾号 $tail · $entitlement';
}

String purchaseEntitlementSubtitle(SubscriptionSnapshot subscription) {
  final entitlement = _subscriptionEntitlementLabel(subscription);
  final expiry = subscription.expiryDate;
  if (!subscription.allowsProFeatures || expiry == null) return entitlement;
  return '$entitlement · 有效至 ${_formatDate(expiry)}';
}

String _subscriptionEntitlementLabel(SubscriptionSnapshot subscription) {
  final errorMessage = subscription.errorMessage?.trim();
  if (errorMessage != null && errorMessage.isNotEmpty) return errorMessage;
  if (subscription.isRestoring ||
      subscription.isPurchasing ||
      subscription.status == SubscriptionStatus.pending) {
    return '正在等待 App Store 交易结果';
  }
  return subscription.allowsProFeatures ? 'Pro 已开通' : '免费版';
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
