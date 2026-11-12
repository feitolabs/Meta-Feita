import 'package:flutter/material.dart';

import '../../infrastructure/ads/ad_gateway.dart';
import '../theme/meta_feita_theme.dart';

/// Slot de banner não intrusivo (Doc 01 §5.1 e §9):
/// aparece só em áreas de resultado, nunca sobre campos de entrada.
/// Sem anúncio carregado, não ocupa espaço na tela.
class SafeAdBannerSlot extends StatelessWidget {
  final AdGateway ads;

  const SafeAdBannerSlot({super.key, required this.ads});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ads.canShowAds,
      builder: (context, canShow, _) {
        if (!canShow) return const SizedBox.shrink();
        return ads.buildBanner(frameBuilder: _frame);
      },
    );
  }

  Widget _frame(BuildContext context, Widget ad) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ANÚNCIO', style: MfText.legenda.copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          ad,
        ],
      ),
    );
  }
}
