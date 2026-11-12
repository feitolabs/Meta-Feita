import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_controller.dart';
import '../../domain/rules/backup_validator.dart';
import '../../infrastructure/exports/backup_service.dart';
import '../navigation/app_route.dart';
import '../theme/meta_feita_theme.dart';
import '../widgets/cards.dart';
import '../widgets/meta_feita_buttons.dart';
import '../widgets/meta_feita_icon.dart';

class ConfiguracoesScreen extends StatelessWidget {
  final AppController controller;
  final void Function(AppRoute route) onNavigate;
  final VoidCallback? onBack;

  const ConfiguracoesScreen({
    super.key,
    required this.controller,
    required this.onNavigate,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final prefs = controller.preferences;
    final cache = controller.creditCache;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: 'Voltar',
                onPressed: onBack,
                icon: const MetaFeitaIcon(MfIcon.voltar, size: 22),
              ),
            Expanded(child: Text('Configurações', style: MfText.titulo)),
          ],
        ),
        const SizedBox(height: 16),
        LightCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preferências locais', style: MfText.tituloCartao),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Salvar cálculos automaticamente',
                  style: MfText.rotulo,
                ),
                subtitle: Text(
                  'Guarda novas simulações de juros compostos no histórico deste aparelho ao calcular.',
                  style: MfText.pequeno,
                ),
                value: prefs.autoSaveSimulations,
                onChanged: (v) => controller.updatePreferences(
                  prefs.copyWith(autoSaveSimulations: v),
                ),
              ),
              const Divider(height: 20),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    Text('Moeda padrão', style: MfText.corpo),
                    Text('Real brasileiro (R\$)', style: MfText.rotulo),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    Text('Formato numérico', style: MfText.corpo),
                    Text('pt-BR (1.234,56)', style: MfText.rotulo),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LightCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Backup em arquivo JSON', style: MfText.tituloCartao),
              const SizedBox(height: 6),
              Text(
                'Exporte simulações, metas e preferências. Créditos e dados de pagamento não entram no backup.',
                style: MfText.pequeno,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ContornoButton(
                      label: 'Exportar',
                      compact: true,
                      leadingIcon: const MetaFeitaIcon(
                        MfIcon.exportar,
                        size: 17,
                      ),
                      onPressed: () => _exportBackup(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ContornoButton(
                      label: 'Restaurar',
                      compact: true,
                      leadingIcon: const MetaFeitaIcon(
                        MfIcon.restaurar,
                        size: 17,
                      ),
                      onPressed: () => _restoreBackup(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LightCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Carteira de créditos', style: MfText.tituloCartao),
              const SizedBox(height: 6),
              Text(
                cache.walletReference.isEmpty
                    ? 'Carteira anônima ainda não inicializada online.'
                    : 'Referência anônima: ${cache.walletReference}',
                style: MfText.pequeno,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ContornoButton(
                      label: 'Sincronizar saldo',
                      compact: true,
                      onPressed: () => controller.syncCreditsAndCatalog(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ContornoButton(
                      label: 'Abrir Créditos',
                      compact: true,
                      onPressed: () => onNavigate(AppRoute.creditos),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LightCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const MetaFeitaIcon(MfIcon.privacidade, size: 20),
                title: Text('Privacidade', style: MfText.rotulo),
                trailing: const MetaFeitaIcon(MfIcon.avancar, size: 18),
                onTap: () => onNavigate(AppRoute.privacidade),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: controller.ads.privacyOptionsRequired,
                builder: (context, required, _) {
                  if (!required) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const MetaFeitaIcon(MfIcon.anuncio, size: 20),
                        title: Text(
                          'Preferências de anúncios',
                          style: MfText.rotulo,
                        ),
                        trailing: const MetaFeitaIcon(MfIcon.avancar, size: 18),
                        onTap: controller.ads.showPrivacyOptions,
                      ),
                    ],
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const MetaFeitaIcon(MfIcon.info, size: 20),
                title: Text('Termos de uso e fórmulas', style: MfText.rotulo),
                trailing: const MetaFeitaIcon(MfIcon.avancar, size: 18),
                onTap: () => onNavigate(AppRoute.termos),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LightCard(
          padding: const EdgeInsets.all(18),
          borderColor: MfColors.erro.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apagar dados deste aparelho',
                style: MfText.tituloCartao.copyWith(color: MfColors.erro),
              ),
              const SizedBox(height: 6),
              Text(
                'Remove todas as simulações, metas e preferências salvas localmente. Seu saldo de créditos confirmado no servidor não é excluído.',
                style: MfText.pequeno,
              ),
              const SizedBox(height: 12),
              ContornoButton(
                label: 'Apagar histórico e metas locais',
                compact: true,
                onPressed: () => _confirmClearAll(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    final json = BackupService.buildBackupJson(
      simulations: controller.simulations,
      goals: controller.goals,
      preferences: controller.preferences,
    );
    try {
      await BackupService.exportAndShare(
        simulations: controller.simulations,
        goals: controller.goals,
        preferences: controller.preferences,
      );
    } catch (_) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text('Backup JSON', style: MfText.tituloCartao),
          content: SizedBox(
            width: 480,
            height: 260,
            child: SingleChildScrollView(
              child: SelectableText(json, style: MfText.pequeno),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: json));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('JSON copiado.')));
              },
              child: const Text('Copiar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    try {
      final payload = await BackupService.pickAndValidateBackupFile();
      if (payload == null || !context.mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text('Restaurar backup', style: MfText.tituloCartao),
          content: Text(
            'Encontradas ${payload.simulations.length} simulação(ões) e ${payload.goals.length} meta(s). '
            'Deseja mesclar ou substituir os dados locais?',
            style: MfText.corpo,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('merge'),
              child: const Text('Mesclar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('replace'),
              child: const Text('Substituir tudo'),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return;
      controller.applyBackup(payload, replaceAll: choice == 'replace');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup restaurado.')));
    } on BackupValidationException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o arquivo: $e')),
      );
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('Apagar dados locais?', style: MfText.tituloCartao),
        content: Text(
          'Tem certeza? Todas as simulações e metas salvas neste aparelho serão apagadas permanentemente, a menos que você tenha um arquivo de backup.',
          style: MfText.corpo,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      controller.clearAllLocalFinancialData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados financeiros locais apagados.')),
      );
    }
  }
}
