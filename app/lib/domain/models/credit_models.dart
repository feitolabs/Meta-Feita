class CreditPackage {
  final String productId;
  final int credits;
  final String title;
  final String subtitle;
  final int priceCents;
  final String displayPrice;
  final bool highlighted;
  final String playProductId;

  const CreditPackage({
    required this.productId,
    required this.credits,
    required this.title,
    required this.subtitle,
    required this.priceCents,
    required this.displayPrice,
    required this.highlighted,
    required this.playProductId,
  });

  factory CreditPackage.fromJson(Map<String, dynamic> json) {
    return CreditPackage(
      productId: json['productId'] as String,
      credits: json['credits'] as int,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      priceCents: json['priceCents'] as int,
      displayPrice: json['displayPrice'] as String,
      highlighted: json['highlighted'] as bool? ?? false,
      playProductId: json['playProductId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'credits': credits,
    'title': title,
    'subtitle': subtitle,
    'priceCents': priceCents,
    'displayPrice': displayPrice,
    'highlighted': highlighted,
    'playProductId': playProductId,
  };
}

class CreditFeatureCost {
  final String featureId;
  final String title;
  final String description;
  final int creditCost;

  const CreditFeatureCost({
    required this.featureId,
    required this.title,
    required this.description,
    required this.creditCost,
  });

  factory CreditFeatureCost.fromJson(Map<String, dynamic> json) {
    return CreditFeatureCost(
      featureId: json['featureId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      creditCost: json['creditCost'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'featureId': featureId,
    'title': title,
    'description': description,
    'creditCost': creditCost,
  };
}

class RewardedAdConfig {
  final int creditsPerView;
  final int dailyLimit;
  final bool enabled;

  const RewardedAdConfig({
    required this.creditsPerView,
    required this.dailyLimit,
    required this.enabled,
  });

  factory RewardedAdConfig.fromJson(Map<String, dynamic> json) {
    return RewardedAdConfig(
      creditsPerView: json['creditsPerView'] as int,
      dailyLimit: json['dailyLimit'] as int,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'creditsPerView': creditsPerView,
    'dailyLimit': dailyLimit,
    'enabled': enabled,
  };
}

class CreditCatalog {
  final String catalogVersion;
  final String currency;
  final List<CreditPackage> packages;
  final List<CreditFeatureCost> features;
  final RewardedAdConfig rewardedAd;

  const CreditCatalog({
    required this.catalogVersion,
    required this.currency,
    required this.packages,
    required this.features,
    required this.rewardedAd,
  });

  CreditFeatureCost? findFeature(String featureId) {
    for (final f in features) {
      if (f.featureId == featureId) return f;
    }
    return null;
  }

  factory CreditCatalog.fromJson(Map<String, dynamic> json) {
    return CreditCatalog(
      catalogVersion: json['catalogVersion'] as String,
      currency: json['currency'] as String,
      packages: (json['packages'] as List<dynamic>)
          .map((e) => CreditPackage.fromJson(e as Map<String, dynamic>))
          .toList(),
      features: (json['features'] as List<dynamic>)
          .map((e) => CreditFeatureCost.fromJson(e as Map<String, dynamic>))
          .toList(),
      rewardedAd: RewardedAdConfig.fromJson(
        json['rewardedAd'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'catalogVersion': catalogVersion,
    'currency': currency,
    'packages': packages.map((e) => e.toJson()).toList(),
    'features': features.map((e) => e.toJson()).toList(),
    'rewardedAd': rewardedAd.toJson(),
  };
}

enum CreditBalanceStatus { confirmed, cachedOffline, uninitialized }

class LocalCreditCache {
  static const int currentCacheVersion = 1;

  final String walletReference;
  final int cachedBalance;
  final DateTime? lastValidatedAt;
  final CreditBalanceStatus status;
  final int cacheVersion;

  const LocalCreditCache({
    required this.walletReference,
    required this.cachedBalance,
    required this.lastValidatedAt,
    required this.status,
    this.cacheVersion = currentCacheVersion,
  });

  Map<String, dynamic> toJson() => {
    'walletReference': walletReference,
    'cachedBalance': cachedBalance,
    'lastValidatedAt': lastValidatedAt?.toIso8601String(),
    'status': status.name,
    'cacheVersion': cacheVersion,
  };

  factory LocalCreditCache.fromJson(Map<String, dynamic> json) {
    return LocalCreditCache(
      walletReference: json['walletReference'] as String? ?? '',
      cachedBalance: json['cachedBalance'] as int? ?? 0,
      lastValidatedAt: json['lastValidatedAt'] != null
          ? DateTime.tryParse(json['lastValidatedAt'] as String)
          : null,
      status: CreditBalanceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CreditBalanceStatus.cachedOffline,
      ),
      cacheVersion: json['cacheVersion'] as int? ?? 1,
    );
  }
}

class LedgerEntry {
  final String transactionId;
  final String walletReference;
  final String source;
  final String? productId;
  final int creditDelta;
  final String? providerTransactionId;
  final String status;
  final DateTime createdAt;
  final String idempotencyKey;

  const LedgerEntry({
    required this.transactionId,
    required this.walletReference,
    required this.source,
    required this.productId,
    required this.creditDelta,
    required this.providerTransactionId,
    required this.status,
    required this.createdAt,
    required this.idempotencyKey,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      transactionId: json['transactionId'] as String,
      walletReference: json['walletReference'] as String,
      source: json['source'] as String,
      productId: json['productId'] as String?,
      creditDelta: json['creditDelta'] as int,
      providerTransactionId: json['providerTransactionId'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      idempotencyKey: json['idempotencyKey'] as String,
    );
  }
}

class PreferenceModel {
  final String theme;
  final String currency;
  final String locale;
  final bool onboardingCompleted;
  final bool autoSaveSimulations;

  const PreferenceModel({
    this.theme = 'light',
    this.currency = 'BRL',
    this.locale = 'pt-BR',
    this.onboardingCompleted = true,
    this.autoSaveSimulations = false,
  });

  PreferenceModel copyWith({
    String? theme,
    String? currency,
    String? locale,
    bool? onboardingCompleted,
    bool? autoSaveSimulations,
  }) {
    return PreferenceModel(
      theme: theme ?? this.theme,
      currency: currency ?? this.currency,
      locale: locale ?? this.locale,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      autoSaveSimulations: autoSaveSimulations ?? this.autoSaveSimulations,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': theme,
    'currency': currency,
    'locale': locale,
    'onboardingCompleted': onboardingCompleted,
    'autoSaveSimulations': autoSaveSimulations,
  };

  factory PreferenceModel.fromJson(Map<String, dynamic> json) {
    return PreferenceModel(
      theme: json['theme'] as String? ?? 'light',
      currency: json['currency'] as String? ?? 'BRL',
      locale: json['locale'] as String? ?? 'pt-BR',
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? true,
      autoSaveSimulations: json['autoSaveSimulations'] as bool? ?? false,
    );
  }
}
