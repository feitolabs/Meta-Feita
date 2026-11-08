import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_controller.dart';
import '../../domain/models/credit_models.dart';
import '../../infrastructure/ads/ad_service.dart';
import '../theme/meta_feita_theme.dart';
import '../widgets/cards.dart';
import '../widgets/credit_cost_dialog.dart';
import '../widgets/meta_feita_buttons.dart';
import '../widgets/meta_feita_icon.dart';

class CreditosScreen extends StatefulWidget {
  final AppController controller;
  final VoidCallback? onBack;

  const CreditosScreen({
    super.key,
    required this.controller,
    this.onBack,
  });

  @override
  State<CreditosScreen> createState() => _CreditosScreenState();
}

class _CreditosScreenState extends State<CreditosScreen> {
  String? _selectedPackageId;
  bool _busyAction = false;

  CreditPackage _resolveSelectedPackage(CreditCatalog catalog) {
    if (_selectedPackageId != null) {
      for (final p in catalog.packages) {
        if (p.productId == _selectedPackageId) return p;
      }
    }
    for (final p in catalog.packages) {
      if (p.highlighted) return p;
    }
    return catalog.packages.first;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final catalog = c.catalog;
    final selectedPkg = _resolveSelectedPackage(catalog);
    final cache = c.creditCache;
    final confirmedTime = cache.lastValidatedAt;
    final timeStr = confirmedTime != null
        ? '${confirmedTime.hour.toString().padLeft(2, '0')}:${confirmedTime.minute.toString().padLeft(2, '0')}'
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            if (widget.onBack != null)
              IconButton(
                tooltip: 'Voltar',
                onPressed: widget.onBack,
                icon: const MetaFeitaIcon(MfIcon.voltar, size: 22),
              ),
            Expanded(child: Text('Créditos', style: MfText.titulo)),
            TextButton.icon(
              onPressed: c.isSyncingCredits ? null : () => c.syncCreditsAndCatalog(),
              icon: const MetaFeitaIcon(MfIcon.online, size: 18),
              label: Text(c.isSyncingCredits ? 'Sincronizando...' : 'Atualizar'),
            ),
          ],
        ),
        if (!c.isOnline) ...[
          const SizedBox(height: 10),
          OfflineNoticeBanner(
            message: c.lastCreditError ??
                'Sem conexão com o servidor de créditos. Mostrando cache local offline.',
          ),
        ],
        const SizedBox(height: 12),
        DarkHighlightCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SEU SALDO',
                    style: MfText.legenda.copyWith(color: MfColors.azulRioClaro),
                  ),
                  if (cache.walletReference.isNotEmpty)
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: cache.walletReference),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ID da carteira copiado.'),
                          ),
                        );
                      },
                      child: Text(
                        'ID: ${cache.walletReference.substring(0, cache.walletReference.length.clamp(0, 10))}…',
                        style: MfText.pequeno.copyWith(
                          color: MfColors.nevoaClaro,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${c.creditBalance}',
                    style: MfText.numero.copyWith(color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    c.creditBalance == 1 ? 'crédito' : 'créditos',
                    style: MfText.subtitulo.copyWith(
                      color: MfColors.nevoaClaro,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                c.isBalanceConfirmed
                    ? 'Confirmado pelo servidor${timeStr != null ? ' às $timeStr' : ''}'
                    : (timeStr != null
                        ? 'Cache local (offline) · última confirmação às $timeStr'
                        : 'Aguardando confirmação online para usar recursos pagos'),
                style: MfText.pequeno.copyWith(
                  color: MfColors.nevoaClaro,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _openRecoveryDialog(context),
                child: Text(
                  'Recuperar saldo com código em outro aparelho',
                  style: MfText.pequeno.copyWith(
                    color: MfColors.azulRioClaro,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text('Comprar pacote', style: MfText.subtitulo),
        const SizedBox(height: 10),
        for (final pkg in catalog.packages) ...[
          _PackageOptionCard(
            package: pkg,
            selected: pkg.productId == selectedPkg.productId,
            onTap: () => setState(() => _selectedPackageId = pkg.productId),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        BrasaPrimaryButton(
          label: 'Comprar ${selectedPkg.credits} créditos',
          isLoading: _busyAction,
          onPressed: _busyAction ? null : () => _startPurchase(selectedPkg),
        ),
        if (catalog.rewardedAd.enabled) ...[
          const SizedBox(height: 10),
          ContornoButton(
            label:
                'Assistir anúncio e ganhar ${catalog.rewardedAd.creditsPerView} crédito${catalog.rewardedAd.creditsPerView == 1 ? '' : 's'}',
            leadingIcon: const MetaFeitaIcon(MfIcon.anuncio, size: 18),
            onPressed: _busyAction ? null : _watchRewardedAd,
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'Compra única, sem assinatura. Créditos não são restaurados pelo arquivo de backup.',
          style: MfText.pequeno,
        ),
        const SizedBox(height: 22),
        Text('Recursos opcionais com créditos', style: MfText.subtitulo),
        const SizedBox(height: 10),
        for (final feature in catalog.features) ...[
          LightCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title,
                        style: MfText.rotulo.copyWith(fontSize: 15.5),
                      ),
                      const SizedBox(height: 2),
                      Text(feature.description, style: MfText.pequeno),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: MfColors.areiaSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${feature.creditCost} crédito${feature.creditCost == 1 ? '' : 's'}',
                    style: MfText.rotulo.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        LightCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ANTES DE USAR',
                style: MfText.legenda.copyWith(color: MfColors.inkMuted),
              ),
              const SizedBox(height: 6),
              Text(
                'Nenhum crédito é descontado sem sua confirmação prévia. Antes de abrir um recurso pago, você sempre vê o custo exato e o saldo restante.',
                style: MfText.corpo.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  showCreditCostConfirmationDialog(
                    context,
                    featureTitle: 'Relatório detalhado (exemplo)',
                    creditCost: catalog.findFeature('detailed_report')?.creditCost ?? 2,
                    currentBalance: c.creditBalance,
                  );
                },
                child: const Text('Visualizar confirmação de uso'),
              ),
            ],
          ),
        ),
        if (c.transactions.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('Extrato recente', style: MfText.subtitulo),
          const SizedBox(height: 10),
          LightCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < c.transactions.length; i++) ...[
                  _LedgerRow(entry: c.transactions[i]),
                  if (i < c.transactions.length - 1) const Divider(height: 18),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _startPurchase(CreditPackage pkg) async {
    if (!widget.controller.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conecte-se à internet para iniciar e validar a compra de créditos.',
          ),
        ),
      );
      return;
    }

    setState(() => _busyAction = true);
    try {
      final session = await widget.controller.initiateWebCheckout(pkg.productId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Checkout iniciado', style: MfText.tituloCartao),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pacote: ${pkg.title} (${pkg.displayPrice}).\n\n'
                'Os créditos são liberados somente após a confirmação pelo servidor de pagamento (webhook/validação segura).',
                style: MfText.corpo,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MfColors.areiaSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  kIsWeb
                      ? 'Checkout ID: ${session.checkoutId}\nURL: ${session.checkoutUrl}'
                      : 'Produto Google Play: ${pkg.playProductId}\nSessão web alternativa: ${session.checkoutUrl}',
                  style: MfText.pequeno,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: session.checkoutUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link do checkout copiado.')),
                );
              },
              child: const Text('Copiar link'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.controller.syncCreditsAndCatalog();
              },
              child: const Text('Atualizar saldo'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _watchRewardedAd() async {
    if (!widget.controller.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conecte-se à internet para validar a recompensa do anúncio.',
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anúncio premiado', style: MfText.tituloCartao),
        content: Text(
          'Deseja exibir o anúncio premiado para ganhar ${widget.controller.catalog.rewardedAd.creditsPerView} crédito(s)?\n\n'
          'Limite diário: ${widget.controller.catalog.rewardedAd.dailyLimit} por dia. '
          'Unidade configurada: ${AdService.currentRewardedUnitId()}'
          '${AdService.isUsingTestIds ? ' (modo teste)' : ''}. '
          'Nenhum valor financeiro seu é enviado ao provedor de anúncios.',
          style: MfText.corpo,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Assistir e validar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busyAction = true);
    try {
      final newBal = await widget.controller.claimRewardedAd();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recompensa confirmada pelo servidor. Saldo: $newBal créditos.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _openRecoveryDialog(BuildContext context) async {
    final refCtrl = TextEditingController(
      text: widget.controller.creditCache.walletReference,
    );
    final codeCtrl = TextEditingController();
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Recuperar carteira', style: MfText.tituloCartao),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Referência da carteira',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código de recuperação',
                  border: OutlineInputBorder(),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMsg!,
                  style: MfText.pequeno.copyWith(color: MfColors.erro),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await widget.controller.recoverWallet(
                    refCtrl.text,
                    codeCtrl.text,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Carteira recuperada e saldo sincronizado.'),
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() => errorMsg = e.toString());
                }
              },
              child: const Text('Recuperar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageOptionCard extends StatelessWidget {
  final CreditPackage package;
  final bool selected;
  final VoidCallback onTap;

  const _PackageOptionCard({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LightCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      backgroundColor:
          selected ? MfColors.areiaCard : MfColors.areiaCard.withValues(alpha: 0.72),
      borderColor: selected ? MfColors.petroleo : MfColors.border,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? MfColors.petroleo : MfColors.borderStrong,
                width: selected ? 6 : 1.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (package.highlighted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MfColors.petroleo,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'MAIS USADO',
                        style: MfText.legenda.copyWith(
                          fontSize: 10.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Text(
                  package.title,
                  style: MfText.tituloCartao.copyWith(fontSize: 17.5),
                ),
                Text(package.subtitle, style: MfText.pequeno),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            package.displayPrice,
            style: MfText.tituloCartao.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final LedgerEntry entry;

  const _LedgerRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dt = entry.createdAt.toLocal();
    final date =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final positive = entry.creditDelta >= 0;
    final label = switch (entry.source) {
      'web_purchase' => 'Compra web de créditos',
      'play_purchase' => 'Compra Google Play',
      'rewarded_ad' || 'rewarded_ad_credit' => 'Anúncio premiado',
      'consumption' => 'Uso de recurso avançado',
      'refund' => 'Estorno de créditos',
      _ => entry.source,
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: MfText.rotulo),
              Text('$date · ${entry.status}', style: MfText.pequeno),
            ],
          ),
        ),
        Text(
          '${positive ? '+' : ''}${entry.creditDelta}',
          style: MfText.tituloCartao.copyWith(
            color: MfColors.petroleo,
          ),
        ),
      ],
    );
  }
}
