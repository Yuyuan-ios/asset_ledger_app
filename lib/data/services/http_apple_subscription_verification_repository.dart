import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/config/subscription_config.dart';
import 'subscription_identity_store.dart';
import 'subscription_verification_repository.dart';

class HttpAppleSubscriptionVerificationRepository
    implements SubscriptionVerificationRepository {
  HttpAppleSubscriptionVerificationRepository({
    SubscriptionConfig config = SubscriptionConfig.fromEnvironment,
    SubscriptionVerificationHttpClient? httpClient,
    SubscriptionIdentityStore? identityStore,
    String? bundleId,
  }) : _config = config,
       _httpClient = httpClient ?? DartIoSubscriptionVerificationHttpClient(),
       _identityStore =
           identityStore ?? SharedPreferencesSubscriptionIdentityStore(),
       _bundleId = bundleId;

  final SubscriptionConfig _config;
  final SubscriptionVerificationHttpClient _httpClient;
  final SubscriptionIdentityStore _identityStore;
  final String? _bundleId;

  @override
  Future<VerifiedEntitlement> verifyPurchase(PurchaseDetails purchase) async {
    final uri = _config.uriFor(_config.verifyPurchasePath);
    if (uri == null) {
      return _safeUnavailable(
        productId: purchase.productID,
        reason: '订阅服务端校验地址未配置',
      );
    }

    try {
      final storedAppAccountToken = await _identityStore
          .readOrCreateAppAccountToken();
      final requestAppAccountToken =
          _appAccountTokenFromSignedTransaction(
            purchase.verificationData.serverVerificationData,
          ) ??
          storedAppAccountToken;
      final request = AppleVerifyPurchaseRequest.fromPurchase(
        purchase,
        appAccountToken: requestAppAccountToken,
        bundleId: _bundleId,
      );
      final response = await _httpClient.postJson(
        uri,
        request.toJson(),
        timeout: _config.requestTimeout,
      );
      final entitlement = _entitlementFromResponse(
        response,
        purchase.productID,
      );
      await _persistVerifiedAppAccountToken(entitlement);
      return entitlement;
    } catch (_) {
      return _safeUnavailable(
        productId: purchase.productID,
        reason: '订阅服务端校验请求失败',
      );
    }
  }

  @override
  Future<VerifiedEntitlement> fetchCurrentEntitlement() async {
    final uri = _config.uriFor(_config.currentEntitlementPath);
    if (uri == null) {
      return _safeUnavailable(reason: '订阅服务端同步地址未配置');
    }

    try {
      final appAccountToken = await _identityStore
          .readOrCreateAppAccountToken();
      final response = await _httpClient.getJson(
        _uriWithAppAccountToken(uri, appAccountToken),
        timeout: _config.requestTimeout,
      );
      final entitlement = _entitlementFromResponse(response, null);
      await _persistVerifiedAppAccountToken(entitlement);
      return entitlement;
    } catch (_) {
      return _safeUnavailable(reason: '订阅服务端同步请求失败');
    }
  }

  VerifiedEntitlement _entitlementFromResponse(
    SubscriptionHttpResponse response,
    String? fallbackProductId,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _safeUnavailable(
        productId: fallbackProductId,
        reason: '订阅服务端返回异常状态',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _safeFailed(productId: fallbackProductId, reason: '订阅服务端响应格式无效');
      }

      return AppleEntitlementResponse.fromJson(
        decoded,
      ).toVerifiedEntitlement(fallbackProductId: fallbackProductId);
    } catch (_) {
      return _safeFailed(productId: fallbackProductId, reason: '订阅服务端响应解析失败');
    }
  }

  VerifiedEntitlement _safeUnavailable({String? productId, String? reason}) {
    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.verificationUnavailable,
      productId: productId,
      reason: reason,
    );
  }

  Future<void> _persistVerifiedAppAccountToken(
    VerifiedEntitlement entitlement,
  ) async {
    final appAccountToken = entitlement.appAccountToken;
    if (!entitlement.isVerified ||
        appAccountToken == null ||
        appAccountToken.trim().isEmpty) {
      return;
    }
    await _identityStore.writeAppAccountToken(appAccountToken);
  }

  VerifiedEntitlement _safeFailed({String? productId, String? reason}) {
    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.verificationFailed,
      productId: productId,
      reason: reason,
    );
  }

  Uri _uriWithAppAccountToken(Uri uri, String appAccountToken) {
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        'appAccountToken': appAccountToken,
      },
    );
  }

  String? _appAccountTokenFromSignedTransaction(String signedTransaction) {
    final parts = signedTransaction.trim().split('.');
    if (parts.length != 3) return null;
    try {
      final payloadBytes = base64Url.decode(base64Url.normalize(parts[1]));
      final decoded = jsonDecode(utf8.decode(payloadBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final token = decoded['appAccountToken'];
      if (token is! String || !_looksLikeUuid(token)) return null;
      return token.trim();
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
  }
}

class AppleVerifyPurchaseRequest {
  const AppleVerifyPurchaseRequest({
    required this.platform,
    required this.productId,
    required this.purchaseId,
    required this.transactionDate,
    required this.serverVerificationData,
    required this.localVerificationData,
    required this.source,
    required this.status,
    required this.appAccountToken,
    this.bundleId,
  });

  factory AppleVerifyPurchaseRequest.fromPurchase(
    PurchaseDetails purchase, {
    required String appAccountToken,
    String? bundleId,
  }) {
    return AppleVerifyPurchaseRequest(
      platform: 'ios',
      productId: purchase.productID,
      purchaseId: purchase.purchaseID,
      transactionDate: purchase.transactionDate,
      serverVerificationData: purchase.verificationData.serverVerificationData,
      localVerificationData: purchase.verificationData.localVerificationData,
      source: purchase.verificationData.source,
      status: purchase.status.name,
      appAccountToken: appAccountToken,
      bundleId: bundleId,
    );
  }

  final String platform;
  final String productId;
  final String? purchaseId;
  final String? transactionDate;
  final String serverVerificationData;
  final String localVerificationData;
  final String source;
  final String status;
  final String appAccountToken;
  final String? bundleId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'platform': platform,
      'productId': productId,
      'purchaseId': purchaseId,
      'transactionDate': transactionDate,
      'serverVerificationData': serverVerificationData,
      'localVerificationData': localVerificationData,
      'source': source,
      'status': status,
      'appAccountToken': appAccountToken,
      if (bundleId != null && bundleId!.isNotEmpty) 'bundleId': bundleId,
    };
  }
}

class AppleEntitlementResponse {
  const AppleEntitlementResponse({
    required this.outcome,
    required this.entitlementTier,
    this.productId,
    this.appAccountToken,
    this.expiryDate,
  });

  factory AppleEntitlementResponse.fromJson(Map<String, dynamic> json) {
    final outcome = json['outcome'];
    if (outcome is! String || outcome.isEmpty) {
      return const AppleEntitlementResponse(
        outcome: SubscriptionVerificationOutcome.verificationFailed,
        entitlementTier: SubscriptionEntitlementTier.none,
      );
    }

    final productId = json['productId'];
    final expiryDateValue = json['expiresAt'] ?? json['expiryDate'];
    DateTime? expiryDate;
    if (expiryDateValue is String && expiryDateValue.isNotEmpty) {
      expiryDate = DateTime.tryParse(expiryDateValue);
      if (expiryDate == null) {
        return AppleEntitlementResponse(
          outcome: SubscriptionVerificationOutcome.verificationFailed,
          entitlementTier: SubscriptionEntitlementTier.none,
          productId: productId is String ? productId : null,
          appAccountToken: json['appAccountToken'] is String
              ? json['appAccountToken'] as String
              : null,
        );
      }
    }

    final appAccountToken = json['appAccountToken'];
    final mappedOutcome = _outcomeFromWireValue(outcome);
    return AppleEntitlementResponse(
      outcome: mappedOutcome,
      entitlementTier:
          _tierFromWireValue(json['entitlementTier']) ??
          _tierFromOutcome(mappedOutcome),
      productId: productId is String ? productId : null,
      appAccountToken: appAccountToken is String ? appAccountToken : null,
      expiryDate: expiryDate,
    );
  }

  final SubscriptionVerificationOutcome outcome;
  final SubscriptionEntitlementTier entitlementTier;
  final String? productId;
  final String? appAccountToken;
  final DateTime? expiryDate;

  VerifiedEntitlement toVerifiedEntitlement({String? fallbackProductId}) {
    final failed =
        outcome == SubscriptionVerificationOutcome.verificationFailed ||
        outcome == SubscriptionVerificationOutcome.verificationUnavailable;
    return VerifiedEntitlement(
      outcome: outcome,
      entitlementTier: entitlementTier,
      productId: productId ?? fallbackProductId,
      appAccountToken: appAccountToken,
      expiryDate: expiryDate,
      reason: failed ? '订阅服务端未返回有效授权' : null,
    );
  }

  static SubscriptionVerificationOutcome _outcomeFromWireValue(String value) {
    return switch (value) {
      'verifiedActivePro' => SubscriptionVerificationOutcome.verifiedActivePro,
      'verifiedActiveMax' => SubscriptionVerificationOutcome.verifiedActiveMax,
      'verifiedGracePeriodPro' =>
        SubscriptionVerificationOutcome.verifiedGracePeriodPro,
      'verifiedGracePeriodMax' =>
        SubscriptionVerificationOutcome.verifiedGracePeriodMax,
      'verifiedActiveMonthly' =>
        SubscriptionVerificationOutcome.verifiedActivePro,
      'verifiedActiveYearly' =>
        SubscriptionVerificationOutcome.verifiedActivePro,
      'verifiedGracePeriod' =>
        SubscriptionVerificationOutcome.verifiedGracePeriodPro,
      'verifiedBillingRetry' => SubscriptionVerificationOutcome.billingRetry,
      'billingRetry' => SubscriptionVerificationOutcome.billingRetry,
      'verifiedExpired' || 'expired' => SubscriptionVerificationOutcome.expired,
      'verifiedRevoked' || 'revoked' => SubscriptionVerificationOutcome.revoked,
      'verifiedInactive' || 'inactive' || 'noActiveEntitlement' =>
        SubscriptionVerificationOutcome.noActiveEntitlement,
      'verificationUnavailable' =>
        SubscriptionVerificationOutcome.verificationUnavailable,
      'verificationFailed' =>
        SubscriptionVerificationOutcome.verificationFailed,
      _ => SubscriptionVerificationOutcome.verificationFailed,
    };
  }

  static SubscriptionEntitlementTier? _tierFromWireValue(Object? value) {
    if (value is! String) return null;
    return switch (value) {
      'pro' => SubscriptionEntitlementTier.pro,
      'max' => SubscriptionEntitlementTier.max,
      'none' => SubscriptionEntitlementTier.none,
      _ => null,
    };
  }

  static SubscriptionEntitlementTier _tierFromOutcome(
    SubscriptionVerificationOutcome outcome,
  ) {
    return VerifiedEntitlement(outcome: outcome).entitlementTier;
  }
}

abstract class SubscriptionVerificationHttpClient {
  Future<SubscriptionHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    required Duration timeout,
  });

  Future<SubscriptionHttpResponse> getJson(
    Uri uri, {
    required Duration timeout,
  });
}

class SubscriptionHttpResponse {
  const SubscriptionHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class DartIoSubscriptionVerificationHttpClient
    implements SubscriptionVerificationHttpClient {
  @override
  Future<SubscriptionHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    required Duration timeout,
  }) async {
    final encoded = jsonEncode(body);
    return _sendJson(method: 'POST', uri: uri, timeout: timeout, body: encoded);
  }

  @override
  Future<SubscriptionHttpResponse> getJson(
    Uri uri, {
    required Duration timeout,
  }) async {
    return _sendJson(method: 'GET', uri: uri, timeout: timeout);
  }

  Future<SubscriptionHttpResponse> _sendJson({
    required String method,
    required Uri uri,
    required Duration timeout,
    String? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final request = await client.openUrl(method, uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      if (body != null) {
        request.write(body);
      }

      final response = await request.close().timeout(timeout);
      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return SubscriptionHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }
}
