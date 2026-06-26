import 'dart:async';

import 'package:asset_ledger/app/app_review_demo_account.dart';
import 'package:asset_ledger/core/config/subscription_product_ids.dart';
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
      SubscriptionService.setStatusForTest(SubscriptionStatus.activePro);

      expect(SubscriptionService.effectivePlan, SubscriptionEffectivePlan.pro);
      expect(SubscriptionService.isProActive, isTrue);
      expect(SubscriptionService.isMaxActive, isFalse);
      expect(SubscriptionService.canUseCustomAvatar, isTrue);
      expect(SubscriptionService.allowsProFeatures, isTrue);
      expect(SubscriptionService.allowsMaxFeatures, isFalse);
      expect(SubscriptionService.canUseUnlimitedTimingRecords, isTrue);
      expect(SubscriptionService.canCreateMoreTimingRecords(31), isTrue);
      expect(SubscriptionService.canUseCloudBackup, isFalse);
      expect(SubscriptionService.canUseCloudRestore, isFalse);
      expect(SubscriptionService.canUseLocalExport, isTrue);
      expect(SubscriptionService.canUseLocalRestore, isTrue);

      SubscriptionService.setStatusForTest(SubscriptionStatus.activeMax);

      expect(SubscriptionService.effectivePlan, SubscriptionEffectivePlan.max);
      expect(SubscriptionService.isProActive, isTrue);
      expect(SubscriptionService.isMaxActive, isTrue);
      expect(SubscriptionService.canUseCustomAvatar, isTrue);
      expect(SubscriptionService.allowsProFeatures, isTrue);
      expect(SubscriptionService.allowsMaxFeatures, isTrue);
      expect(SubscriptionService.canUseUnlimitedTimingRecords, isTrue);
      expect(SubscriptionService.canCreateMoreTimingRecords(31), isTrue);
      expect(SubscriptionService.canUseCloudBackup, isTrue);
      expect(SubscriptionService.canUseCloudRestore, isTrue);
      expect(SubscriptionService.canUseLocalExport, isTrue);
      expect(SubscriptionService.canUseLocalRestore, isTrue);

      SubscriptionService.setStatusForTest(SubscriptionStatus.free);

      expect(SubscriptionService.effectivePlan, SubscriptionEffectivePlan.free);
      expect(SubscriptionService.isProActive, isFalse);
      expect(SubscriptionService.isMaxActive, isFalse);
      expect(SubscriptionService.canUseCustomAvatar, isFalse);
      expect(SubscriptionService.allowsProFeatures, isFalse);
      expect(SubscriptionService.allowsMaxFeatures, isFalse);
      expect(SubscriptionService.canUseUnlimitedTimingRecords, isFalse);
      expect(SubscriptionService.canCreateMoreTimingRecords(29), isTrue);
      expect(SubscriptionService.canCreateMoreTimingRecords(30), isFalse);
      expect(SubscriptionService.canCreateMoreTimingRecords(31), isFalse);
      expect(SubscriptionService.canUseCloudBackup, isFalse);
      expect(SubscriptionService.canUseCloudRestore, isFalse);
      expect(SubscriptionService.canUseLocalExport, isTrue);
      expect(SubscriptionService.canUseLocalRestore, isTrue);
    });

    test('pending and revoked states do not unlock pro capabilities', () {
      SubscriptionService.setStatusForTest(SubscriptionStatus.pending);

      expect(SubscriptionService.canUseCustomAvatar, isFalse);

      SubscriptionService.setStatusForTest(SubscriptionStatus.revoked);

      expect(SubscriptionService.canUseCustomAvatar, isFalse);
    });

    test('app review demo auth token does not unlock subscription', () {
      SubscriptionService.setStatusForTest(SubscriptionStatus.free);

      expect(AppReviewDemoAccount.authToken, isNotEmpty);
      expect(SubscriptionService.snapshot.status, SubscriptionStatus.free);
      expect(SubscriptionService.canUseCustomAvatar, isFalse);
      expect(SubscriptionService.allowsProFeatures, isFalse);
      expect(SubscriptionService.allowsMaxFeatures, isFalse);
    });

    test(
      'missing store products shows operator guidance without product ids',
      () async {
        storeGateway.productDetailsResponse = ProductDetailsResponse(
          productDetails: const [],
          notFoundIDs: const [
            SubscriptionService.proYearlyProductId,
            SubscriptionService.maxYearlyProductId,
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
            id: SubscriptionService.proYearlyProductId,
            price: '¥6.00',
          ),
          productDetails(
            id: SubscriptionService.maxYearlyProductId,
            price: '¥24.00',
          ),
        ],
        notFoundIDs: const [],
      );

      await SubscriptionService.loadProducts();

      expect(
        SubscriptionService.snapshot
            .productFor(SubscriptionProductKind.pro)
            ?.price,
        '¥6.00',
      );
      expect(
        SubscriptionService.snapshot
            .productFor(SubscriptionProductKind.max)
            ?.price,
        '¥24.00',
      );
      expect(SubscriptionService.snapshot.errorMessage, isNull);
    });

    test('current product ids have explicit tier and duration metadata', () {
      expect(
        SubscriptionProductIds.definitionFor(
          SubscriptionService.proYearlyProductId,
        ),
        isA<SubscriptionProductDefinition>()
            .having(
              (definition) => definition.tier,
              'tier',
              SubscriptionTier.pro,
            )
            .having(
              (definition) => definition.duration,
              'duration',
              SubscriptionDuration.yearly,
            ),
      );
      expect(
        SubscriptionProductIds.definitionFor(
          SubscriptionService.maxYearlyProductId,
        ),
        isA<SubscriptionProductDefinition>()
            .having(
              (definition) => definition.tier,
              'tier',
              SubscriptionTier.max,
            )
            .having(
              (definition) => definition.duration,
              'duration',
              SubscriptionDuration.yearly,
            ),
      );
      expect(SubscriptionProductIds.currentProductIds, {
        SubscriptionService.proYearlyProductId,
        SubscriptionService.maxYearlyProductId,
      });
      expect(SubscriptionProductIds.definitionFor('unknown.product'), isNull);
    });

    test('purchase and restore attach the stable appAccountToken', () async {
      storeGateway.productDetailsResponse = ProductDetailsResponse(
        productDetails: [
          productDetails(
            id: SubscriptionService.proYearlyProductId,
            price: '¥6.00',
          ),
        ],
        notFoundIDs: const [],
      );

      await SubscriptionService.loadProducts();
      await SubscriptionService.buySelectedProduct(SubscriptionProductKind.pro);
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

    test('restore verifies purchases returned by the restore call', () async {
      verificationRepository.purchaseResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedActivePro,
        entitlementTier: SubscriptionEntitlementTier.pro,
        productId: SubscriptionService.proYearlyProductId,
      );
      storeGateway.restoredPurchases = [
        purchaseDetails(
          productId: SubscriptionService.proYearlyProductId,
          status: PurchaseStatus.restored,
        ),
      ];

      final outcome = await SubscriptionService.restorePurchases();

      expect(outcome, const SubscriptionRestoreOutcome.restoredPro());
      expect(SubscriptionService.snapshot.status, SubscriptionStatus.activePro);
      expect(SubscriptionService.allowsProFeatures, isTrue);
      expect(verificationRepository.verifiedPurchases, hasLength(1));
      expect(
        verificationRepository.verifiedPurchases.single.productID,
        SubscriptionService.proYearlyProductId,
      );
      expect(verificationRepository.currentFetchCount, 0);
    });

    test(
      'restore prefers max when multiple restored subscriptions arrive',
      () async {
        verificationRepository.purchaseResults = {
          SubscriptionService.proYearlyProductId: VerifiedEntitlement(
            outcome: SubscriptionVerificationOutcome.verifiedActivePro,
            entitlementTier: SubscriptionEntitlementTier.pro,
            productId: SubscriptionService.proYearlyProductId,
          ),
          SubscriptionService.maxYearlyProductId: VerifiedEntitlement(
            outcome: SubscriptionVerificationOutcome.verifiedActiveMax,
            entitlementTier: SubscriptionEntitlementTier.max,
            productId: SubscriptionService.maxYearlyProductId,
          ),
        };
        storeGateway.restoredPurchases = [
          purchaseDetails(
            productId: SubscriptionService.proYearlyProductId,
            status: PurchaseStatus.restored,
          ),
          purchaseDetails(
            productId: SubscriptionService.maxYearlyProductId,
            status: PurchaseStatus.restored,
          ),
        ];

        final outcome = await SubscriptionService.restorePurchases();

        expect(outcome, const SubscriptionRestoreOutcome.restoredMax());
        expect(
          SubscriptionService.snapshot.status,
          SubscriptionStatus.activeMax,
        );
        expect(
          verificationRepository.verifiedPurchases.first.productID,
          SubscriptionService.maxYearlyProductId,
        );
      },
    );

    test(
      'restore falls back to current entitlement when no purchases arrive',
      () async {
        verificationRepository.currentResult = VerifiedEntitlement(
          outcome: SubscriptionVerificationOutcome.noActiveEntitlement,
        );

        final outcome = await SubscriptionService.restorePurchases();

        expect(outcome, const SubscriptionRestoreOutcome.noActivePurchase());
        expect(
          SubscriptionService.snapshot.status,
          SubscriptionStatus.noActiveEntitlement,
        );
        expect(SubscriptionService.snapshot.isRestoring, isFalse);
        expect(verificationRepository.currentFetchCount, 1);
        expect(verificationRepository.verifiedPurchases, isEmpty);
      },
    );

    test('restore returns failed outcome for verification failure', () async {
      verificationRepository.currentResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verificationFailed,
        reason: 'invalid receipt',
      );

      final outcome = await SubscriptionService.restorePurchases();

      expect(
        outcome,
        const SubscriptionRestoreOutcome.failed('invalid receipt'),
      );
      expect(SubscriptionService.snapshot.status, SubscriptionStatus.free);
      expect(SubscriptionService.snapshot.errorMessage, 'invalid receipt');
    });

    test(
      'restore returns unavailable outcome for verification outage',
      () async {
        verificationRepository.currentResult = VerifiedEntitlement(
          outcome: SubscriptionVerificationOutcome.verificationUnavailable,
          reason: 'server unavailable',
        );

        final outcome = await SubscriptionService.restorePurchases();

        expect(
          outcome,
          const SubscriptionRestoreOutcome.unavailable('server unavailable'),
        );
        expect(SubscriptionService.snapshot.status, SubscriptionStatus.free);
        expect(SubscriptionService.snapshot.errorMessage, 'server unavailable');
      },
    );

    test('restore falls back when the store gateway hangs', () async {
      verificationRepository.currentResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedActivePro,
        entitlementTier: SubscriptionEntitlementTier.pro,
        productId: SubscriptionService.proYearlyProductId,
      );
      storeGateway.restoreCompleter = Completer<List<PurchaseDetails>>();
      SubscriptionService.configureForTest(
        storeGateway: storeGateway,
        verificationRepository: verificationRepository,
        entitlementCache: entitlementCache,
        identityStore: identityStore,
        restoreGatewayTimeout: const Duration(milliseconds: 1),
      );

      final outcome = await SubscriptionService.restorePurchases();

      expect(outcome, const SubscriptionRestoreOutcome.restoredPro());
      expect(SubscriptionService.snapshot.status, SubscriptionStatus.activePro);
      expect(SubscriptionService.allowsProFeatures, isTrue);
      expect(verificationRepository.currentFetchCount, 1);
      expect(verificationRepository.verifiedPurchases, isEmpty);
    });

    test('restore catch branch returns failed outcome', () async {
      storeGateway.restoreError = StateError('store restore failed');

      final outcome = await SubscriptionService.restorePurchases();

      expect(outcome.kind, SubscriptionRestoreOutcomeKind.failed);
      expect(outcome.reason, contains('恢复购买失败：Bad state'));
      expect(SubscriptionService.snapshot.status, SubscriptionStatus.free);
      expect(SubscriptionService.snapshot.errorMessage, outcome.reason);
    });

    test('purchased but verificationFailed does not unlock pro', () async {
      verificationRepository.purchaseResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verificationFailed,
        productId: SubscriptionService.proYearlyProductId,
        reason: 'invalid receipt',
      );

      await SubscriptionService.handlePurchaseUpdates([
        purchaseDetails(
          productId: SubscriptionService.proYearlyProductId,
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
          productId: SubscriptionService.maxYearlyProductId,
          reason: 'server unavailable',
        );

        await SubscriptionService.handlePurchaseUpdates([
          purchaseDetails(
            productId: SubscriptionService.maxYearlyProductId,
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

    test('verifiedActivePro allows custom avatar', () async {
      verificationRepository.purchaseResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedActivePro,
        entitlementTier: SubscriptionEntitlementTier.pro,
        productId: SubscriptionService.proYearlyProductId,
      );

      await SubscriptionService.handlePurchaseUpdates([
        purchaseDetails(
          productId: SubscriptionService.proYearlyProductId,
          status: PurchaseStatus.purchased,
          pendingCompletePurchase: true,
        ),
      ]);

      expect(SubscriptionService.snapshot.status, SubscriptionStatus.activePro);
      expect(
        SubscriptionService.snapshot.entitlementTier,
        SubscriptionEntitlementTier.pro,
      );
      expect(SubscriptionService.snapshot.isEntitlementVerified, isTrue);
      expect(SubscriptionService.canUseCustomAvatar, isTrue);
      expect(SubscriptionService.allowsMaxFeatures, isFalse);
      expect(
        entitlementCache.entry?.outcome,
        SubscriptionVerificationOutcome.verifiedActivePro,
      );
      expect(
        entitlementCache.entry?.entitlementTier,
        SubscriptionEntitlementTier.pro,
      );
      expect(storeGateway.completedPurchases, hasLength(1));
    });

    test('verifiedActiveMax unlocks max and includes pro', () async {
      verificationRepository.purchaseResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedActiveMax,
        entitlementTier: SubscriptionEntitlementTier.max,
        productId: SubscriptionService.maxYearlyProductId,
      );

      await SubscriptionService.handlePurchaseUpdates([
        purchaseDetails(
          productId: SubscriptionService.maxYearlyProductId,
          status: PurchaseStatus.purchased,
          pendingCompletePurchase: true,
        ),
      ]);

      expect(SubscriptionService.snapshot.status, SubscriptionStatus.activeMax);
      expect(
        SubscriptionService.snapshot.entitlementTier,
        SubscriptionEntitlementTier.max,
      );
      expect(SubscriptionService.allowsProFeatures, isTrue);
      expect(SubscriptionService.allowsMaxFeatures, isTrue);
      expect(storeGateway.completedPurchases, hasLength(1));
    });

    test('expired forbids custom avatar', () async {
      verificationRepository.purchaseResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.expired,
        productId: SubscriptionService.proYearlyProductId,
      );

      await SubscriptionService.handlePurchaseUpdates([
        purchaseDetails(
          productId: SubscriptionService.proYearlyProductId,
          status: PurchaseStatus.purchased,
        ),
      ]);

      expect(SubscriptionService.snapshot.status, SubscriptionStatus.expired);
      expect(SubscriptionService.snapshot.isEntitlementVerified, isTrue);
      expect(SubscriptionService.canUseCustomAvatar, isFalse);
    });

    test('startup sync revokes cached active when verified expired', () async {
      entitlementCache.entry = SubscriptionEntitlementCacheEntry(
        outcome: SubscriptionVerificationOutcome.verifiedActivePro,
        entitlementTier: SubscriptionEntitlementTier.pro,
        productId: SubscriptionService.proYearlyProductId,
        expiryDate: DateTime(2099),
        lastSyncedAt: DateTime(2026),
      );
      verificationRepository.currentResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.expired,
        productId: SubscriptionService.proYearlyProductId,
        expiryDate: DateTime(2025),
      );

      await SubscriptionService.syncSubscriptionStatus();

      expect(SubscriptionService.snapshot.status, SubscriptionStatus.expired);
      expect(SubscriptionService.snapshot.isEntitlementVerified, isTrue);
      expect(SubscriptionService.canUseCustomAvatar, isFalse);
      expect(
        entitlementCache.entry?.outcome,
        SubscriptionVerificationOutcome.expired,
      );
    });

    test('current entitlement restores pro entitlement', () async {
      verificationRepository.currentResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedActivePro,
        entitlementTier: SubscriptionEntitlementTier.pro,
        productId: SubscriptionService.proYearlyProductId,
      );

      await SubscriptionService.syncSubscriptionStatus();

      expect(SubscriptionService.snapshot.status, SubscriptionStatus.activePro);
      expect(SubscriptionService.allowsProFeatures, isTrue);
      expect(SubscriptionService.allowsMaxFeatures, isFalse);
    });

    test('current entitlement restores max entitlement', () async {
      verificationRepository.currentResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedActiveMax,
        entitlementTier: SubscriptionEntitlementTier.max,
        productId: SubscriptionService.maxYearlyProductId,
      );

      await SubscriptionService.syncSubscriptionStatus();

      expect(SubscriptionService.snapshot.status, SubscriptionStatus.activeMax);
      expect(SubscriptionService.allowsProFeatures, isTrue);
      expect(SubscriptionService.allowsMaxFeatures, isTrue);
    });

    test('restored and verified purchase enables entitlement', () async {
      verificationRepository.purchaseResult = VerifiedEntitlement(
        outcome: SubscriptionVerificationOutcome.verifiedActiveMax,
        entitlementTier: SubscriptionEntitlementTier.max,
        productId: SubscriptionService.maxYearlyProductId,
      );

      await SubscriptionService.handlePurchaseUpdates([
        purchaseDetails(
          productId: SubscriptionService.maxYearlyProductId,
          status: PurchaseStatus.restored,
        ),
      ]);

      expect(SubscriptionService.snapshot.status, SubscriptionStatus.activeMax);
      expect(SubscriptionService.canUseCustomAvatar, isTrue);
      expect(SubscriptionService.allowsMaxFeatures, isTrue);
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
  final verifiedPurchases = <PurchaseDetails>[];
  var currentFetchCount = 0;

  VerifiedEntitlement purchaseResult = VerifiedEntitlement(
    outcome: SubscriptionVerificationOutcome.verificationFailed,
    reason: 'unset purchase result',
  );

  Map<String, VerifiedEntitlement>? purchaseResults;

  VerifiedEntitlement currentResult = VerifiedEntitlement(
    outcome: SubscriptionVerificationOutcome.verificationUnavailable,
    reason: 'unset current result',
  );

  @override
  Future<VerifiedEntitlement> verifyPurchase(PurchaseDetails purchase) async {
    verifiedPurchases.add(purchase);
    return purchaseResults?[purchase.productID] ?? purchaseResult;
  }

  @override
  Future<VerifiedEntitlement> fetchCurrentEntitlement() async {
    currentFetchCount++;
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

  @override
  Future<void> writeAppAccountToken(String token) async {
    this.token = token;
  }
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
  List<PurchaseDetails> restoredPurchases = const <PurchaseDetails>[];
  Completer<List<PurchaseDetails>>? restoreCompleter;
  Object? restoreError;
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
  Future<List<PurchaseDetails>> restorePurchases({
    String? applicationUserName,
  }) async {
    restoreCallCount++;
    lastRestoreApplicationUserName = applicationUserName;
    final error = restoreError;
    if (error != null) throw error;
    final completer = restoreCompleter;
    if (completer != null) return completer.future;
    return restoredPurchases;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }
}
