enum BillingPurchaseStatus { purchased, restored, pending, canceled, error }

class BillingProduct {
  final String productId;
  final String displayPrice;

  const BillingProduct({required this.productId, required this.displayPrice});
}

class BillingPurchase {
  final String productId;
  final String purchaseToken;
  final String? orderId;
  final BillingPurchaseStatus status;

  /// Carteira gravada na compra, quando a loja a devolve.
  final String? accountId;

  const BillingPurchase({
    required this.productId,
    required this.purchaseToken,
    required this.status,
    this.orderId,
    this.accountId,
  });
}

/// Porta de compras na loja. Só libera crédito depois da validação no servidor.
abstract class BillingGateway {
  bool get isSupported;

  Stream<List<BillingPurchase>> get purchases;

  Future<bool> isAvailable();

  Future<Map<String, BillingProduct>> loadProducts(Set<String> productIds);

  /// Retorna falso quando a loja não abriu o fluxo de pagamento.
  Future<bool> buy({required String productId, required String walletRef});

  /// Reapresenta compras pagas que ainda não foram consumidas.
  Future<void> restoreUnfinished();

  /// Consome a compra. Deve ser chamado só depois da validação no servidor.
  Future<void> finish(BillingPurchase purchase);
}

/// Usado onde não há Google Play: Web, iOS, desktop e testes.
class NoBillingGateway implements BillingGateway {
  const NoBillingGateway();

  @override
  bool get isSupported => false;

  @override
  Stream<List<BillingPurchase>> get purchases => const Stream.empty();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<Map<String, BillingProduct>> loadProducts(
    Set<String> productIds,
  ) async => const {};

  @override
  Future<bool> buy({
    required String productId,
    required String walletRef,
  }) async => false;

  @override
  Future<void> restoreUnfinished() async {}

  @override
  Future<void> finish(BillingPurchase purchase) async {}
}
