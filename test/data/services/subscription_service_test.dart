import 'dart:async';

import 'package:asset_ledger/data/services/subscription_entitlement_cache.dart';
import 'package:asset_ledger/data/services/subscription_identity_store.dart';
import 'package:asset_ledger/data/services/subscription_service.dart';
import 'package:asset_ledger/data/services/subscription_store_gateway.dart';
import 'package:asset_ledger/data/services/subscription_verification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  late FakeVerificationRepository verificationRepository;
  late MemoryEntitlementCache entitlementCache;
  late MemoryIdentityStore identityStore;
  late FakeSubscriptionStoreGateway storeGateway;

  setUp(() {
    verificationRepository = FakeVerificationRepository();
    entitlementCache = MemoryEntitlementCache();
    identityStore = MemoryIdentityStore('00000000-0000-4000-8000-000000000001');
    storeGateway = FakeSubscriptionStoreGateway();
    SubscriptionService.configureForTest(
      storeGateway: storeGateway,
      verificationRepository: verificationRepository,
      entitlementCache: entitlementCache,
      identityStore: identityStore,
    );
  });

  tearDown(() {
    SubscriptionService.resetForTest();
  });

  group('SubscriptionService', () {
    test('status model controls capability flags', () {
      SubscriptionService.setStatusForTest(SubscriptionStatus.activeMonthly);

      expect(SubscriptionService.canUseCustomAvatar, isTrue);
      expect(SubscriptionService.allowsProFeatures, isTrue);

      SubscriptionService.setStatusForTest(SubscriptionStatus.free);

      expect(SubscriptionService.canUseCustomAvatar, isFalse);
      expect(SubscriptionService.allowsProFeatures, isFalse);
    });

    test('pending and revoked states do not unlock pro capabilities', () {
      SubscriptionService.setStatusForTest(SubscriptionStatus.pending);

      expect(SubscriptionService.canUseCustomAvatar, isFalse);

      SubscriptionService.setStatusForTest(SubscriptionStatus.revoked);

      expect(SubscriptionService.canUseCustomAvatar, isFalse);
    });

    test(
      'missing store products shows operator guidance without product ids',
      () async {
        storeGateway.productDetailsResponse = ProductDetailsResponse(
          productDetails: const [],
          notFoundIDs: const [
            SubscriptionService.monthlyProductId,
            SubscriptionService.yearlyProductId,
          ],
        );

        await SubscriptionService.loadProducts();

        expect(SubscriptionService.snapshot.products, isEmpty);
        expect(
          SubscriptionService.snapshot.errorMessage,
          '订阅商品暂不可用，请确认 App Store Connect 已为当前 iOS App 配置订阅商品。',
        );
        expect(
          SubscriptionService.snapshot.errorMessage,
          isNot(contains('com.yuyuan')),
        );
      },
    );

    test('loaded store products are mapped by subscription kind', () async {
      storeGateway.productDetailsResponse = ProductDetailsResponse(
        productDetails: [
          productDetails(
            id: SubscriptionService.monthlyProductId,
            price: '¥1.00',
          ),
          productDetails(
            id: SubscriptionService.yearlyProductId,
            price: '¥6.00',
          ),
        ],
        notFoundIDs: const [],
      );

      await SubscriptionService.loadProducts();

      expect(
        SubscriptionService.snapshot
            .productFor(SubscriptionProductKind.monthly)
            ?.price,
        '¥1.00',
      );
      expect(
        SubscriptionService.snapshot
            .productFor(SubscriptionProductKind.yearly)
            ?.price,
        '¥6.00',
      );
      expect(SubscriptionService.snapshot.errorMessage, isNull);
    });

    test('purchase and restore attach the stable appAccountToken', () async {
      storeGateway.productDetailsResponse = ProductDetailsResponse(
        productDetails: [
          productDetails(
            id: SubscriptionService.yearlyProductId,
            price: '¥6.00',
          ),
        ],
        notFoundIDs: const [],
      );

      await SubscriptionService.loadProducts();
      await SubscriptionService.buySelectedProduct(
        SubscriptionProductKind.yearly,
      );
      await SubscriptionService.restorePurchases();

      expect(
        storeGateway.lastPurchaseParam?.applicationUserName,
        '00000000-0000-4000-8000-000000000001',
      );
      expect(
        storeGateway.lastRestoreApplicationUserName,
        '00000000-0000-4000-8000-000000000001',
      );
    });

    test('purchased but verificationFailed does not unlock pro', () async {
      verificationRepository.purchaseResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verificationFailed,
        productId: SubscriptionService.monthlyProductId,
        reason: 'invalid receipt',
      );

      await SubscriptionService.handlePurchaseUpdates([
        purchaseDetails(
          productId: SubscriptionService.monthlyProductId,
          status: PurchaseStatus.purchased,
          pendingCompletePurchase: true,
        ),
      ]);

      expect(SubscriptionService.snapshot.status, SubscriptionStatus.free);
      expect(SubscriptionService.canUseCustomAvatar, isFalse);
      expect(entitlementCache.entry, isNull);
      expect(storeGateway.completedPurchases, hasLength(1));
    });

    test(
      'restored but verificationUnavailable does not unlock or complete',
      () async {
        verificationRepository.purchaseResult = VerifiedEntitlement(
          outcome: SubscriptionVerificationOutcome.verificationUnavailable,
          productId: SubscriptionService.yearlyProductId,
          reason: 'server unavailable',
        );

        await SubscriptionService.handlePurchaseUpdates([
          purchaseDetails(
            productId: SubscriptionService.yearlyProductId,
            status: PurchaseStatus.restored,
            pendingCompletePurchase: true,
          ),
        ]);

        expect(SubscriptionService.snapshot.status, SubscriptionStatus.free);
        expect(SubscriptionService.canUseCustomAvatar, isFalse);
        expect(entitlementCache.entry, isNull);
        expect(storeGateway.completedPurchases, isEmpty);
      },
    );

    test('verifiedActiveMonthly allows custom avatar', () async {
      verificationRepository.purchaseResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedActiveMonthly,
        productId: SubscriptionService.monthlyProductId,
      );

      await SubscriptionService.handlePurchaseUpdates([
        purchaseDetails(
          productId: SubscriptionService.monthlyProductId,
          status: PurchaseStatus.purchased,
          pendingCompletePurchase: true,
        ),
      ]);

      expect(
        SubscriptionService.snapshot.status,
        SubscriptionStatus.activeMonthly,
      );
      expect(SubscriptionService.snapshot.isEntitlementVerified, isTrue);
      expect(SubscriptionService.canUseCustomAvatar, isTrue);
      expect(
        entitlementCache.entry?.outcome,
        SubscriptionVerificationOutcome.verifiedActiveMonthly,
      );
      expect(storeGateway.completedPurchases, hasLength(1));
    });

    test('verifiedExpired forbids custom avatar', () async {
      verificationRepository.purchaseResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedExpired,
        productId: SubscriptionService.monthlyProductId,
      );

      await SubscriptionService.handlePurchaseUpdates([
        purchaseDetails(
          productId: SubscriptionService.monthlyProductId,
          status: PurchaseStatus.purchased,
        ),
      ]);

      expect(SubscriptionService.snapshot.status, SubscriptionStatus.expired);
      expect(SubscriptionService.snapshot.isEntitlementVerified, isTrue);
      expect(SubscriptionService.canUseCustomAvatar, isFalse);
    });

    test('startup sync revokes cached active when verified expired', () async {
      entitlementCache.entry = SubscriptionEntitlementCacheEntry(
        outcome: SubscriptionVerificationOutcome.verifiedActiveMonthly,
        productId: SubscriptionService.monthlyProductId,
        expiryDate: DateTime(2099),
        lastSyncedAt: DateTime(2026),
      );
      verificationRepository.currentResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedExpired,
        productId: SubscriptionService.monthlyProductId,
        expiryDate: DateTime(2025),
      );

      await SubscriptionService.syncSubscriptionStatus();

      expect(SubscriptionService.snapshot.status, SubscriptionStatus.expired);
      expect(SubscriptionService.snapshot.isEntitlementVerified, isTrue);
      expect(SubscriptionService.canUseCustomAvatar, isFalse);
      expect(
        entitlementCache.entry?.outcome,
        SubscriptionVerificationOutcome.verifiedExpired,
      );
    });

    test('restored and verified purchase enables entitlement', () async {
      verificationRepository.purchaseResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedActiveYearly,
        productId: SubscriptionService.yearlyProductId,
      );

      await SubscriptionService.handlePurchaseUpdates([
        purchaseDetails(
          productId: SubscriptionService.yearlyProductId,
          status: PurchaseStatus.restored,
        ),
      ]);

      expect(
        SubscriptionService.snapshot.status,
        SubscriptionStatus.activeYearly,
      );
      expect(SubscriptionService.canUseCustomAvatar, isTrue);
    });
  });
}

PurchaseDetails purchaseDetails({
  required String productId,
  required PurchaseStatus status,
  bool pendingCompletePurchase = false,
}) {
  final purchase = PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-$productId',
      serverVerificationData: 'server-$productId',
      source: 'app_store',
    ),
    transactionDate: '1700000000000',
    status: status,
  );
  purchase.pendingCompletePurchase = pendingCompletePurchase;
  return purchase;
}

ProductDetails productDetails({required String id, required String price}) {
  return ProductDetails(
    id: id,
    title: id,
    description: '',
    price: price,
    rawPrice: double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
    currencyCode: 'CNY',
    currencySymbol: '¥',
  );
}

class FakeVerificationRepository implements SubscriptionVerificationRepository {
  VerifiedEntitlement purchaseResult = VerifiedEntitlement(
    outcome: SubscriptionVerificationOutcome.verificationFailed,
    reason: 'unset purchase result',
  );

  VerifiedEntitlement currentResult = VerifiedEntitlement(
    outcome: SubscriptionVerificationOutcome.verificationUnavailable,
    reason: 'unset current result',
  );

  @override
  Future<VerifiedEntitlement> verifyPurchase(PurchaseDetails purchase) async {
    return purchaseResult;
  }

  @override
  Future<VerifiedEntitlement> fetchCurrentEntitlement() async {
    return currentResult;
  }
}

class MemoryEntitlementCache implements SubscriptionEntitlementCache {
  SubscriptionEntitlementCacheEntry? entry;

  @override
  Future<void> clear() async {
    entry = null;
  }

  @override
  Future<SubscriptionEntitlementCacheEntry?> read() async => entry;

  @override
  Future<void> write(SubscriptionEntitlementCacheEntry entry) async {
    this.entry = entry;
  }
}

class MemoryIdentityStore implements SubscriptionIdentityStore {
  MemoryIdentityStore(this.token);

  String token;

  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAppAccountToken() async => token;

  @override
  Future<String> readOrCreateAppAccountToken() async => token;
}

class FakeSubscriptionStoreGateway implements SubscriptionStoreGateway {
  final completedPurchases = <PurchaseDetails>[];
  final purchaseController =
      StreamController<List<PurchaseDetails>>.broadcast();

  bool available = true;
  ProductDetailsResponse productDetailsResponse = ProductDetailsResponse(
    productDetails: const [],
    notFoundIDs: const [],
  );
  PurchaseParam? lastPurchaseParam;
  String? lastRestoreApplicationUserName;
  var restoreCallCount = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchaseController.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return productDetailsResponse;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    lastPurchaseParam = purchaseParam;
    return true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCallCount++;
    lastRestoreApplicationUserName = applicationUserName;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }
}
