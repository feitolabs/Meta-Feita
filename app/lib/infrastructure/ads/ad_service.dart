import 'package:flutter/foundation.dart';

/// Identificadores de anúncios em conformidade com Doc 01 §9:
/// - Usa IDs oficiais de teste do Google AdMob em desenvolvimento.
/// - IDs reais vêm de --dart-define-from-file; teste e produção nunca se misturam.
class AdService {
  static const String _googleTestPublisher = 'ca-app-pub-3940256099942544';

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

  /// Blocos de teste do Google não disparam o callback de verificação no servidor.
  static bool get isUsingTestIds =>
      currentRewardedUnitId().startsWith(_googleTestPublisher);

  static String currentBannerUnitId() {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? iosBannerId
        : androidBannerId;
  }

  static String currentRewardedUnitId() {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? iosRewardedId
        : androidRewardedId;
  }
}
