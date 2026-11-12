import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'billing_gateway.dart';

BillingGateway createBillingGateway() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return GooglePlayBillingGateway();
  }
  return const NoBillingGateway();
}

class GooglePlayBillingGateway implements BillingGateway {
  final InAppPurchase _store = InAppPurchase.instance;
  final Map<String, ProductDetails> _productDetails = {};
  final Map<String, PurchaseDetails> _purchasesByToken = {};

  @override
  bool get isSupported => true;

  @override
  Stream<List<BillingPurchase>> get purchases =>
      _store.purchaseStream.map((updates) => updates.map(_convert).toList());

  BillingPurchase _convert(PurchaseDetails details) {
    final token = details.verificationData.serverVerificationData;
    _purchasesByToken[token] = details;
    final account = details is GooglePlayPurchaseDetails
        ? details.billingClientPurchase.obfuscatedAccountId
        : null;
    return BillingPurchase(
      productId: details.productID,
      purchaseToken: token,
      orderId: details.purchaseID,
      accountId: account,
      status: switch (details.status) {
        PurchaseStatus.purchased => BillingPurchaseStatus.purchased,
        PurchaseStatus.restored => BillingPurchaseStatus.restored,
        PurchaseStatus.pending => BillingPurchaseStatus.pending,
        PurchaseStatus.canceled => BillingPurchaseStatus.canceled,
        PurchaseStatus.error => BillingPurchaseStatus.error,
      },
    );
  }

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<Map<String, BillingProduct>> loadProducts(
    Set<String> productIds,
  ) async {
    final response = await _store.queryProductDetails(productIds);
    for (final details in response.productDetails) {
      _productDetails[details.id] = details;
    }
    return {
      for (final details in response.productDetails)
        details.id: BillingProduct(
          productId: details.id,
          displayPrice: details.price,
        ),
    };
  }

  @override
  Future<bool> buy({required String productId, required String walletRef}) {
    final details = _productDetails[productId];
    if (details == null) return Future<bool>.value(false);
    // autoConsume falso: consumir antes de validar perderia a compra se o servidor falhar.
    return _store.buyConsumable(
      purchaseParam: PurchaseParam(
        productDetails: details,
        applicationUserName: walletRef,
      ),
      autoConsume: false,
    );
  }

  @override
  Future<void> restoreUnfinished() => _store.restorePurchases();

  @override
  Future<void> finish(BillingPurchase purchase) async {
    final details = _purchasesByToken[purchase.purchaseToken];
    if (details == null) return;
    final android = _store
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final result = await android.consumePurchase(details);
    if (result.responseCode != BillingResponse.ok) {
      throw StateError('Falha ao consumir compra: ${result.responseCode}');
    }
    _purchasesByToken.remove(purchase.purchaseToken);
  }
}
