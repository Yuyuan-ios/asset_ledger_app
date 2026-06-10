import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/config/subscription_product_ids.dart';
import 'subscription_entitlement_cache.dart';
import 'subscription_identity_store.dart';
import 'subscription_store_gateway.dart';
import 'subscription_verification_repository.dart';
import 'subscription_verification_repository_factory.dart';

enum SubscriptionStatus {
  unknown,
  free,
  pending,
  activePro,
  activeMax,
  inGracePeriodPro,
  inGracePeriodMax,
  billingRetry,
  expired,
  revoked,
  noActiveEntitlement,
}

enum SubscriptionProductKind { pro, max }

class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.status,
    required this.products,
    this.entitlementTier = SubscriptionEntitlementTier.none,
    this.isEntitlementVerified = false,
    this.isLoadingProducts = false,
    this.isPurchasing = false,
    this.isRestoring = false,
    this.isSyncing = false,
    this.productId,
    this.expiryDate,
    this.lastSyncedAt,
    this.errorMessage,
  });

  factory SubscriptionSnapshot.initial() {
    return const SubscriptionSnapshot(
      status: SubscriptionStatus.unknown,
      products: <SubscriptionProductKind, ProductDetails>{},
    );
  }

  final SubscriptionStatus status;
  final Map<SubscriptionProductKind, ProductDetails> products;
  final SubscriptionEntitlementTier entitlementTier;
  final bool isEntitlementVerified;
  final bool isLoadingProducts;
  final bool isPurchasing;
  final bool isRestoring;
  final bool isSyncing;
  final String? productId;
  final DateTime? expiryDate;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  bool get allowsProFeatures {
    if (!isEntitlementVerified) return false;
    return entitlementTier.includesPro &&
        (status == SubscriptionStatus.activePro ||
            status == SubscriptionStatus.activeMax ||
            status == SubscriptionStatus.inGracePeriodPro ||
            status == SubscriptionStatus.inGracePeriodMax);
  }

  bool get allowsMaxFeatures {
    if (!isEntitlementVerified) return false;
    return entitlementTier.includesMax &&
        (status == SubscriptionStatus.activeMax ||
            status == SubscriptionStatus.inGracePeriodMax);
  }

  bool get canUseCustomAvatar => allowsProFeatures;

  bool get hasProducts => products.isNotEmpty;

  bool get isBusy => isLoadingProducts || isPurchasing || isRestoring;

  ProductDetails? productFor(SubscriptionProductKind kind) => products[kind];

  SubscriptionSnapshot copyWith({
    SubscriptionStatus? status,
    Map<SubscriptionProductKind, ProductDetails>? products,
    SubscriptionEntitlementTier? entitlementTier,
    bool? isEntitlementVerified,
    bool? isLoadingProducts,
    bool? isPurchasing,
    bool? isRestoring,
    bool? isSyncing,
    String? productId,
    DateTime? expiryDate,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool clearProductId = false,
    bool clearExpiryDate = false,
    bool clearLastSyncedAt = false,
    bool clearError = false,
  }) {
    return SubscriptionSnapshot(
      status: status ?? this.status,
      products: products ?? this.products,
      entitlementTier: entitlementTier ?? this.entitlementTier,
      isEntitlementVerified:
          isEntitlementVerified ?? this.isEntitlementVerified,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isRestoring: isRestoring ?? this.isRestoring,
      isSyncing: isSyncing ?? this.isSyncing,
      productId: clearProductId ? null : productId ?? this.productId,
      expiryDate: clearExpiryDate ? null : expiryDate ?? this.expiryDate,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class SubscriptionService {
  const SubscriptionService._();

  static const String proYearlyProductId = SubscriptionProductIds.proYearly;
  static const String maxYearlyProductId = SubscriptionProductIds.maxYearly;

  static final ValueNotifier<SubscriptionSnapshot> notifier =
      ValueNotifier<SubscriptionSnapshot>(SubscriptionSnapshot.initial());

  static StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  static bool _initialized = false;

  static SubscriptionStoreGateway _storeGateway =
      InAppPurchaseSubscriptionStoreGateway();
  static SubscriptionVerificationRepository _verificationRepository =
      createDefaultSubscriptionVerificationRepository();
  static SubscriptionEntitlementCache _entitlementCache =
      const SharedPreferencesSubscriptionEntitlementCache();
  static SubscriptionIdentityStore _identityStore =
      SharedPreferencesSubscriptionIdentityStore();

  static SubscriptionSnapshot get snapshot => notifier.value;

  static bool get canUseCustomAvatar => snapshot.canUseCustomAvatar;

  static bool get allowsProFeatures => snapshot.allowsProFeatures;

  static bool get allowsMaxFeatures => snapshot.allowsMaxFeatures;

  static Future<void> init() async {
    if (!_initialized) {
      _purchaseSubscription = _storeGateway.purchaseStream.listen(
        handlePurchaseUpdates,
        onError: (Object error) {
          _setSnapshot(
            snapshot.copyWith(
              status: SubscriptionStatus.free,
              isEntitlementVerified: false,
              isPurchasing: false,
              isRestoring: false,
              errorMessage: '订阅交易监听失败：$error',
            ),
          );
        },
      );
      _initialized = true;
    }

    await syncSubscriptionStatus();
    await loadProducts();
  }

  static Future<void> loadProducts() async {
    _setSnapshot(snapshot.copyWith(isLoadingProducts: true, clearError: true));

    try {
      final available = await _storeGateway.isAvailable();
      if (!available) {
        _setSnapshot(
          snapshot.copyWith(
            status: SubscriptionStatus.free,
            isEntitlementVerified: false,
            products: const <SubscriptionProductKind, ProductDetails>{},
            isLoadingProducts: false,
            errorMessage: 'App Store 购买服务暂不可用',
          ),
        );
        return;
      }

      final response = await _storeGateway.queryProductDetails(
        SubscriptionProductIds.currentProductIds,
      );
      if (kDebugMode) {
        debugPrint(
          'IAP products loaded: found=${response.productDetails.map((product) => product.id).join(', ')} '
          'notFound=${response.notFoundIDs.join(', ')}',
        );
      }

      final products = <SubscriptionProductKind, ProductDetails>{};
      for (final product in response.productDetails) {
        switch (product.id) {
          case proYearlyProductId:
            products[SubscriptionProductKind.pro] = product;
            break;
          case maxYearlyProductId:
            products[SubscriptionProductKind.max] = product;
            break;
        }
      }

      final notFound = response.notFoundIDs;
      _setSnapshot(
        snapshot.copyWith(
          products: products,
          isLoadingProducts: false,
          errorMessage: notFound.isEmpty
              ? null
              : '订阅商品暂不可用，请确认 App Store Connect 已为当前 iOS App 配置订阅商品。',
          clearError: notFound.isEmpty,
        ),
      );
    } catch (error) {
      _setSnapshot(
        snapshot.copyWith(
          status: SubscriptionStatus.free,
          isEntitlementVerified: false,
          isLoadingProducts: false,
          errorMessage: '订阅商品加载失败：$error',
        ),
      );
    }
  }

  static Future<void> buySelectedProduct(SubscriptionProductKind kind) async {
    final product = snapshot.productFor(kind);
    if (product == null) {
      _setSnapshot(snapshot.copyWith(errorMessage: '当前订阅套餐不可购买，请稍后重试'));
      return;
    }

    _setSnapshot(
      snapshot.copyWith(
        status: SubscriptionStatus.pending,
        isEntitlementVerified: false,
        isPurchasing: true,
        clearError: true,
      ),
    );

    try {
      final appAccountToken = await _identityStore
          .readOrCreateAppAccountToken();
      final purchaseParam = PurchaseParam(productDetails: product);
      await _storeGateway.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: purchaseParam.productDetails,
          applicationUserName: appAccountToken,
        ),
      );
    } catch (error) {
      _setSnapshot(
        snapshot.copyWith(
          status: SubscriptionStatus.free,
          isEntitlementVerified: false,
          isPurchasing: false,
          errorMessage: '无法发起订阅购买：$error',
        ),
      );
    }
  }

  static Future<void> restorePurchases() async {
    _setSnapshot(
      snapshot.copyWith(
        status: SubscriptionStatus.pending,
        isEntitlementVerified: false,
        isRestoring: true,
        clearError: true,
      ),
    );

    try {
      final appAccountToken = await _identityStore
          .readOrCreateAppAccountToken();
      await _storeGateway.restorePurchases(
        applicationUserName: appAccountToken,
      );
    } catch (error) {
      _setSnapshot(
        snapshot.copyWith(
          status: SubscriptionStatus.free,
          isEntitlementVerified: false,
          isRestoring: false,
          errorMessage: '恢复购买失败：$error',
        ),
      );
    }
  }

  static Future<void> handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      var shouldCompletePurchase = false;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setSnapshot(
            snapshot.copyWith(
              status: SubscriptionStatus.pending,
              isEntitlementVerified: false,
              isPurchasing: false,
              isRestoring: false,
              clearError: true,
            ),
          );
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          shouldCompletePurchase = await _handleVerifiedPurchase(purchase);
          break;
        case PurchaseStatus.error:
          _setSnapshot(
            snapshot.copyWith(
              status: SubscriptionStatus.free,
              isEntitlementVerified: false,
              isPurchasing: false,
              isRestoring: false,
              errorMessage: purchase.error?.message ?? '订阅购买失败',
            ),
          );
          shouldCompletePurchase = true;
          break;
        case PurchaseStatus.canceled:
          _setSnapshot(
            snapshot.copyWith(
              status: SubscriptionStatus.free,
              isEntitlementVerified: false,
              isPurchasing: false,
              isRestoring: false,
              errorMessage: '已取消订阅购买',
            ),
          );
          shouldCompletePurchase = true;
          break;
      }

      if (purchase.pendingCompletePurchase && shouldCompletePurchase) {
        await _storeGateway.completePurchase(purchase);
      }
    }
  }

  static Future<void> syncSubscriptionStatus() async {
    _setSnapshot(snapshot.copyWith(isSyncing: true, clearError: true));

    final cached = await _entitlementCache.read();
    if (cached != null) {
      _setSnapshot(_snapshotFromCachedEntitlement(cached));
    }

    final entitlement = await _verificationRepository.fetchCurrentEntitlement();
    await _applyVerificationResult(entitlement);
  }

  static Future<bool> _handleVerifiedPurchase(PurchaseDetails purchase) async {
    final entitlement = await _verificationRepository.verifyPurchase(purchase);
    await _applyVerificationResult(
      entitlement,
      fallbackProductId: purchase.productID,
    );
    return _shouldCompletePurchase(entitlement);
  }

  static Future<void> _applyVerificationResult(
    VerifiedEntitlement entitlement, {
    String? fallbackProductId,
  }) async {
    final next = _snapshotFromVerifiedEntitlement(
      entitlement,
      fallbackProductId: fallbackProductId,
    );
    _setSnapshot(next);

    if (entitlement.isVerified) {
      await _entitlementCache.write(
        SubscriptionEntitlementCacheEntry.fromVerified(entitlement),
      );
    }
  }

  static SubscriptionSnapshot _snapshotFromCachedEntitlement(
    SubscriptionEntitlementCacheEntry cached,
  ) {
    return snapshot.copyWith(
      status: mapVerifiedEntitlementToStatus(cached.outcome),
      entitlementTier: cached.entitlementTier,
      isEntitlementVerified: false,
      isPurchasing: false,
      isRestoring: false,
      isSyncing: true,
      productId: cached.productId,
      expiryDate: cached.expiryDate,
      lastSyncedAt: cached.lastSyncedAt,
      clearError: true,
    );
  }

  static SubscriptionSnapshot _snapshotFromVerifiedEntitlement(
    VerifiedEntitlement entitlement, {
    String? fallbackProductId,
  }) {
    final status = mapVerifiedEntitlementToStatus(entitlement.outcome);
    final failed =
        entitlement.outcome ==
        SubscriptionVerificationOutcome.verificationFailed;
    final unavailable =
        entitlement.outcome ==
        SubscriptionVerificationOutcome.verificationUnavailable;

    return snapshot.copyWith(
      status: status,
      entitlementTier: entitlement.entitlementTier,
      isEntitlementVerified: entitlement.isVerified,
      isPurchasing: false,
      isRestoring: false,
      isSyncing: false,
      productId: entitlement.productId ?? fallbackProductId,
      expiryDate: entitlement.expiryDate,
      lastSyncedAt: entitlement.lastSyncedAt,
      clearProductId:
          entitlement.productId == null && fallbackProductId == null,
      clearExpiryDate: entitlement.expiryDate == null,
      errorMessage: failed || unavailable ? entitlement.reason : null,
      clearError: !(failed || unavailable),
    );
  }

  static SubscriptionStatus mapVerifiedEntitlementToStatus(
    SubscriptionVerificationOutcome outcome,
  ) {
    return switch (outcome) {
      SubscriptionVerificationOutcome.verifiedActivePro =>
        SubscriptionStatus.activePro,
      SubscriptionVerificationOutcome.verifiedActiveMax =>
        SubscriptionStatus.activeMax,
      SubscriptionVerificationOutcome.verifiedGracePeriodPro =>
        SubscriptionStatus.inGracePeriodPro,
      SubscriptionVerificationOutcome.verifiedGracePeriodMax =>
        SubscriptionStatus.inGracePeriodMax,
      SubscriptionVerificationOutcome.billingRetry =>
        SubscriptionStatus.billingRetry,
      SubscriptionVerificationOutcome.expired => SubscriptionStatus.expired,
      SubscriptionVerificationOutcome.revoked => SubscriptionStatus.revoked,
      SubscriptionVerificationOutcome.verificationFailed =>
        SubscriptionStatus.free,
      SubscriptionVerificationOutcome.verificationUnavailable =>
        SubscriptionStatus.free,
      SubscriptionVerificationOutcome.noActiveEntitlement =>
        SubscriptionStatus.noActiveEntitlement,
    };
  }

  static bool _shouldCompletePurchase(VerifiedEntitlement entitlement) {
    return entitlement.outcome !=
        SubscriptionVerificationOutcome.verificationUnavailable;
  }

  static void _setSnapshot(SubscriptionSnapshot next) {
    notifier.value = next;
  }

  @visibleForTesting
  static void resetForTest() {
    assert(() {
      _purchaseSubscription?.cancel();
      _purchaseSubscription = null;
      _initialized = false;
      _storeGateway = const UnavailableSubscriptionStoreGateway();
      _verificationRepository =
          createDefaultSubscriptionVerificationRepository();
      _entitlementCache = const SharedPreferencesSubscriptionEntitlementCache();
      _identityStore = SharedPreferencesSubscriptionIdentityStore();
      notifier.value = SubscriptionSnapshot.initial();
      return true;
    }());
  }

  @visibleForTesting
  static void configureForTest({
    SubscriptionStoreGateway? storeGateway,
    SubscriptionVerificationRepository? verificationRepository,
    SubscriptionEntitlementCache? entitlementCache,
    SubscriptionIdentityStore? identityStore,
  }) {
    assert(() {
      if (storeGateway != null) {
        _storeGateway = storeGateway;
      }
      if (verificationRepository != null) {
        _verificationRepository = verificationRepository;
      }
      if (entitlementCache != null) {
        _entitlementCache = entitlementCache;
      }
      if (identityStore != null) {
        _identityStore = identityStore;
      }
      return true;
    }());
  }

  @visibleForTesting
  static void setStatusForTest(SubscriptionStatus status) {
    assert(() {
      notifier.value = snapshot.copyWith(
        status: status,
        entitlementTier: _tierForStatus(status),
        isEntitlementVerified: true,
        clearError: true,
      );
      return true;
    }());
  }

  static SubscriptionEntitlementTier _tierForStatus(SubscriptionStatus status) {
    return switch (status) {
      SubscriptionStatus.activePro ||
      SubscriptionStatus.inGracePeriodPro => SubscriptionEntitlementTier.pro,
      SubscriptionStatus.activeMax ||
      SubscriptionStatus.inGracePeriodMax => SubscriptionEntitlementTier.max,
      _ => SubscriptionEntitlementTier.none,
    };
  }
}
