import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum RewardedAdStatus { earned, dismissedWithoutReward, unavailable }

/// Recebe o anúncio já carregado e devolve o widget com rótulo e espaçamento.
typedef AdFrameBuilder = Widget Function(BuildContext context, Widget ad);

/// Porta de publicidade. Nenhum método recebe valores financeiros (Doc 01 §9).
abstract class AdGateway {
  bool get isSupported;

  /// Verdadeiro depois do consentimento e da inicialização do SDK.
  ValueListenable<bool> get canShowAds;

  /// Verdadeiro quando a região exige um acesso permanente às opções de privacidade.
  ValueListenable<bool> get privacyOptionsRequired;

  Future<void> initialize();

  Widget buildBanner({required AdFrameBuilder frameBuilder});

  Future<RewardedAdStatus> showRewarded({
    required String userId,
    required String customData,
  });

  Future<void> showPrivacyOptions();
}

/// Usado onde não há publicidade: Web, iOS, desktop e testes.
class NoAdGateway implements AdGateway {
  const NoAdGateway();

  static final ValueNotifier<bool> _alwaysFalse = ValueNotifier<bool>(false);

  @override
  bool get isSupported => false;

  @override
  ValueListenable<bool> get canShowAds => _alwaysFalse;

  @override
  ValueListenable<bool> get privacyOptionsRequired => _alwaysFalse;

  @override
  Future<void> initialize() async {}

  @override
  Widget buildBanner({required AdFrameBuilder frameBuilder}) =>
      const SizedBox.shrink();

  @override
  Future<RewardedAdStatus> showRewarded({
    required String userId,
    required String customData,
  }) async => RewardedAdStatus.unavailable;

  @override
  Future<void> showPrivacyOptions() async {}
}
