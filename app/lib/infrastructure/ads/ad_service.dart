import 'package:flutter/foundation.dart';

/// Adaptador de publicidade em conformidade com Doc 01 §9:
/// - Usa IDs oficiais de teste do Google AdMob em desenvolvimento.
/// - Nunca envia parâmetros financeiros ou conteúdo das simulações.
/// - Nunca exibe anúncios antes do resultado básico nem sobre campos de entrada.
class AdService {
  static const String androidBannerId = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String iosBannerId = String.fromEnvironment(
    'ADMOB_BANNER_IOS_ID',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );
  static const String androidRewardedId = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const String iosRewardedId = String.fromEnvironment(
    'ADMOB_REWARDED_IOS_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  static bool get isUsingTestIds =>
      androidBannerId == 'ca-app-pub-3940256099942544/6300978111';

  static String currentBannerUnitId() {
    if (kIsWeb) return 'web-ad-slot-consent';
    return defaultTargetPlatform == TargetPlatform.iOS
        ? iosBannerId
        : androidBannerId;
  }

  static String currentRewardedUnitId() {
    if (kIsWeb) return 'web-rewarded-slot';
    return defaultTargetPlatform == TargetPlatform.iOS
        ? iosRewardedId
        : androidRewardedId;
  }
}

