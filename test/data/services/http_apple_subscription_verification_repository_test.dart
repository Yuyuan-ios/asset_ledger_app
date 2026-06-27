import 'dart:async';
import 'dart:convert';

import 'package:asset_ledger/core/config/subscription_config.dart';
import 'package:asset_ledger/data/services/http_apple_subscription_verification_repository.dart';
import 'package:asset_ledger/data/services/subscription_identity_store.dart';
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
        purchaseDetails(productId: SubscriptionService.proYearlyProductId),
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
          kUseLocalIapVerification
              ? SubscriptionVerificationOutcome.noActiveEntitlement
              : SubscriptionVerificationOutcome.verificationUnavailable,
        );
        expect(result.isVerified, kUseLocalIapVerification ? isTrue : isFalse);
      },
    );

    test('verify-purchase maps active pro response', () async {
      final expiryDate = DateTime.utc(2026, 5, 21);
      final client = FakeVerificationHttpClient(
        postResponse: SubscriptionHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'outcome': 'verifiedActivePro',
            'entitlementTier': 'pro',
            'productId': SubscriptionService.proYearlyProductId,
            'expiresAt': expiryDate.toIso8601String(),
          }),
        ),
      );
      final repository = HttpAppleSubscriptionVerificationRepository(
        config: configured,
        httpClient: client,
        identityStore: MemoryIdentityStore(
          '00000000-0000-4000-8000-000000000456',
        ),
        bundleId: 'com.yuyuan.asset-ledger',
      );

      final result = await repository.verifyPurchase(
        purchaseDetails(productId: SubscriptionService.proYearlyProductId),
      );

      expect(result.outcome, SubscriptionVerificationOutcome.verifiedActivePro);
      expect(result.entitlementTier, SubscriptionEntitlementTier.pro);
      expect(result.productId, SubscriptionService.proYearlyProductId);
      expect(result.expiryDate, expiryDate);
      expect(client.lastPostUri?.path, '/iap/apple/verify-purchase');
      expect(client.lastPostBody?['platform'], 'ios');
      expect(client.lastPostBody?['bundleId'], 'com.yuyuan.asset-ledger');
      expect(
        client.lastPostBody?['appAccountToken'],
        '00000000-0000-4000-8000-000000000456',
      );
      expect(
        client.lastPostBody?['serverVerificationData'],
        'server-${SubscriptionService.proYearlyProductId}',
      );
      expect(client.lastPostHeaders, isNull);
    });

    test(
      'verify-purchase sends Authorization when login token is available',
      () async {
        final client = FakeVerificationHttpClient(
          postResponse: const SubscriptionHttpResponse(
            statusCode: 200,
            body:
                '{"outcome":"verifiedActiveMax","entitlementTier":"max","productId":"com.yuyuan.assetledger.max.yearly"}',
          ),
        );
        final repository = HttpAppleSubscriptionVerificationRepository(
          config: configured,
          httpClient: client,
          identityStore: MemoryIdentityStore(
            '00000000-0000-4000-8000-000000000457',
          ),
          accessTokenProvider: () async => 'login-token-1',
        );

        await repository.verifyPurchase(
          purchaseDetails(productId: SubscriptionService.maxYearlyProductId),
        );

        expect(client.lastPostHeaders, {
          'authorization': 'Bearer login-token-1',
        });
      },
    );

    test(
      'verify-purchase uses signed transaction appAccountToken and persists server token',
      () async {
        const storedToken = '00000000-0000-4000-8000-000000000111';
        const transactionToken = '00000000-0000-4000-8000-000000000222';
        final identityStore = MemoryIdentityStore(storedToken);
        final client = FakeVerificationHttpClient(
          postResponse: SubscriptionHttpResponse(
            statusCode: 200,
            body: jsonEncode({
              'outcome': 'verifiedActivePro',
              'entitlementTier': 'pro',
              'productId': SubscriptionService.proYearlyProductId,
              'appAccountToken': transactionToken,
            }),
          ),
        );
        final repository = HttpAppleSubscriptionVerificationRepository(
          config: configured,
          httpClient: client,
          identityStore: identityStore,
        );

        final result = await repository.verifyPurchase(
          purchaseDetails(
            productId: SubscriptionService.proYearlyProductId,
            serverVerificationData: signedTransactionJws({
              'appAccountToken': transactionToken,
            }),
          ),
        );

        expect(
          result.outcome,
          SubscriptionVerificationOutcome.verifiedActivePro,
        );
        expect(result.appAccountToken, transactionToken);
        expect(client.lastPostBody?['appAccountToken'], transactionToken);
        expect(identityStore.token, transactionToken);
      },
    );

    test(
      'verify-purchase falls back to stored token when JWS has no token',
      () async {
        const storedToken = '00000000-0000-4000-8000-000000000333';
        final identityStore = MemoryIdentityStore(storedToken);
        final client = FakeVerificationHttpClient(
          postResponse: const SubscriptionHttpResponse(
            statusCode: 200,
            body:
                '{"outcome":"verifiedActivePro","entitlementTier":"pro","productId":"com.yuyuan.assetledger.pro.yearly"}',
          ),
        );
        final repository = HttpAppleSubscriptionVerificationRepository(
          config: configured,
          httpClient: client,
          identityStore: identityStore,
        );

        await repository.verifyPurchase(
          purchaseDetails(
            productId: SubscriptionService.proYearlyProductId,
            serverVerificationData: signedTransactionJws({}),
          ),
        );

        expect(client.lastPostBody?['appAccountToken'], storedToken);
        expect(identityStore.token, storedToken);
      },
    );

    test('verify-purchase maps active max response', () async {
      final client = FakeVerificationHttpClient(
        postResponse: SubscriptionHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'outcome': 'verifiedActiveMax',
            'entitlementTier': 'max',
            'productId': SubscriptionService.maxYearlyProductId,
          }),
        ),
      );
      final repository = HttpAppleSubscriptionVerificationRepository(
        config: configured,
        httpClient: client,
        identityStore: MemoryIdentityStore(
          '00000000-0000-4000-8000-000000000456',
        ),
      );

      final result = await repository.verifyPurchase(
        purchaseDetails(productId: SubscriptionService.maxYearlyProductId),
      );

      expect(result.outcome, SubscriptionVerificationOutcome.verifiedActiveMax);
      expect(result.entitlementTier, SubscriptionEntitlementTier.max);
      expect(result.productId, SubscriptionService.maxYearlyProductId);
    });

    test('current-entitlement sends the stable appAccountToken', () async {
      final client = FakeVerificationHttpClient(
        getResponse: const SubscriptionHttpResponse(
          statusCode: 200,
          body: '{"outcome":"inactive"}',
        ),
      );
      final repository = HttpAppleSubscriptionVerificationRepository(
        config: configured,
        httpClient: client,
        identityStore: MemoryIdentityStore(
          '00000000-0000-4000-8000-000000000789',
        ),
      );

      await repository.fetchCurrentEntitlement();

      expect(client.lastGetUri?.path, '/iap/apple/current-entitlement');
      expect(
        client.lastGetUri?.queryParameters['appAccountToken'],
        '00000000-0000-4000-8000-000000000789',
      );
      expect(client.lastGetHeaders, isNull);
    });

    test(
      'current-entitlement sends Authorization when login token is available',
      () async {
        final client = FakeVerificationHttpClient(
          getResponse: const SubscriptionHttpResponse(
            statusCode: 200,
            body: '{"outcome":"noActiveEntitlement","entitlementTier":"none"}',
          ),
        );
        final repository = HttpAppleSubscriptionVerificationRepository(
          config: configured,
          httpClient: client,
          identityStore: MemoryIdentityStore(
            '00000000-0000-4000-8000-000000000790',
          ),
          accessTokenProvider: () async => 'login-token-2',
        );

        await repository.fetchCurrentEntitlement();

        expect(client.lastGetHeaders, {
          'authorization': 'Bearer login-token-2',
        });
      },
    );

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
        identityStore: MemoryIdentityStore(
          '00000000-0000-4000-8000-000000000111',
        ),
      );

      final result = await repository.verifyPurchase(
        purchaseDetails(productId: SubscriptionService.proYearlyProductId),
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
                  '{"outcome":"revoked","entitlementTier":"none","productId":"com.yuyuan.assetledger.pro.yearly"}',
            ),
          ),
          identityStore: MemoryIdentityStore(
            '00000000-0000-4000-8000-000000000222',
          ),
        );

        final revoked = await repository.fetchCurrentEntitlement();
        expect(revoked.outcome, SubscriptionVerificationOutcome.revoked);
        expect(
          SubscriptionService.mapVerifiedEntitlementToStatus(revoked.outcome),
          SubscriptionStatus.revoked,
        );
        expect(revoked.isVerified, isTrue);

        final expired = AppleEntitlementResponse.fromJson({
          'outcome': 'expired',
        }).toVerifiedEntitlement();
        expect(expired.outcome, SubscriptionVerificationOutcome.expired);
        expect(
          SubscriptionService.mapVerifiedEntitlementToStatus(expired.outcome),
          SubscriptionStatus.expired,
        );

        final inactive = AppleEntitlementResponse.fromJson({
          'outcome': 'noActiveEntitlement',
        }).toVerifiedEntitlement();
        expect(
          inactive.outcome,
          SubscriptionVerificationOutcome.noActiveEntitlement,
        );
        expect(
          SubscriptionService.mapVerifiedEntitlementToStatus(inactive.outcome),
          SubscriptionStatus.noActiveEntitlement,
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
        identityStore: MemoryIdentityStore(
          '00000000-0000-4000-8000-000000000333',
        ),
      );
      final timeoutRepository = HttpAppleSubscriptionVerificationRepository(
        config: configured,
        httpClient: FakeVerificationHttpClient(
          postError: TimeoutException('timed out'),
        ),
        identityStore: MemoryIdentityStore(
          '00000000-0000-4000-8000-000000000444',
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
        identityStore: MemoryIdentityStore(
          '00000000-0000-4000-8000-000000000555',
        ),
      );

      final serverError = await serverErrorRepository.fetchCurrentEntitlement();
      final timeout = await timeoutRepository.verifyPurchase(
        purchaseDetails(productId: SubscriptionService.proYearlyProductId),
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

PurchaseDetails purchaseDetails({
  required String productId,
  String? serverVerificationData,
}) {
  return PurchaseDetails(
    productID: productId,
    purchaseID: 'purchase-$productId',
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-$productId',
      serverVerificationData: serverVerificationData ?? 'server-$productId',
      source: 'app_store',
    ),
    transactionDate: '1700000000000',
    status: PurchaseStatus.purchased,
  );
}

String signedTransactionJws(Map<String, Object?> payload) {
  String encodePart(Map<String, Object?> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${encodePart({'alg': 'none'})}.${encodePart(payload)}.signature';
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
  Uri? lastGetUri;
  Map<String, Object?>? lastPostBody;
  Map<String, String>? lastPostHeaders;
  Map<String, String>? lastGetHeaders;
  var postCallCount = 0;
  var getCallCount = 0;

  @override
  Future<SubscriptionHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String>? headers,
    required Duration timeout,
  }) async {
    postCallCount++;
    lastPostUri = uri;
    lastPostBody = body;
    lastPostHeaders = headers;
    final error = postError;
    if (error != null) throw error;
    return postResponse ??
        const SubscriptionHttpResponse(statusCode: 200, body: '{}');
  }

  @override
  Future<SubscriptionHttpResponse> getJson(
    Uri uri, {
    Map<String, String>? headers,
    required Duration timeout,
  }) async {
    getCallCount++;
    lastGetUri = uri;
    lastGetHeaders = headers;
    final error = getError;
    if (error != null) throw error;
    return getResponse ??
        const SubscriptionHttpResponse(statusCode: 200, body: '{}');
  }
}
