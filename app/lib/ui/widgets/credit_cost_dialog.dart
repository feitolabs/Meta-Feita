import 'package:flutter/material.dart';

import '../../infrastructure/ads/ad_service.dart';
import '../theme/meta_feita_theme.dart';
import 'cards.dart';
import 'meta_feita_buttons.dart';
import 'meta_feita_icon.dart';

/// Confirmação explícita "ANTES DE USAR" idêntica à Página 7 do protótipo.
Future<bool> showCreditCostConfirmationDialog(
  BuildContext context, {
  required String featureTitle,
  required int creditCost,
  required int currentBalance,
}) async {
  final after = currentBalance - creditCost;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        contentPadding: const EdgeInsets.all(22),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ANTES DE USAR',
              style: MfText.legenda.copyWith(color: MfColors.inkMuted),
            ),
            const SizedBox(height: 10),
            Text(
              '$featureTitle custa $creditCost crédito${creditCost == 1 ? '' : 's'}. '
              'Seu saldo depois: ${after < 0 ? 0 : after} crédito${after == 1 ? '' : 's'}.',
              style: MfText.corpo,
            ),
            if (after < 0) ...[
              const SizedBox(height: 10),
              Text(
                'Saldo insuficiente. Adquira créditos avulsos ou assista a um anúncio na aba Créditos.',
                style: MfText.pequeno.copyWith(
                  color: MfColors.erro,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ContornoButton(
                    label: 'Cancelar',
                    compact: true,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PetroleoDarkButton(
                    label: 'Usar créditos',
                    compact: true,
                    onPressed:
                        after >= 0 ? () => Navigator.of(ctx).pop(true) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

class OfflineNoticeBanner extends StatelessWidget {
  final String message;

  const OfflineNoticeBanner({
    super.key,
    this.message =
        'Modo offline: todas as calculadoras básicas, metas e histórico local continuam funcionando normalmente.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MfColors.areiaSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MfColors.border),
      ),
      child: Row(
        children: [
          const MetaFeitaIcon(MfIcon.online, size: 18, color: MfColors.petroleo),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: MfText.pequeno),
          ),
        ],
      ),
    );
  }
}

/// Slot de banner não intrusivo (Doc 01 §5.1 e §9):
/// Nunca colocado sobre campos de entrada nem antes do resultado básico.
class SafeAdBannerSlot extends StatelessWidget {
  const SafeAdBannerSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return LightCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      backgroundColor: MfColors.areiaSubtle.withValues(alpha: 0.7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: MfColors.nevoaSoft.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'ANÚNCIO',
              style: MfText.legenda.copyWith(fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AdService.isUsingTestIds
                  ? 'Espaço publicitário (modo teste · sem dados financeiros)'
                  : 'Espaço publicitário contextual · sem rastreio financeiro',
              style: MfText.pequeno,
            ),
          ),
        ],
      ),
    );
  }
}

