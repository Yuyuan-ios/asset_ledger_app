import 'dart:async';

import 'package:asset_ledger/core/config/app_environment.dart';
import 'package:asset_ledger/data/services/subscription_entitlement_cache.dart';
import 'package:asset_ledger/data/services/subscription_identity_store.dart';
import 'package:asset_ledger/data/services/subscription_service.dart';
import 'package:asset_ledger/data/services/subscription_store_gateway.dart';
import 'package:asset_ledger/data/services/subscription_verification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  tearDown(() {
    RuntimeGate.resetForTest();
    SubscriptionService.resetForTest();
  });

  test(
    'sandbox and demo access force max without StoreKit or backend calls',
    () async {
      for (final mode in [RuntimeAccessMode.sandbox, RuntimeAccessMode.demo]) {
        RuntimeGate.setAccessModeForTest(mode);
        final storeGateway = _CountingSubscriptionStoreGateway();
        final verificationRepository = _CountingVerificationRepository();
        SubscriptionService.configureForTest(
          storeGateway: storeGateway,
          verificationRepository: verificationRepository,
          entitlementCache: _MemoryEntitlementCache(),
          identityStore: _MemoryIdentityStore(),
        );

        await SubscriptionService.init();
        final restoreOutcome = await SubscriptionService.restorePurchases();
        await SubscriptionService.buySelectedProduct(
          SubscriptionProductKind.pro,
        );
        await SubscriptionService.syncSubscriptionStatus();

        expect(
          SubscriptionService.snapshot.status,
          SubscriptionStatus.activeMax,
        );
        expect(
          SubscriptionService.snapshot.entitlementTier,
          SubscriptionEntitlementTier.max,
        );
        expect(SubscriptionService.snapshot.isEntitlementVerified, isTrue);
        expect(SubscriptionService.allowsProFeatures, isTrue);
        expect(SubscriptionService.allowsMaxFeatures, isTrue);
        expect(restoreOutcome, const SubscriptionRestoreOutcome.restoredMax());
        expect(storeGateway.calls, 0);
        expect(verificationRepository.calls, 0);
        SubscriptionService.resetForTest();
      }
    },
  );

  test('review account sandbox access forces max entitlement', () async {
    RuntimeGate.resolveAccessForAccount(
      accountIdentifier: 'review@example.com',
      isAuthenticated: true,
      reviewAccessPolicy: const ReviewAccessPolicy(
        enabled: true,
        emails: {'review@example.com'},
      ),
    );
    final storeGateway = _CountingSubscriptionStoreGateway();
    final verificationRepository = _CountingVerificationRepository();
    SubscriptionService.configureForTest(
      storeGateway: storeGateway,
      verificationRepository: verificationRepository,
      entitlementCache: _MemoryEntitlementCache(),
      identityStore: _MemoryIdentityStore(),
    );

    await SubscriptionService.init();

    expect(RuntimeGate.isSandboxAccess, isTrue);
    expect(SubscriptionService.snapshot.status, SubscriptionStatus.activeMax);
    expect(SubscriptionService.snapshot.isEntitlementVerified, isTrue);
    expect(storeGateway.calls, 0);
    expect(verificationRepository.calls, 0);
  });
}

class _CountingSubscriptionStoreGateway implements SubscriptionStoreGateway {
  var calls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async {
    calls++;
    return true;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    calls++;
    return ProductDetailsResponse(
      productDetails: const [],
      notFoundIDs: identifiers.toList(growable: false),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    calls++;
    return true;
  }

  @override
  Future<List<PurchaseDetails>> restorePurchases({
    String? applicationUserName,
  }) async {
    calls++;
    return const <PurchaseDetails>[];
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    calls++;
  }
}

class _CountingVerificationRepository
    implements SubscriptionVerificationRepository {
  var calls = 0;

  @override
  Future<VerifiedEntitlement> verifyPurchase(PurchaseDetails purchase) async {
    calls++;
    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.verificationFailed,
    );
  }

  @override
  Future<VerifiedEntitlement> fetchCurrentEntitlement() async {
    calls++;
    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.verificationFailed,
    );
  }
}

class _MemoryEntitlementCache implements SubscriptionEntitlementCache {
  @override
  Future<void> clear() async {}

  @override
  Future<SubscriptionEntitlementCacheEntry?> read() async => null;

  @override
  Future<void> write(SubscriptionEntitlementCacheEntry entry) async {}
}

class _MemoryIdentityStore implements SubscriptionIdentityStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAppAccountToken() async => null;

  @override
  Future<String> readOrCreateAppAccountToken() async =>
      '00000000-0000-4000-8000-000000000001';

  @override
  Future<void> writeAppAccountToken(String token) async {}
}
