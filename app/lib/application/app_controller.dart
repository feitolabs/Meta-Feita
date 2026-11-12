import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/credit_models.dart';
import '../domain/models/goal_models.dart';
import '../domain/models/simulation_models.dart';
import '../domain/rules/backup_validator.dart';
import '../infrastructure/ads/ad_gateway.dart';
import '../infrastructure/ads/ad_service.dart';
import '../infrastructure/billing/billing_gateway.dart';
import '../infrastructure/monetization/monetization_api_client.dart';
import '../infrastructure/storage/local_repositories.dart';
import '../infrastructure/storage/local_storage_adapter.dart';

enum RewardOutcome { credited, pendingConfirmation, notEarned, unavailable }

class RewardClaim {
  final RewardOutcome outcome;
  final int? balance;

  const RewardClaim(this.outcome, [this.balance]);
}

class AppController extends ChangeNotifier {
  static const Uuid _uuid = Uuid();

  final LocalStorageAdapter storage;
  late final LocalRepositories _repos;
  final MonetizationClient apiClient;
  final AdGateway ads;
  final BillingGateway billing;

  /// Com blocos reais, o crédito é concedido pelo callback do AdMob ao servidor.
  final bool serverVerifiesRewards;
  final Duration rewardPollInterval;
  final int rewardPollAttempts;

  /// Sem Google Play, a biblioteca de cobrança tenta reconectar indefinidamente.
  final Duration storeTimeout;

  List<SavedSimulation> _simulations = [];
  List<SavedGoal> _goals = [];
  PreferenceModel _preferences = const PreferenceModel();
  LocalCreditCache _creditCache = const LocalCreditCache(
    walletReference: '',
    cachedBalance: 0,
    lastValidatedAt: null,
    status: CreditBalanceStatus.uninitialized,
  );
  CreditCatalog? _catalog;
  List<LedgerEntry> _transactions = [];
  bool _isOnline = false;
  bool _isSyncingCredits = false;
  String? _lastCreditError;
  String? _pendingRecoveryCode;

  StreamSubscription<List<BillingPurchase>>? _billingSubscription;
  Map<String, BillingProduct> _storeProducts = const {};
  final Set<String> _purchaseTokensInFlight = {};
  bool _isPurchasing = false;
  String? _billingNotice;

  AppController({
    required this.storage,
    required this.apiClient,
    this.ads = const NoAdGateway(),
    this.billing = const NoBillingGateway(),
    bool? serverVerifiesRewards,
    this.rewardPollInterval = const Duration(seconds: 2),
    this.rewardPollAttempts = 8,
    this.storeTimeout = const Duration(seconds: 15),
  }) : serverVerifiesRewards =
           serverVerifiesRewards ?? !AdService.isUsingTestIds {
    _repos = LocalRepositories(storage);
  }

  List<SavedSimulation> get simulations => List.unmodifiable(_simulations);
  List<SavedGoal> get goals => List.unmodifiable(_goals);
  PreferenceModel get preferences => _preferences;
  LocalCreditCache get creditCache => _creditCache;
  CreditCatalog get catalog => _catalog ?? _fallbackCatalog;
  List<LedgerEntry> get transactions => List.unmodifiable(_transactions);
  bool get isOnline => _isOnline;
  bool get isSyncingCredits => _isSyncingCredits;
  String? get lastCreditError => _lastCreditError;
  String? get pendingRecoveryCode => _pendingRecoveryCode;
  bool get isPurchasing => _isPurchasing;
  String? get billingNotice => _billingNotice;

  /// O preço da loja, quando conhecido, é o que a pessoa realmente pagará.
  String displayPriceFor(CreditPackage package) =>
      _storeProducts[package.playProductId]?.displayPrice ??
      package.displayPrice;

  int get creditBalance => _creditCache.cachedBalance;
  bool get isBalanceConfirmed =>
      _isOnline && _creditCache.status == CreditBalanceStatus.confirmed;

  SavedGoal? get focusGoal {
    if (_goals.isEmpty) return null;
    for (final g in _goals) {
      if (g.isFocus) return g;
    }
    return _goals.first;
  }

  static const CreditCatalog _fallbackCatalog = CreditCatalog(
    catalogVersion: 'offline-cache',
    currency: 'BRL',
    packages: [
      CreditPackage(
        productId: 'credits_10',
        credits: 10,
        title: '10 créditos',
        subtitle: 'Para testar um recurso avançado',
        priceCents: 490,
        displayPrice: 'R\$ 4,90',
        highlighted: false,
        playProductId: 'meta_feita_credits_10',
      ),
      CreditPackage(
        productId: 'credits_30',
        credits: 30,
        title: '30 créditos',
        subtitle: 'Mais usado',
        priceCents: 1190,
        displayPrice: 'R\$ 11,90',
        highlighted: true,
        playProductId: 'meta_feita_credits_30',
      ),
      CreditPackage(
        productId: 'credits_80',
        credits: 80,
        title: '80 créditos',
        subtitle: 'Para muitas comparações',
        priceCents: 2490,
        displayPrice: 'R\$ 24,90',
        highlighted: false,
        playProductId: 'meta_feita_credits_80',
      ),
    ],
    features: [
      CreditFeatureCost(
        featureId: 'detailed_report',
        title: 'Relatório detalhado',
        description: 'Exportação completa com premissas e série mês a mês.',
        creditCost: 2,
      ),
      CreditFeatureCost(
        featureId: 'extended_comparison',
        title: 'Comparação ampliada (3 a 4 cenários)',
        description: 'Comparação estendida com até 4 cenários simultâneos.',
        creditCost: 2,
      ),
      CreditFeatureCost(
        featureId: 'advanced_reinvestment',
        title: 'Reinvestimento avançado',
        description: 'Auditoria completa por evento e preços múltiplos.',
        creditCost: 3,
      ),
    ],
    rewardedAd: RewardedAdConfig(
      creditsPerView: 1,
      dailyLimit: 5,
      enabled: true,
    ),
  );

  Future<void> loadLocalState() async {
    await storage.init();
    _simulations = _repos.loadSimulations();
    _goals = _repos.loadGoals();
    _preferences = _repos.loadPreferences();
    _creditCache = _repos.loadCreditCache();
    _catalog = _repos.loadCatalogCache();
    notifyListeners();
  }

  Future<void> initialize() async {
    await loadLocalState();
    await syncCreditsAndCatalog();
  }

  Future<void> syncCreditsAndCatalog() async {
    _isSyncingCredits = true;
    _lastCreditError = null;
    notifyListeners();

    try {
      final fetchedCatalog = await apiClient.fetchCatalog();
      _catalog = fetchedCatalog;
      _repos.saveCatalogCache(fetchedCatalog);

      if (_creditCache.walletReference.isEmpty) {
        final init = await apiClient.initWallet();
        _pendingRecoveryCode = init.recoveryCode;
        _creditCache = LocalCreditCache(
          walletReference: init.walletReference,
          cachedBalance: init.balance,
          lastValidatedAt: init.lastValidatedAt,
          status: CreditBalanceStatus.confirmed,
        );
      } else {
        final bal = await apiClient.fetchBalance(_creditCache.walletReference);
        _creditCache = LocalCreditCache(
          walletReference: bal.walletReference,
          cachedBalance: bal.balance,
          lastValidatedAt: bal.lastValidatedAt,
          status: CreditBalanceStatus.confirmed,
        );
      }
      _repos.saveCreditCache(_creditCache);

      _transactions = await apiClient.fetchTransactions(
        _creditCache.walletReference,
      );
      _isOnline = true;
    } catch (e) {
      _isOnline = false;
      if (_creditCache.walletReference.isNotEmpty) {
        _creditCache = LocalCreditCache(
          walletReference: _creditCache.walletReference,
          cachedBalance: _creditCache.cachedBalance,
          lastValidatedAt: _creditCache.lastValidatedAt,
          status: CreditBalanceStatus.cachedOffline,
        );
        _repos.saveCreditCache(_creditCache);
      }
      _lastCreditError =
          'Sem conexão com o servidor de créditos. Calculadoras locais seguem disponíveis offline.';
    } finally {
      _isSyncingCredits = false;
      notifyListeners();
    }
  }

  void dismissPendingRecoveryCode() {
    _pendingRecoveryCode = null;
    notifyListeners();
  }

  // --- Simulações locais ---

  void saveSimulation({
    String? existingId,
    required String title,
    required SimulationType type,
    required String summaryLabel,
    required Map<String, dynamic> inputData,
    required Map<String, dynamic> resultData,
  }) {
    final now = DateTime.now();
    if (existingId != null) {
      final idx = _simulations.indexWhere((s) => s.id == existingId);
      if (idx != -1) {
        _simulations[idx] = _simulations[idx].copyWith(
          title: title,
          summaryLabel: summaryLabel,
          inputData: inputData,
          resultData: resultData,
          updatedAt: now,
        );
        _simulations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _repos.saveSimulations(_simulations);
        notifyListeners();
        return;
      }
    }

    final item = SavedSimulation(
      id: _uuid.v4(),
      title: title,
      type: type,
      summaryLabel: summaryLabel,
      inputData: inputData,
      resultData: resultData,
      createdAt: now,
      updatedAt: now,
    );
    _simulations = [item, ..._simulations];
    _repos.saveSimulations(_simulations);
    notifyListeners();
  }

  void renameSimulation(String id, String newTitle) {
    final idx = _simulations.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    _simulations[idx] = _simulations[idx].copyWith(
      title: newTitle.trim(),
      updatedAt: DateTime.now(),
    );
    _simulations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _repos.saveSimulations(_simulations);
    notifyListeners();
  }

  void deleteSimulation(String id) {
    _simulations = _simulations.where((s) => s.id != id).toList();
    _repos.saveSimulations(_simulations);
    notifyListeners();
  }

  // --- Metas locais ---

  void saveGoal(SavedGoal goal) {
    final updated = List<SavedGoal>.from(_goals);
    if (goal.isFocus) {
      for (var i = 0; i < updated.length; i++) {
        if (updated[i].id != goal.id && updated[i].isFocus) {
          updated[i] = updated[i].copyWith(isFocus: false);
        }
      }
    }

    final idx = updated.indexWhere((g) => g.id == goal.id);
    if (idx != -1) {
      updated[idx] = goal;
    } else {
      final shouldBeFocus = updated.isEmpty || goal.isFocus;
      updated.insert(0, goal.copyWith(isFocus: shouldBeFocus));
    }
    _goals = updated..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _repos.saveGoals(_goals);
    notifyListeners();
  }

  void setFocusGoal(String id) {
    _goals = _goals.map((g) => g.copyWith(isFocus: g.id == id)).toList();
    _repos.saveGoals(_goals);
    notifyListeners();
  }

  void deleteGoal(String id) {
    _goals = _goals.where((g) => g.id != id).toList();
    if (_goals.isNotEmpty && !_goals.any((g) => g.isFocus)) {
      _goals[0] = _goals[0].copyWith(isFocus: true);
    }
    _repos.saveGoals(_goals);
    notifyListeners();
  }

  // --- Preferências e Backup ---

  void updatePreferences(PreferenceModel prefs) {
    _preferences = prefs;
    _repos.savePreferences(_preferences);
    notifyListeners();
  }

  void applyBackup(BackupPayload payload, {required bool replaceAll}) {
    if (replaceAll) {
      _simulations = List<SavedSimulation>.from(payload.simulations);
      _goals = List<SavedGoal>.from(payload.goals);
      _preferences = payload.preferences;
    } else {
      final simMap = {for (final s in _simulations) s.id: s};
      for (final s in payload.simulations) {
        simMap[s.id] = s;
      }
      _simulations = simMap.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final goalMap = {for (final g in _goals) g.id: g};
      for (final g in payload.goals) {
        goalMap[g.id] = g;
      }
      _goals = goalMap.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    _repos.saveSimulations(_simulations);
    _repos.saveGoals(_goals);
    _repos.savePreferences(_preferences);
    notifyListeners();
  }

  void clearAllLocalFinancialData() {
    _simulations = [];
    _goals = [];
    _preferences = const PreferenceModel();
    _repos.clearFinancialData();
    notifyListeners();
  }

  // --- Monetização / Créditos ---

  Future<bool> recoverWallet(String walletRef, String recoveryCode) async {
    final bal = await apiClient.recoverWallet(
      walletRef.trim(),
      recoveryCode.trim(),
    );
    _creditCache = LocalCreditCache(
      walletReference: bal.walletReference,
      cachedBalance: bal.balance,
      lastValidatedAt: bal.lastValidatedAt,
      status: CreditBalanceStatus.confirmed,
    );
    _repos.saveCreditCache(_creditCache);
    _transactions = await apiClient.fetchTransactions(bal.walletReference);
    _isOnline = true;
    notifyListeners();
    return true;
  }

  Future<RewardClaim> watchRewardedAd() async {
    if (_creditCache.walletReference.isEmpty) {
      await syncCreditsAndCatalog();
    }
    if (_creditCache.walletReference.isEmpty) {
      throw const MonetizationApiException(
        'OFFLINE',
        'Conecte-se à internet para validar a recompensa de anúncio.',
      );
    }

    final walletRef = _creditCache.walletReference;
    final rewardReference = _uuid.v4();
    final status = await ads.showRewarded(
      userId: walletRef,
      customData: rewardReference,
    );
    switch (status) {
      case RewardedAdStatus.unavailable:
        return const RewardClaim(RewardOutcome.unavailable);
      case RewardedAdStatus.dismissedWithoutReward:
        return const RewardClaim(RewardOutcome.notEarned);
      case RewardedAdStatus.earned:
        break;
    }

    if (serverVerifiesRewards) {
      return _awaitServerReward(walletRef, rewardReference);
    }

    final newBalance = await apiClient.claimRewardedAd(
      walletRef: walletRef,
      providerTransactionId: 'ad_$rewardReference',
      idempotencyKey: rewardReference,
      adNetwork: 'admob_test',
    );
    _updateBalanceConfirmed(newBalance);
    _transactions = await apiClient.fetchTransactions(walletRef);
    notifyListeners();
    return RewardClaim(RewardOutcome.credited, newBalance);
  }

  Future<RewardClaim> _awaitServerReward(
    String walletRef,
    String rewardReference,
  ) async {
    for (var attempt = 0; attempt < rewardPollAttempts; attempt++) {
      await Future<void>.delayed(rewardPollInterval);
      final List<LedgerEntry> entries;
      try {
        entries = await apiClient.fetchTransactions(walletRef);
      } on Exception {
        continue;
      }
      if (entries.any((e) => e.idempotencyKey == rewardReference)) {
        final balance = await apiClient.fetchBalance(walletRef);
        _updateBalanceConfirmed(balance.balance);
        _transactions = entries;
        notifyListeners();
        return RewardClaim(RewardOutcome.credited, balance.balance);
      }
    }
    return const RewardClaim(RewardOutcome.pendingConfirmation);
  }

  // --- Google Play Billing ---

  /// Escuta a loja e retoma compras pagas cujo crédito não foi concluído.
  Future<void> startBilling() async {
    if (!billing.isSupported || _billingSubscription != null) return;
    _billingSubscription = billing.purchases.listen(
      (updates) => unawaited(_handlePurchaseUpdates(updates)),
      onError: (Object _) => _endPurchaseAttempt(_purchaseFailedNotice),
    );
    try {
      if (!await billing.isAvailable().timeout(storeTimeout)) return;
      await _loadStoreProducts();
      await billing.restoreUnfinished().timeout(storeTimeout);
    } on Exception {
      // Sem a loja agora: uma nova tentativa ocorre na compra ou ao reabrir o app.
    }
  }

  static const String _purchaseFailedNotice =
      'A compra não foi concluída. Nenhum crédito foi alterado.';

  Future<void> _loadStoreProducts() async {
    final ids = catalog.packages.map((p) => p.playProductId).toSet();
    _storeProducts = await billing.loadProducts(ids).timeout(storeTimeout);
    notifyListeners();
  }

  Future<void> buyCreditPackage(CreditPackage package) async {
    if (_creditCache.walletReference.isEmpty) {
      await syncCreditsAndCatalog();
    }
    if (_creditCache.walletReference.isEmpty) {
      throw const MonetizationApiException(
        'OFFLINE',
        'Conecte-se à internet para iniciar a compra de créditos.',
      );
    }
    await startBilling();
    if (!_storeProducts.containsKey(package.playProductId)) {
      try {
        await _loadStoreProducts();
      } on Exception {
        // Tratado abaixo: o pacote continua indisponível.
      }
    }
    if (!_storeProducts.containsKey(package.playProductId)) {
      throw const MonetizationApiException(
        'BILLING_UNAVAILABLE',
        'Este pacote não está disponível na Google Play agora.',
      );
    }

    _isPurchasing = true;
    _billingNotice = null;
    notifyListeners();
    try {
      final opened = await billing.buy(
        productId: package.playProductId,
        walletRef: _creditCache.walletReference,
      );
      if (!opened) _endPurchaseAttempt(_purchaseFailedNotice);
    } on Exception {
      _endPurchaseAttempt(_purchaseFailedNotice);
      // Uma compra anterior ainda não consumida impede uma nova do mesmo item.
      unawaited(billing.restoreUnfinished().catchError((Object _) {}));
    }
  }

  void _endPurchaseAttempt(String? notice) {
    _isPurchasing = false;
    _billingNotice = notice;
    notifyListeners();
  }

  Future<void> _handlePurchaseUpdates(List<BillingPurchase> updates) async {
    for (final purchase in updates) {
      switch (purchase.status) {
        case BillingPurchaseStatus.pending:
          _endPurchaseAttempt(_purchasePendingNotice);
        case BillingPurchaseStatus.canceled:
          _endPurchaseAttempt(null);
        case BillingPurchaseStatus.error:
          _endPurchaseAttempt(_purchaseFailedNotice);
        case BillingPurchaseStatus.purchased:
        case BillingPurchaseStatus.restored:
          await _fulfillPurchase(purchase);
      }
    }
  }

  static const String _purchasePendingNotice =
      'Pagamento pendente. Os créditos entram assim que a Google Play confirmar.';

  Future<void> _fulfillPurchase(BillingPurchase purchase) async {
    final token = purchase.purchaseToken;
    if (!_purchaseTokensInFlight.add(token)) return;

    final accountId = purchase.accountId;
    final walletRef = accountId != null && accountId.isNotEmpty
        ? accountId
        : _creditCache.walletReference;
    final isNewPurchase = purchase.status == BillingPurchaseStatus.purchased;

    try {
      if (walletRef.isEmpty) {
        // Compra fica sem consumir e volta na próxima abertura do app.
        _endPurchaseAttempt(null);
        return;
      }

      final PlayValidationResult result;
      try {
        result = await apiClient.validatePlayPurchase(
          walletRef: walletRef,
          productId: purchase.productId,
          purchaseToken: token,
          orderId: purchase.orderId ?? 'pedido-indisponivel',
          idempotencyKey: _uuid.v5(Namespace.url.value, token),
        );
      } on Exception {
        _endPurchaseAttempt(
          isNewPurchase
              ? 'Pagamento recebido, mas ainda não confirmado. Tentaremos de novo ao reabrir o app.'
              : null,
        );
        return;
      }

      if (!result.acknowledged) {
        _endPurchaseAttempt(_purchasePendingNotice);
        return;
      }

      // O crédito já foi concedido; se consumir falhar, repete sem conceder de novo.
      try {
        await billing.finish(purchase);
      } on Exception {
        debugPrint('Consumo da compra será repetido ao reabrir o app.');
      } on StateError {
        debugPrint('Consumo da compra será repetido ao reabrir o app.');
      }

      if (walletRef == _creditCache.walletReference) {
        _updateBalanceConfirmed(result.balance);
        try {
          _transactions = await apiClient.fetchTransactions(walletRef);
        } on Exception {
          // O saldo já está confirmado; o extrato atualiza na próxima sincronização.
        }
      } else {
        await syncCreditsAndCatalog();
      }
      _endPurchaseAttempt(
        isNewPurchase
            ? 'Compra confirmada. Saldo: $creditBalance créditos.'
            : null,
      );
    } finally {
      _purchaseTokensInFlight.remove(token);
    }
  }

  @override
  void dispose() {
    _billingSubscription?.cancel();
    super.dispose();
  }

  Future<WebCheckoutSession> initiateWebCheckout(String productId) async {
    if (_creditCache.walletReference.isEmpty) {
      await syncCreditsAndCatalog();
    }
    if (_creditCache.walletReference.isEmpty) {
      throw const MonetizationApiException(
        'OFFLINE',
        'Conecte-se à internet para iniciar a compra de créditos.',
      );
    }
    return apiClient.createWebCheckout(
      walletRef: _creditCache.walletReference,
      productId: productId,
    );
  }

  /// Executa ação paga usando reserva -> ação -> confirmação,
  /// garantindo estorno automático caso o processamento falhe antes de concluir.
  Future<T> executeWithCredits<T>({
    required String featureId,
    required Future<T> Function() action,
  }) async {
    if (!isBalanceConfirmed || _creditCache.walletReference.isEmpty) {
      throw const MonetizationApiException(
        'OFFLINE_BLOCKED',
        'Recursos pagos em créditos exigem conexão para confirmação do saldo.',
      );
    }
    final ticket = await apiClient.reserveCredits(
      walletRef: _creditCache.walletReference,
      featureId: featureId,
      idempotencyKey: _uuid.v4(),
    );
    _updateBalanceConfirmed(ticket.balance);
    notifyListeners();

    final T result;
    try {
      result = await action();
      final confirmed = await apiClient.confirmReservation(
        walletRef: _creditCache.walletReference,
        reservationId: ticket.reservationId,
        idempotencyKey: _uuid.v4(),
      );
      _updateBalanceConfirmed(confirmed.balance);
    } catch (err) {
      try {
        final refunded = await apiClient.refundReservation(
          walletRef: _creditCache.walletReference,
          reservationId: ticket.reservationId,
          idempotencyKey: _uuid.v4(),
        );
        _updateBalanceConfirmed(refunded.balance);
        _transactions = await apiClient.fetchTransactions(
          _creditCache.walletReference,
        );
        notifyListeners();
      } catch (_) {}
      rethrow;
    }

    // O uso já foi confirmado: falha ao atualizar o extrato não pode virar erro
    // nem estorno (o servidor recusaria, e a pessoa já recebeu o recurso).
    notifyListeners();
    try {
      _transactions = await apiClient.fetchTransactions(
        _creditCache.walletReference,
      );
      notifyListeners();
    } on Exception {
      // O extrato é atualizado na próxima sincronização.
    }
    return result;
  }

  void _updateBalanceConfirmed(int balance) {
    _creditCache = LocalCreditCache(
      walletReference: _creditCache.walletReference,
      cachedBalance: balance,
      lastValidatedAt: DateTime.now(),
      status: CreditBalanceStatus.confirmed,
    );
    _repos.saveCreditCache(_creditCache);
    _isOnline = true;
  }

  void trackScreen(String screenName) {
    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            _ => 'desktop',
          };
    apiClient.sendOperationalEvent(
      eventName: 'screen_view',
      screenName: screenName,
      platform: platform,
    );
  }
}
