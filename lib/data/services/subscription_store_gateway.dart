import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

abstract class SubscriptionStoreGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});

  Future<List<PurchaseDetails>> restorePurchases({String? applicationUserName});

  Future<void> completePurchase(PurchaseDetails purchase);
}

class InAppPurchaseSubscriptionStoreGateway
    implements SubscriptionStoreGateway {
  InAppPurchaseSubscriptionStoreGateway({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _inAppPurchase.purchaseStream;

  @override
  Future<bool> isAvailable() => _inAppPurchase.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) {
    return _inAppPurchase.queryProductDetails(identifiers);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) {
    return _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<List<PurchaseDetails>> restorePurchases({
    String? applicationUserName,
  }) async {
    final restoredPurchases = <PurchaseDetails>[];
    final completer = Completer<List<PurchaseDetails>>();
    Timer? settleTimer;
    late final StreamSubscription<List<PurchaseDetails>> subscription;

    subscription = purchaseStream.listen((purchases) {
      if (purchases.isEmpty) return;
      restoredPurchases.addAll(purchases);
      settleTimer?.cancel();
      settleTimer = Timer(const Duration(milliseconds: 300), () {
        if (!completer.isCompleted) {
          completer.complete(
            List<PurchaseDetails>.unmodifiable(restoredPurchases),
          );
        }
      });
    });

    try {
      await _inAppPurchase.restorePurchases(
        applicationUserName: applicationUserName,
      );
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => List<PurchaseDetails>.unmodifiable(restoredPurchases),
      );
    } finally {
      settleTimer?.cancel();
      await subscription.cancel();
    }
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _inAppPurchase.completePurchase(purchase);
  }
}

class UnavailableSubscriptionStoreGateway implements SubscriptionStoreGateway {
  const UnavailableSubscriptionStoreGateway();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: const [],
      notFoundIDs: identifiers.toList(growable: false),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return false;
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
