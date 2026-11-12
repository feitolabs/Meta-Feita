import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/credit_models.dart';

class MonetizationApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const MonetizationApiException(this.code, this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class WalletInitResult {
  final String walletReference;
  final int balance;
  final String recoveryCode;
  final DateTime lastValidatedAt;

  const WalletInitResult({
    required this.walletReference,
    required this.balance,
    required this.recoveryCode,
    required this.lastValidatedAt,
  });
}

class BalanceValidationResult {
  final String walletReference;
  final int balance;
  final DateTime lastValidatedAt;
  final String catalogVersion;

  const BalanceValidationResult({
    required this.walletReference,
    required this.balance,
    required this.lastValidatedAt,
    required this.catalogVersion,
  });
}

class PlayValidationResult {
  final int balance;

  /// Verdadeiro somente quando a compra está paga e os créditos foram concedidos.
  final bool acknowledged;

  const PlayValidationResult({
    required this.balance,
    required this.acknowledged,
  });
}

class WebCheckoutSession {
  final String checkoutId;
  final String productId;
  final int credits;
  final int amountCents;
  final String currency;
  final String status;
  final String checkoutUrl;

  const WebCheckoutSession({
    required this.checkoutId,
    required this.productId,
    required this.credits,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.checkoutUrl,
  });
}

class ReservationTicket {
  final String reservationId;
  final String featureId;
  final int amount;
  final String status;
  final int balance;

  const ReservationTicket({
    required this.reservationId,
    required this.featureId,
    required this.amount,
    required this.status,
    required this.balance,
  });
}

abstract class MonetizationClient {
  Future<CreditCatalog> fetchCatalog();
  Future<WalletInitResult> initWallet();
  Future<BalanceValidationResult> recoverWallet(
    String walletRef,
    String recoveryCode,
  );
  Future<BalanceValidationResult> fetchBalance(String walletRef);
  Future<List<LedgerEntry>> fetchTransactions(String walletRef);
  Future<ReservationTicket> reserveCredits({
    required String walletRef,
    required String featureId,
    required String idempotencyKey,
  });
  Future<ReservationTicket> confirmReservation({
    required String walletRef,
    required String reservationId,
    required String idempotencyKey,
  });
  Future<ReservationTicket> refundReservation({
    required String walletRef,
    required String reservationId,
    required String idempotencyKey,
  });
  Future<WebCheckoutSession> createWebCheckout({
    required String walletRef,
    required String productId,
  });
  Future<PlayValidationResult> validatePlayPurchase({
    required String walletRef,
    required String productId,
    required String purchaseToken,
    required String orderId,
    required String idempotencyKey,
  });
  Future<int> claimRewardedAd({
    required String walletRef,
    required String providerTransactionId,
    required String idempotencyKey,
    required String adNetwork,
  });
  Future<void> sendOperationalEvent({
    required String eventName,
    String? screenName,
    String? platform,
    Map<String, dynamic> metadata = const {},
  });
}

class HttpMonetizationApiClient implements MonetizationClient {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  final String baseUrl;
  final http.Client _http;
  final Duration timeout;

  HttpMonetizationApiClient({
    String? baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : baseUrl = (baseUrl ?? defaultBaseUrl).replaceAll(RegExp(r'/+$'), ''),
       _http = client ?? http.Client();

  Uri _uri(String path) {
    if (kReleaseMode && !baseUrl.startsWith('https://')) {
      throw const MonetizationApiException(
        'INSECURE_API_URL',
        'Serviço de créditos sem conexão segura configurada.',
      );
    }
    return Uri.parse('$baseUrl$path');
  }

  Map<String, dynamic> _decodeResponse(http.Response res) {
    final Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } on FormatException {
      // Erro do proxy ou da hospedagem (HTML ou texto), não do serviço de créditos.
      throw MonetizationApiException(
        'HTTP_${res.statusCode}',
        'O serviço de créditos está indisponível no momento. Tente novamente em instantes.',
        res.statusCode,
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is! Map) {
        throw MonetizationApiException(
          'BAD_RESPONSE',
          'Resposta inesperada do serviço de créditos.',
          res.statusCode,
        );
      }
      return Map<String, dynamic>.from(decoded);
    }
    if (decoded is Map) {
      throw MonetizationApiException(
        decoded['code']?.toString() ?? 'HTTP_${res.statusCode}',
        decoded['message']?.toString() ??
            'Erro de comunicação com o serviço de créditos.',
        res.statusCode,
      );
    }
    throw MonetizationApiException(
      'HTTP_${res.statusCode}',
      'Erro HTTP ${res.statusCode} ao consultar o serviço de créditos.',
      res.statusCode,
    );
  }

  @override
  Future<CreditCatalog> fetchCatalog() async {
    final res = await _http.get(_uri('/v1/catalog')).timeout(timeout);
    return CreditCatalog.fromJson(_decodeResponse(res));
  }

  @override
  Future<WalletInitResult> initWallet() async {
    final res = await _http.post(_uri('/v1/wallets/init')).timeout(timeout);
    final data = _decodeResponse(res);
    return WalletInitResult(
      walletReference: data['walletReference'] as String,
      balance: data['balance'] as int,
      recoveryCode: data['recoveryCode'] as String,
      lastValidatedAt: DateTime.parse(data['lastValidatedAt'] as String),
    );
  }

  @override
  Future<BalanceValidationResult> recoverWallet(
    String walletRef,
    String recoveryCode,
  ) async {
    final res = await _http
        .post(
          _uri('/v1/wallets/recover'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletReference': walletRef,
            'recoveryCode': recoveryCode,
          }),
        )
        .timeout(timeout);
    final data = _decodeResponse(res);
    return BalanceValidationResult(
      walletReference: data['walletReference'] as String,
      balance: data['balance'] as int,
      lastValidatedAt: DateTime.parse(data['lastValidatedAt'] as String),
      catalogVersion: data['catalogVersion'] as String,
    );
  }

  @override
  Future<BalanceValidationResult> fetchBalance(String walletRef) async {
    final res = await _http
        .get(_uri('/v1/wallets/$walletRef/balance'))
        .timeout(timeout);
    final data = _decodeResponse(res);
    return BalanceValidationResult(
      walletReference: data['walletReference'] as String,
      balance: data['balance'] as int,
      lastValidatedAt: DateTime.parse(data['lastValidatedAt'] as String),
      catalogVersion: data['catalogVersion'] as String,
    );
  }

  @override
  Future<List<LedgerEntry>> fetchTransactions(String walletRef) async {
    final res = await _http
        .get(_uri('/v1/wallets/$walletRef/transactions'))
        .timeout(timeout);
    final data = _decodeResponse(res);
    return (data['transactions'] as List<dynamic>)
        .map((e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<ReservationTicket> reserveCredits({
    required String walletRef,
    required String featureId,
    required String idempotencyKey,
  }) async {
    final res = await _http
        .post(
          _uri('/v1/credits/reserve'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletReference': walletRef,
            'featureId': featureId,
            'idempotencyKey': idempotencyKey,
          }),
        )
        .timeout(timeout);
    final data = _decodeResponse(res);
    return ReservationTicket(
      reservationId: data['reservationId'] as String,
      featureId: data['featureId'] as String,
      amount: data['amount'] as int,
      status: data['status'] as String,
      balance: data['balance'] as int,
    );
  }

  @override
  Future<ReservationTicket> confirmReservation({
    required String walletRef,
    required String reservationId,
    required String idempotencyKey,
  }) async {
    final res = await _http
        .post(
          _uri('/v1/credits/confirm'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletReference': walletRef,
            'reservationId': reservationId,
            'idempotencyKey': idempotencyKey,
          }),
        )
        .timeout(timeout);
    final data = _decodeResponse(res);
    return ReservationTicket(
      reservationId: data['reservationId'] as String,
      featureId: data['featureId'] as String,
      amount: data['amount'] as int,
      status: data['status'] as String,
      balance: data['balance'] as int,
    );
  }

  @override
  Future<ReservationTicket> refundReservation({
    required String walletRef,
    required String reservationId,
    required String idempotencyKey,
  }) async {
    final res = await _http
        .post(
          _uri('/v1/credits/refund'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletReference': walletRef,
            'reservationId': reservationId,
            'idempotencyKey': idempotencyKey,
          }),
        )
        .timeout(timeout);
    final data = _decodeResponse(res);
    return ReservationTicket(
      reservationId: data['reservationId'] as String,
      featureId: data['featureId'] as String,
      amount: data['amount'] as int,
      status: data['status'] as String,
      balance: data['balance'] as int,
    );
  }

  @override
  Future<WebCheckoutSession> createWebCheckout({
    required String walletRef,
    required String productId,
  }) async {
    final res = await _http
        .post(
          _uri('/v1/purchases/web/checkout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletReference': walletRef,
            'productId': productId,
          }),
        )
        .timeout(timeout);
    final data = _decodeResponse(res);
    return WebCheckoutSession(
      checkoutId: data['checkoutId'] as String,
      productId: data['productId'] as String,
      credits: data['credits'] as int,
      amountCents: data['amountCents'] as int,
      currency: data['currency'] as String,
      status: data['status'] as String,
      checkoutUrl: data['checkoutUrl'] as String,
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
    final res = await _http
        .post(
          _uri('/v1/purchases/play/validate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletReference': walletRef,
            'productId': productId,
            'purchaseToken': purchaseToken,
            'orderId': orderId,
            'purchaseState': 'purchased',
            'idempotencyKey': idempotencyKey,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final data = _decodeResponse(res);
    return PlayValidationResult(
      balance: data['balance'] as int,
      acknowledged: data['acknowledged'] as bool,
    );
  }

  @override
  Future<int> claimRewardedAd({
    required String walletRef,
    required String providerTransactionId,
    required String idempotencyKey,
    required String adNetwork,
  }) async {
    final res = await _http
        .post(
          _uri('/v1/ads/rewarded/claim'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletReference': walletRef,
            'providerTransactionId': providerTransactionId,
            'idempotencyKey': idempotencyKey,
            'adNetwork': adNetwork,
          }),
        )
        .timeout(timeout);
    final data = _decodeResponse(res);
    return data['balance'] as int;
  }

  @override
  Future<void> sendOperationalEvent({
    required String eventName,
    String? screenName,
    String? platform,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await _http
          .post(
            _uri('/v1/telemetry/events'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'eventName': eventName,
              'screenName': ?screenName,
              'platform': ?platform,
              'metadata': metadata,
            }),
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Telemetria operacional nunca bloqueia uso offline do app.
    }
  }
}
