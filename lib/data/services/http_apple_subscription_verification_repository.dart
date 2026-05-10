import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/config/subscription_config.dart';
import 'subscription_verification_repository.dart';

class HttpAppleSubscriptionVerificationRepository
    implements SubscriptionVerificationRepository {
  HttpAppleSubscriptionVerificationRepository({
    SubscriptionConfig config = SubscriptionConfig.fromEnvironment,
    SubscriptionVerificationHttpClient? httpClient,
    String? bundleId,
  }) : _config = config,
       _httpClient = httpClient ?? DartIoSubscriptionVerificationHttpClient(),
       _bundleId = bundleId;

  final SubscriptionConfig _config;
  final SubscriptionVerificationHttpClient _httpClient;
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
      final request = AppleVerifyPurchaseRequest.fromPurchase(
        purchase,
        bundleId: _bundleId,
      );
      final response = await _httpClient.postJson(
        uri,
        request.toJson(),
        timeout: _config.requestTimeout,
      );
      return _entitlementFromResponse(response, purchase.productID);
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
      final response = await _httpClient.getJson(
        uri,
        timeout: _config.requestTimeout,
      );
      return _entitlementFromResponse(response, null);
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

  VerifiedEntitlement _safeFailed({String? productId, String? reason}) {
    return VerifiedEntitlement(
      outcome: SubscriptionVerificationOutcome.verificationFailed,
      productId: productId,
      reason: reason,
    );
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
    this.bundleId,
  });

  factory AppleVerifyPurchaseRequest.fromPurchase(
    PurchaseDetails purchase, {
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
      if (bundleId != null && bundleId!.isNotEmpty) 'bundleId': bundleId,
    };
  }
}

class AppleEntitlementResponse {
  const AppleEntitlementResponse({
    required this.outcome,
    this.productId,
    this.expiryDate,
  });

  factory AppleEntitlementResponse.fromJson(Map<String, dynamic> json) {
    final outcome = json['outcome'];
    if (outcome is! String || outcome.isEmpty) {
      return const AppleEntitlementResponse(
        outcome: SubscriptionVerificationOutcome.verificationFailed,
      );
    }

    final productId = json['productId'];
    final expiryDateValue = json['expiryDate'];
    DateTime? expiryDate;
    if (expiryDateValue is String && expiryDateValue.isNotEmpty) {
      expiryDate = DateTime.tryParse(expiryDateValue);
      if (expiryDate == null) {
        return AppleEntitlementResponse(
          outcome: SubscriptionVerificationOutcome.verificationFailed,
          productId: productId is String ? productId : null,
        );
      }
    }

    return AppleEntitlementResponse(
      outcome: _outcomeFromWireValue(outcome),
      productId: productId is String ? productId : null,
      expiryDate: expiryDate,
    );
  }

  final SubscriptionVerificationOutcome outcome;
  final String? productId;
  final DateTime? expiryDate;

  VerifiedEntitlement toVerifiedEntitlement({String? fallbackProductId}) {
    final failed =
        outcome == SubscriptionVerificationOutcome.verificationFailed ||
        outcome == SubscriptionVerificationOutcome.verificationUnavailable;
    return VerifiedEntitlement(
      outcome: outcome,
      productId: productId ?? fallbackProductId,
      expiryDate: expiryDate,
      reason: failed ? '订阅服务端未返回有效授权' : null,
    );
  }

  static SubscriptionVerificationOutcome _outcomeFromWireValue(String value) {
    return switch (value) {
      'verifiedActiveMonthly' =>
        SubscriptionVerificationOutcome.verifiedActiveMonthly,
      'verifiedActiveYearly' =>
        SubscriptionVerificationOutcome.verifiedActiveYearly,
      'verifiedGracePeriod' =>
        SubscriptionVerificationOutcome.verifiedGracePeriod,
      'verifiedBillingRetry' =>
        SubscriptionVerificationOutcome.verifiedBillingRetry,
      'verifiedExpired' ||
      'expired' => SubscriptionVerificationOutcome.verifiedExpired,
      'verifiedRevoked' ||
      'revoked' => SubscriptionVerificationOutcome.verifiedRevoked,
      'verifiedInactive' ||
      'inactive' => SubscriptionVerificationOutcome.verifiedInactive,
      'verificationUnavailable' =>
        SubscriptionVerificationOutcome.verificationUnavailable,
      'verificationFailed' =>
        SubscriptionVerificationOutcome.verificationFailed,
      _ => SubscriptionVerificationOutcome.verificationFailed,
    };
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
