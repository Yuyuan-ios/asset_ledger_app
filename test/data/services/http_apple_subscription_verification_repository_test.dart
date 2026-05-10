import 'dart:async';
import 'dart:convert';

import 'package:asset_ledger/core/config/subscription_config.dart';
import 'package:asset_ledger/data/services/http_apple_subscription_verification_repository.dart';
import 'package:asset_ledger/data/services/subscription_service.dart';
import 'package:asset_ledger/data/services/subscription_verification_repository.dart';
import 'package:asset_ledger/data/services/subscription_verification_repository_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  const configured = SubscriptionConfig(
    appleVerificationBaseUrl: 'https://example.test',
    requestTimeout: Duration(milliseconds: 20),
  );

  group('HttpAppleSubscriptionVerificationRepository', () {
    test('unconfigured baseUrl safely fails without unlocking', () async {
      final client = FakeVerificationHttpClient();
      final repository = HttpAppleSubscriptionVerificationRepository(
        config: const SubscriptionConfig(appleVerificationBaseUrl: ''),
        httpClient: client,
      );

      final purchaseResult = await repository.verifyPurchase(
        purchaseDetails(productId: SubscriptionService.monthlyProductId),
      );
      final currentResult = await repository.fetchCurrentEntitlement();

      expect(
        purchaseResult.outcome,
        SubscriptionVerificationOutcome.verificationUnavailable,
      );
      expect(currentResult.isVerified, isFalse);
      expect(client.postCallCount, 0);
      expect(client.getCallCount, 0);
    });

    test(
      'default factory uses a safe repository when baseUrl is absent',
      () async {
        final repository = createDefaultSubscriptionVerificationRepository(
          config: const SubscriptionConfig(appleVerificationBaseUrl: ''),
        );

        final result = await repository.fetchCurrentEntitlement();

        expect(
          result.outcome,
          SubscriptionVerificationOutcome.verificationUnavailable,
        );
        expect(result.isVerified, isFalse);
      },
    );

    test('verify-purchase maps active monthly response', () async {
      final expiryDate = DateTime.utc(2026, 5, 21);
      final client = FakeVerificationHttpClient(
        postResponse: SubscriptionHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'outcome': 'verifiedActiveMonthly',
            'productId': SubscriptionService.monthlyProductId,
            'expiryDate': expiryDate.toIso8601String(),
          }),
        ),
      );
      final repository = HttpAppleSubscriptionVerificationRepository(
        config: configured,
        httpClient: client,
        bundleId: 'com.yuyuan.assetledger',
      );

      final result = await repository.verifyPurchase(
        purchaseDetails(productId: SubscriptionService.monthlyProductId),
      );

      expect(
        result.outcome,
        SubscriptionVerificationOutcome.verifiedActiveMonthly,
      );
      expect(result.productId, SubscriptionService.monthlyProductId);
      expect(result.expiryDate, expiryDate);
      expect(client.lastPostUri?.path, '/iap/apple/verify-purchase');
      expect(client.lastPostBody?['platform'], 'ios');
      expect(client.lastPostBody?['bundleId'], 'com.yuyuan.assetledger');
      expect(
        client.lastPostBody?['serverVerificationData'],
        'server-${SubscriptionService.monthlyProductId}',
      );
    });

    test('unknown outcome safely fails', () async {
      final client = FakeVerificationHttpClient(
        postResponse: const SubscriptionHttpResponse(
          statusCode: 200,
          body: '{"outcome":"surpriseActive"}',
        ),
      );
      final repository = HttpAppleSubscriptionVerificationRepository(
        config: configured,
        httpClient: client,
      );

      final result = await repository.verifyPurchase(
        purchaseDetails(productId: SubscriptionService.yearlyProductId),
      );

      expect(
        result.outcome,
        SubscriptionVerificationOutcome.verificationFailed,
      );
      expect(result.isVerified, isFalse);
    });

    test(
      'current-entitlement maps revoked, expired, and inactive as non-pro',
      () async {
        final repository = HttpAppleSubscriptionVerificationRepository(
          config: configured,
          httpClient: FakeVerificationHttpClient(
            getResponse: const SubscriptionHttpResponse(
              statusCode: 200,
              body:
                  '{"outcome":"revoked","productId":"com.yuyuan.assetledger.pro.monthly"}',
            ),
          ),
        );

        final revoked = await repository.fetchCurrentEntitlement();
        expect(
          revoked.outcome,
          SubscriptionVerificationOutcome.verifiedRevoked,
        );
        expect(
          SubscriptionService.mapVerifiedEntitlementToStatus(revoked.outcome),
          SubscriptionStatus.revoked,
        );
        expect(revoked.isVerified, isTrue);

        final expired = AppleEntitlementResponse.fromJson({
          'outcome': 'expired',
        }).toVerifiedEntitlement();
        expect(
          expired.outcome,
          SubscriptionVerificationOutcome.verifiedExpired,
        );
        expect(
          SubscriptionService.mapVerifiedEntitlementToStatus(expired.outcome),
          SubscriptionStatus.expired,
        );

        final inactive = AppleEntitlementResponse.fromJson({
          'outcome': 'inactive',
        }).toVerifiedEntitlement();
        expect(
          inactive.outcome,
          SubscriptionVerificationOutcome.verifiedInactive,
        );
        expect(
          SubscriptionService.mapVerifiedEntitlementToStatus(inactive.outcome),
          SubscriptionStatus.free,
        );
      },
    );

    test('http 500, timeout, and invalid json fail safely', () async {
      final serverErrorRepository = HttpAppleSubscriptionVerificationRepository(
        config: configured,
        httpClient: FakeVerificationHttpClient(
          getResponse: const SubscriptionHttpResponse(
            statusCode: 500,
            body: '{"error":"server"}',
          ),
        ),
      );
      final timeoutRepository = HttpAppleSubscriptionVerificationRepository(
        config: configured,
        httpClient: FakeVerificationHttpClient(
          postError: TimeoutException('timed out'),
        ),
      );
      final invalidJsonRepository = HttpAppleSubscriptionVerificationRepository(
        config: configured,
        httpClient: FakeVerificationHttpClient(
          getResponse: const SubscriptionHttpResponse(
            statusCode: 200,
            body: 'not json',
          ),
        ),
      );

      final serverError = await serverErrorRepository.fetchCurrentEntitlement();
      final timeout = await timeoutRepository.verifyPurchase(
        purchaseDetails(productId: SubscriptionService.monthlyProductId),
      );
      final invalidJson = await invalidJsonRepository.fetchCurrentEntitlement();

      expect(
        serverError.outcome,
        SubscriptionVerificationOutcome.verificationUnavailable,
      );
      expect(
        timeout.outcome,
        SubscriptionVerificationOutcome.verificationUnavailable,
      );
      expect(
        invalidJson.outcome,
        SubscriptionVerificationOutcome.verificationFailed,
      );
      expect(serverError.isVerified, isFalse);
      expect(timeout.isVerified, isFalse);
      expect(invalidJson.isVerified, isFalse);
    });
  });
}

PurchaseDetails purchaseDetails({required String productId}) {
  return PurchaseDetails(
    productID: productId,
    purchaseID: 'purchase-$productId',
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-$productId',
      serverVerificationData: 'server-$productId',
      source: 'app_store',
    ),
    transactionDate: '1700000000000',
    status: PurchaseStatus.purchased,
  );
}

class FakeVerificationHttpClient implements SubscriptionVerificationHttpClient {
  FakeVerificationHttpClient({
    this.postResponse,
    this.getResponse,
    this.postError,
    this.getError,
  });

  final SubscriptionHttpResponse? postResponse;
  final SubscriptionHttpResponse? getResponse;
  final Object? postError;
  final Object? getError;

  Uri? lastPostUri;
  Map<String, Object?>? lastPostBody;
  var postCallCount = 0;
  var getCallCount = 0;

  @override
  Future<SubscriptionHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    required Duration timeout,
  }) async {
    postCallCount++;
    lastPostUri = uri;
    lastPostBody = body;
    final error = postError;
    if (error != null) throw error;
    return postResponse ??
        const SubscriptionHttpResponse(statusCode: 200, body: '{}');
  }

  @override
  Future<SubscriptionHttpResponse> getJson(
    Uri uri, {
    required Duration timeout,
  }) async {
    getCallCount++;
    final error = getError;
    if (error != null) throw error;
    return getResponse ??
        const SubscriptionHttpResponse(statusCode: 200, body: '{}');
  }
}
