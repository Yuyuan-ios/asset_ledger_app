import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:asset_ledger/core/config/subscription_config.dart';
import 'package:asset_ledger/data/services/subscription_entitlement_cache.dart';
import 'package:asset_ledger/data/services/subscription_identity_store.dart';
import 'package:asset_ledger/data/services/subscription_service.dart';
import 'package:asset_ledger/data/services/subscription_store_gateway.dart';
import 'package:asset_ledger/data/services/subscription_verification_repository.dart';
import 'package:asset_ledger/data/services/subscription_verification_repository_factory.dart';
import 'package:asset_ledger/features/device/application/controllers/subscription_controller.dart';
import 'package:asset_ledger/features/device/view/upgrade_page.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  tearDown(() {
    SubscriptionService.resetForTest();
  });

  test(
    'local review define enables the purchase flow',
    () {
      expect(
        SubscriptionController.isPurchaseFlowAvailable(
          config: const SubscriptionConfig(appleVerificationBaseUrl: ''),
          useLocalIapVerification: true,
        ),
        isTrue,
      );
      expect(kUseLocalIapVerification, isTrue);
    },
    skip: !kUseLocalIapVerification,
  );

  test('production base URL enables the purchase flow when configured', () {
    expect(
      SubscriptionController.isPurchaseFlowAvailable(
        config: const SubscriptionConfig(
          appleVerificationBaseUrl:
              SubscriptionConfig.defaultAppleVerificationBaseUrl,
        ),
        useLocalIapVerification: false,
      ),
      isTrue,
    );
    expect(
      SubscriptionController.isPurchaseFlowAvailable(
        config: const SubscriptionConfig(appleVerificationBaseUrl: ''),
        useLocalIapVerification: false,
      ),
      isFalse,
    );
  });

  test('production dart define stays in sync with the code default', () {
    final file = File('dart_defines/production.json');
    final decoded = jsonDecode(file.readAsStringSync());

    expect(decoded, isA<Map<String, dynamic>>());
    expect(
      decoded['APPLE_IAP_VERIFICATION_BASE_URL'],
      SubscriptionConfig.defaultAppleVerificationBaseUrl,
    );
  });

  test(
    'production base URL define enables the runtime purchase flow',
    () {
      expect(
        SubscriptionConfig.fromEnvironment.appleVerificationBaseUrl,
        SubscriptionConfig.defaultAppleVerificationBaseUrl,
      );
      expect(SubscriptionConfig.fromEnvironment.isConfigured, isTrue);
      expect(const SubscriptionController().canUsePurchaseFlow, isTrue);
    },
    skip: !SubscriptionConfig.fromEnvironment.isConfigured,
  );

  testWidgets(
    'upgrade page stays purchasable when a verification define is present',
    (tester) async {
      final storeGateway = FakeSubscriptionStoreGateway()
        ..productDetailsResponse = ProductDetailsResponse(
          productDetails: [
            productDetails(
              id: SubscriptionService.proYearlyProductId,
              price: r'¥6.00',
            ),
            productDetails(
              id: SubscriptionService.maxYearlyProductId,
              price: r'¥24.00',
            ),
          ],
          notFoundIDs: const [],
        );
      SubscriptionService.configureForTest(
        storeGateway: storeGateway,
        verificationRepository: FakeVerificationRepository(),
        entitlementCache: MemoryEntitlementCache(),
        identityStore: MemoryIdentityStore(
          '00000000-0000-4000-8000-000000000999',
        ),
      );

      await tester.pumpWidget(_localizedApp(home: const UpgradePage()));
      await tester.pumpAndSettle();

      expect(const SubscriptionController().canUsePurchaseFlow, isTrue);
      expect(find.text('暂不可购买'), findsNothing);
      expect(find.text('订阅购买服务暂不可用，请稍后重试'), findsNothing);
      expect(find.text('年套餐'), findsNothing);
      expect(find.text('月套餐'), findsNothing);
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.textContaining(r'¥6.00'), findsOneWidget);
      expect(find.textContaining(r'¥24.00'), findsOneWidget);
      final purchaseButton = find.byType(FilledButton);
      await tester.scrollUntilVisible(purchaseButton, 500);
      await tester.pumpAndSettle();

      expect(purchaseButton, findsOneWidget);
      expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);

      await tester.tap(purchaseButton);
      await tester.pump();

      expect(storeGateway.lastPurchaseParam, isNotNull);
      expect(
        storeGateway.lastPurchaseParam?.productDetails.id,
        SubscriptionService.proYearlyProductId,
      );
    },
    skip:
        !(kUseLocalIapVerification ||
            SubscriptionConfig.fromEnvironment.isConfigured),
  );
}

Widget _localizedApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

ProductDetails productDetails({required String id, required String price}) {
  return ProductDetails(
    id: id,
    title: id,
    description: '',
    price: price,
    rawPrice: double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
    currencyCode: 'USD',
    currencySymbol: r'$',
  );
}

class FakeVerificationRepository implements SubscriptionVerificationRepository {
  @override
  Future<VerifiedEntitlement> verifyPurchase(PurchaseDetails purchase) async {
    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.verificationUnavailable,
      productId: purchase.productID,
      reason: 'server unavailable in widget test',
    );
  }

  @override
  Future<VerifiedEntitlement> fetchCurrentEntitlement() async {
    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.verificationUnavailable,
      reason: 'server unavailable in widget test',
    );
  }
}

class MemoryEntitlementCache implements SubscriptionEntitlementCache {
  @override
  Future<void> clear() async {}

  @override
  Future<SubscriptionEntitlementCacheEntry?> read() async => null;

  @override
  Future<void> write(SubscriptionEntitlementCacheEntry entry) async {}
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
  final purchaseController =
      StreamController<List<PurchaseDetails>>.broadcast();

  ProductDetailsResponse productDetailsResponse = ProductDetailsResponse(
    productDetails: const [],
    notFoundIDs: const [],
  );
  PurchaseParam? lastPurchaseParam;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchaseController.stream;

  @override
  Future<bool> isAvailable() async => true;

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
    return const <PurchaseDetails>[];
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}
