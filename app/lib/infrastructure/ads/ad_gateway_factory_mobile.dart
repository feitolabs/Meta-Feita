import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_gateway.dart';
import 'ad_service.dart';

AdGateway createAdGateway() {
  // Doc 01 §9: a publicidade nativa prevista é AdMob no Android.
  if (defaultTargetPlatform == TargetPlatform.android) {
    return GoogleMobileAdGateway();
  }
  return const NoAdGateway();
}

class GoogleMobileAdGateway implements AdGateway {
  static const Duration _consentLookupTimeout = Duration(seconds: 15);
  static const Duration _rewardedLoadTimeout = Duration(seconds: 30);

  final ValueNotifier<bool> _canShowAds = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _privacyOptionsRequired = ValueNotifier<bool>(
    false,
  );
  bool _initializeStarted = false;
  bool _sdkStarted = false;

  @override
  bool get isSupported => true;

  @override
  ValueListenable<bool> get canShowAds => _canShowAds;

  @override
  ValueListenable<bool> get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<void> initialize() async {
    if (_initializeStarted) return;
    _initializeStarted = true;
    await _gatherConsent();
    await _applyConsentState();
  }

  /// Falhas aqui nunca impedem o uso do app; apenas mantêm os anúncios desligados.
  Future<void> _gatherConsent() async {
    final lookup = Completer<bool>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          if (!lookup.isCompleted) lookup.complete(true);
        },
        (_) {
          if (!lookup.isCompleted) lookup.complete(false);
        },
      );
      final updated = await lookup.future.timeout(
        _consentLookupTimeout,
        onTimeout: () => false,
      );
      if (!updated) return;

      // Sem tempo limite: aguarda a pessoa responder ao formulário.
      final answered = Completer<void>();
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!answered.isCompleted) answered.complete();
      });
      await answered.future;
    } on PlatformException catch (error) {
      debugPrint('Consentimento de anúncios indisponível: ${error.code}');
    }
  }

  Future<void> _applyConsentState() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _privacyOptionsRequired.value =
          status == PrivacyOptionsRequirementStatus.required;

      final allowed = await ConsentInformation.instance.canRequestAds();
      if (allowed && !_sdkStarted) {
        await MobileAds.instance.initialize();
        _sdkStarted = true;
      }
      _canShowAds.value = allowed && _sdkStarted;
    } on PlatformException catch (error) {
      debugPrint('Falha ao iniciar anúncios: ${error.code}');
      _canShowAds.value = false;
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    try {
      final closed = Completer<void>();
      await ConsentForm.showPrivacyOptionsForm((_) {
        if (!closed.isCompleted) closed.complete();
      });
      await closed.future;
    } on PlatformException catch (error) {
      debugPrint('Opções de privacidade indisponíveis: ${error.code}');
    }
    await _applyConsentState();
  }

  @override
  Widget buildBanner({required AdFrameBuilder frameBuilder}) {
    return _InlineBanner(frameBuilder: frameBuilder);
  }

  @override
  Future<RewardedAdStatus> showRewarded({
    required String userId,
    required String customData,
  }) async {
    if (!_canShowAds.value) return RewardedAdStatus.unavailable;

    final loaded = Completer<RewardedAd?>();
    await RewardedAd.load(
      adUnitId: AdService.currentRewardedUnitId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (loaded.isCompleted) {
            ad.dispose();
          } else {
            loaded.complete(ad);
          }
        },
        onAdFailedToLoad: (_) {
          if (!loaded.isCompleted) loaded.complete(null);
        },
      ),
    );
    final ad = await loaded.future.timeout(
      _rewardedLoadTimeout,
      onTimeout: () => null,
    );
    if (ad == null) return RewardedAdStatus.unavailable;

    var earned = false;
    final finished = Completer<RewardedAdStatus>();
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        if (!finished.isCompleted) {
          finished.complete(
            earned
                ? RewardedAdStatus.earned
                : RewardedAdStatus.dismissedWithoutReward,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (failed, _) {
        failed.dispose();
        if (!finished.isCompleted) {
          finished.complete(RewardedAdStatus.unavailable);
        }
      },
    );
    await ad.setServerSideOptions(
      ServerSideVerificationOptions(userId: userId, customData: customData),
    );
    await ad.show(
      onUserEarnedReward: (_, _) {
        earned = true;
      },
    );
    return finished.future;
  }
}

/// Banner dentro do conteúdo rolável. Sem anúncio carregado, não ocupa espaço.
class _InlineBanner extends StatefulWidget {
  final AdFrameBuilder frameBuilder;

  const _InlineBanner({required this.frameBuilder});

  @override
  State<_InlineBanner> createState() => _InlineBannerState();
}

class _InlineBannerState extends State<_InlineBanner> {
  static const int _maxHeight = 120;

  BannerAd? _ad;
  AdSize? _loadedSize;
  int? _requestedWidth;

  void _load(int width) {
    if (!mounted) return;
    final previous = _ad;
    setState(() {
      _ad = null;
      _loadedSize = null;
    });
    previous?.dispose();

    late final BannerAd banner;
    banner = BannerAd(
      adUnitId: AdService.currentBannerUnitId(),
      size: AdSize.getInlineAdaptiveBannerAdSize(width, _maxHeight),
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => _onLoaded(banner),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (identical(_ad, banner)) _ad = null;
        },
      ),
    );
    _ad = banner;
    banner.load();
  }

  Future<void> _onLoaded(BannerAd banner) async {
    final size = await banner.getPlatformAdSize();
    if (!mounted || !identical(_ad, banner)) return;
    if (size == null) {
      _ad = null;
      await banner.dispose();
      return;
    }
    setState(() => _loadedSize = size);
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.truncate();
        if (width > 0 && width != _requestedWidth) {
          _requestedWidth = width;
          WidgetsBinding.instance.addPostFrameCallback((_) => _load(width));
        }

        final ad = _ad;
        final size = _loadedSize;
        if (ad == null || size == null) return const SizedBox.shrink();

        return widget.frameBuilder(
          context,
          Center(
            child: SizedBox(
              width: size.width.toDouble(),
              height: size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        );
      },
    );
  }
}
