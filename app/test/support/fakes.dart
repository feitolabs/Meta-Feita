import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta_feita/application/app_controller.dart';
import 'package:meta_feita/domain/models/credit_models.dart';
import 'package:meta_feita/infrastructure/ads/ad_gateway.dart';
import 'package:meta_feita/infrastructure/billing/billing_gateway.dart';
import 'package:meta_feita/infrastructure/monetization/monetization_api_client.dart';
import 'package:meta_feita/infrastructure/storage/local_storage_adapter.dart';

class FakeMonetizationClient implements MonetizationClient {
  bool offline;
  int serverBalance;
  final List<LedgerEntry> entries = [];
  final List<String> playValidations = [];
  final List<String> playWallets = [];
  Exception? playValidationError;
  bool playAcknowledged = true;
  int claimCalls = 0;
  int refundCalls = 0;
  bool failTransactions = false;
  int webCheckoutCalls = 0;

  FakeMonetizationClient({this.offline = false, this.serverBalance = 12});

  Never _throwOffline() {
    throw const MonetizationApiException('OFFLINE', 'Sem conexão de rede.');
  }

  @override
  Future<CreditCatalog> fetchCatalog() async {
    if (offline) _throwOffline();
    return AppController(
      storage: InMemoryLocalStorageAdapter(),
      apiClient: this,
    ).catalog;
  }

  @override
  Future<WalletInitResult> initWallet() async {
    if (offline) _throwOffline();
    return WalletInitResult(
      walletReference: 'wlt_test_ref_1234',
      balance: serverBalance,
      recoveryCode: 'MFREC-TEST-CODE-99',
      lastValidatedAt: DateTime.now(),
    );
  }

  @override
  Future<BalanceValidationResult> recoverWallet(
    String walletRef,
    String recoveryCode,
  ) async {
    if (offline) _throwOffline();
    return BalanceValidationResult(
      walletReference: walletRef,
      balance: serverBalance,
      lastValidatedAt: DateTime.now(),
      catalogVersion: '1.0',
    );
  }

  @override
  Future<BalanceValidationResult> fetchBalance(String walletRef) async {
    if (offline) _throwOffline();
    return BalanceValidationResult(
      walletReference: walletRef,
      balance: serverBalance,
      lastValidatedAt: DateTime.now(),
      catalogVersion: '1.0',
    );
  }

  @override
  Future<List<LedgerEntry>> fetchTransactions(String walletRef) async {
    if (offline || failTransactions) _throwOffline();
    return List.unmodifiable(entries);
  }

  @override
  Future<ReservationTicket> reserveCredits({
    required String walletRef,
    required String featureId,
    required String idempotencyKey,
  }) async {
    if (offline) _throwOffline();
    serverBalance -= 2;
    return ReservationTicket(
      reservationId: 'res_1',
      featureId: featureId,
      amount: 2,
      status: 'reserved',
      balance: serverBalance,
    );
  }

  @override
  Future<ReservationTicket> confirmReservation({
    required String walletRef,
    required String reservationId,
    required String idempotencyKey,
  }) async {
    if (offline) _throwOffline();
    return ReservationTicket(
      reservationId: reservationId,
      featureId: 'detailed_report',
      amount: 2,
      status: 'confirmed',
      balance: serverBalance,
    );
  }

  @override
  Future<ReservationTicket> refundReservation({
    required String walletRef,
    required String reservationId,
    required String idempotencyKey,
  }) async {
    if (offline) _throwOffline();
    refundCalls++;
    serverBalance += 2;
    return ReservationTicket(
      reservationId: reservationId,
      featureId: 'detailed_report',
      amount: 2,
      status: 'refunded',
      balance: serverBalance,
    );
  }

  @override
  Future<WebCheckoutSession> createWebCheckout({
    required String walletRef,
    required String productId,
  }) async {
    if (offline) _throwOffline();
    webCheckoutCalls++;
    return WebCheckoutSession(
      checkoutId: 'chk_123',
      productId: productId,
      credits: 30,
      amountCents: 1190,
      currency: 'BRL',
      status: 'pending',
      checkoutUrl: 'https://checkout.feitolabs.example/chk_123',
    );
  }

  @override
  Future<PlayValidationResult> validatePlayPurchase({
    required String walletRef,
    required String productId,
    required String purchaseToken,
    required String orderId,
    required String idempotencyKey,
  }) async {
    if (offline) _throwOffline();
    playValidations.add(purchaseToken);
    playWallets.add(walletRef);
    if (playValidationError != null) throw playValidationError!;
    if (playAcknowledged) serverBalance += 30;
    return PlayValidationResult(
      balance: serverBalance,
      acknowledged: playAcknowledged,
    );
  }

  @override
  Future<int> claimRewardedAd({
    required String walletRef,
    required String providerTransactionId,
    required String idempotencyKey,
    required String adNetwork,
  }) async {
    if (offline) _throwOffline();
    claimCalls++;
    serverBalance += 1;
    entries.insert(
      0,
      LedgerEntry(
        transactionId: 'tx_ad_1',
        walletReference: walletRef,
        source: 'rewarded_ad_credit',
        productId: 'rewarded_ad',
        creditDelta: 1,
        providerTransactionId: providerTransactionId,
        status: 'completed',
        createdAt: DateTime.now(),
        idempotencyKey: idempotencyKey,
      ),
    );
    return serverBalance;
  }

  @override
  Future<void> sendOperationalEvent({
    required String eventName,
    String? screenName,
    String? platform,
    Map<String, dynamic> metadata = const {},
  }) async {}
}

class FakeAdGateway implements AdGateway {
  final ValueNotifier<bool> _canShow;
  final ValueNotifier<bool> _privacy;
  RewardedAdStatus rewardedStatus;
  VoidCallback? onRewardedShown;
  final List<String> rewardUsers = [];
  final List<String> rewardCustomData = [];

  FakeAdGateway({
    bool canShow = true,
    bool privacyRequired = false,
    this.rewardedStatus = RewardedAdStatus.earned,
  }) : _canShow = ValueNotifier<bool>(canShow),
       _privacy = ValueNotifier<bool>(privacyRequired);

  @override
  bool get isSupported => true;

  @override
  ValueListenable<bool> get canShowAds => _canShow;

  @override
  ValueListenable<bool> get privacyOptionsRequired => _privacy;

  @override
  Future<void> initialize() async {}

  @override
  Widget buildBanner({required AdFrameBuilder frameBuilder}) {
    return Builder(
      builder: (context) => frameBuilder(
        context,
        const SizedBox(key: ValueKey('fake-banner'), height: 100),
      ),
    );
  }

  @override
  Future<RewardedAdStatus> showRewarded({
    required String userId,
    required String customData,
  }) async {
    rewardUsers.add(userId);
    rewardCustomData.add(customData);
    onRewardedShown?.call();
    return rewardedStatus;
  }

  @override
  Future<void> showPrivacyOptions() async {}
}

class FakeBillingGateway implements BillingGateway {
  final StreamController<List<BillingPurchase>> _updates =
      StreamController<List<BillingPurchase>>.broadcast();
  final List<String> boughtProducts = [];
  final List<String> boughtWallets = [];
  final List<String> finishedTokens = [];
  int restoreCalls = 0;
  bool available = true;
  bool opensCheckout = true;
  bool finishFails = false;
  bool storeHangs = false;
  List<BillingPurchase> unfinished = [];
  Map<String, BillingProduct> products = const {
    'meta_feita_credits_10': BillingProduct(
      productId: 'meta_feita_credits_10',
      displayPrice: 'R\$ 5,49',
    ),
    'meta_feita_credits_30': BillingProduct(
      productId: 'meta_feita_credits_30',
      displayPrice: 'R\$ 12,99',
    ),
    'meta_feita_credits_80': BillingProduct(
      productId: 'meta_feita_credits_80',
      displayPrice: 'R\$ 26,99',
    ),
  };

  void emit(BillingPurchase purchase) => _updates.add([purchase]);

  Future<void> dispose() => _updates.close();

  @override
  bool get isSupported => true;

  @override
  Stream<List<BillingPurchase>> get purchases => _updates.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Map<String, BillingProduct>> loadProducts(Set<String> productIds) {
    if (storeHangs) return Completer<Map<String, BillingProduct>>().future;
    return Future.value({
      for (final id in productIds)
        if (products.containsKey(id)) id: products[id]!,
    });
  }

  @override
  Future<bool> buy({
    required String productId,
    required String walletRef,
  }) async {
    boughtProducts.add(productId);
    boughtWallets.add(walletRef);
    return opensCheckout;
  }

  @override
  Future<void> restoreUnfinished() async {
    restoreCalls++;
    if (unfinished.isNotEmpty) _updates.add(unfinished);
  }

  @override
  Future<void> finish(BillingPurchase purchase) async {
    if (finishFails) throw StateError('falha ao consumir');
    finishedTokens.add(purchase.purchaseToken);
  }
}

/// Usa as fontes reais do app: as de teste têm larguras diferentes.
Future<void> loadAppFonts() async {
  const families = {
    'BricolageGrotesque': ['Bold', 'ExtraBold'],
    'HankenGrotesk': ['Regular', 'Medium', 'SemiBold', 'Bold'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final weight in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/${entry.key}-$weight.ttf'));
    }
    await loader.load();
  }
}

/// Controller com carteira confirmada, usado nos testes de monetização.
Future<AppController> onlineController({
  required FakeMonetizationClient api,
  AdGateway ads = const NoAdGateway(),
  BillingGateway billing = const NoBillingGateway(),
  bool serverVerifiesRewards = false,
  Duration storeTimeout = const Duration(seconds: 15),
}) async {
  final controller = AppController(
    storage: InMemoryLocalStorageAdapter(),
    apiClient: api,
    ads: ads,
    billing: billing,
    serverVerifiesRewards: serverVerifiesRewards,
    rewardPollInterval: Duration.zero,
    rewardPollAttempts: 3,
    storeTimeout: storeTimeout,
  );
  await controller.loadLocalState();
  await controller.syncCreditsAndCatalog();
  return controller;
}
