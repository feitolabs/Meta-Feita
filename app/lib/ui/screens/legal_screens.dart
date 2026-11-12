import 'package:flutter/material.dart';

import '../theme/meta_feita_theme.dart';
import '../widgets/cards.dart';
import '../widgets/meta_feita_icon.dart';

class PrivacidadeScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const PrivacidadeScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
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
            Expanded(child: Text('Privacidade', style: MfText.titulo)),
          ],
        ),
        const SizedBox(height: 16),
        LightCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Armazenamento local-first', style: MfText.tituloCartao),
              const SizedBox(height: 8),
              Text(
                'Suas simulações, metas financeiras, parâmetros monetários e histórico ficam gravados exclusivamente neste aparelho usando armazenamento local (localstorage). '
                'Não exigimos cadastro ou login e não enviamos seus valores financeiros para servidores externos.',
                style: MfText.corpo,
              ),
              const SizedBox(height: 18),
              Text(
                'O que vai para o servidor de créditos',
                style: MfText.tituloCartao,
              ),
              const SizedBox(height: 8),
              Text(
                'Quando você está conectado e utiliza o sistema de créditos, o servidor armazena apenas:\n'
                '• Uma referência anônima de carteira e o hash do código de recuperação;\n'
                '• O extrato transacional de pacotes comprados, reservas/estornos de recursos avançados e anúncios premiados validados;\n'
                '• Eventos operacionais técnicos sem nenhum campo financeiro.',
                style: MfText.corpo,
              ),
              const SizedBox(height: 18),
              Text(
                'Publicidade sem perfilamento financeiro',
                style: MfText.tituloCartao,
              ),
              const SizedBox(height: 8),
              Text(
                'No Android, o app exibe anúncios do Google AdMob. Eles não recebem capital inicial, aportes, metas, taxas ou resultados das suas simulações. '
                'O Google pode tratar o identificador de publicidade do aparelho e dados técnicos para exibir e medir anúncios, conforme as escolhas feitas no aviso de consentimento. '
                'Quando exigido na sua região, você pode rever essas escolhas em Configurações.',
                style: MfText.corpo,
              ),
              const SizedBox(height: 18),
              Text('Compras', style: MfText.tituloCartao),
              const SizedBox(height: 8),
              Text(
                'No Android, os pagamentos são processados pela Google Play. O Meta Feita recebe apenas o comprovante da compra para liberar os créditos e não tem acesso aos dados do seu cartão.',
                style: MfText.corpo,
              ),
              const SizedBox(height: 18),
              Text('Exclusão e portabilidade', style: MfText.tituloCartao),
              const SizedBox(height: 8),
              Text(
                'Você pode exportar um arquivo JSON com seu histórico a qualquer momento ou apagar todos os dados financeiros locais em Configurações.',
                style: MfText.corpo,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TermosScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const TermosScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
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
            Expanded(child: Text('Termos de uso', style: MfText.titulo)),
          ],
        ),
        const SizedBox(height: 16),
        LightCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finalidade educacional e simulatória',
                style: MfText.tituloCartao,
              ),
              const SizedBox(height: 8),
              Text(
                'O Meta Feita é uma ferramenta de cálculo e planejamento financeiro baseada estritamente nos números e premissas informados por você. '
                'Os resultados são estimativas matemáticas hipotéticas e não constituem recomendação de investimento, consultoria financeira regulada ou garantia de rentabilidade.',
                style: MfText.corpo,
              ),
              const SizedBox(height: 18),
              Text('Transparência matemática', style: MfText.tituloCartao),
              const SizedBox(height: 8),
              Text(
                '• Taxas anuais efetivas usam conversão composta equivalente ((1 + i_a)^(1/12) - 1);\n'
                '• Taxas nominais anuais capitalizadas mensalmente usam j / 12;\n'
                '• Conversão entre rendimento nominal e real aplica a equação de Fisher: (1 + r_real) = (1 + r_nominal) / (1 + inflação);\n'
                '• Cálculos monetários são executados com precisão decimal exata e arredondamento explícito para 2 casas na moeda Real (BRL).',
                style: MfText.corpo,
              ),
              const SizedBox(height: 18),
              Text('Modelo de créditos avulsos', style: MfText.tituloCartao),
              const SizedBox(height: 8),
              Text(
                'Todas as calculadoras essenciais funcionam gratuitamente e offline. '
                'Recursos avançados consomem créditos obtidos por compra única (sem assinatura ou cobrança recorrente) ou por anúncio premiado. '
                'No Android, as compras são feitas pela Google Play e seguem as regras de reembolso da loja. '
                'Sempre exibimos o custo antes da confirmação e estornamos reservas caso uma ação falhe antes de concluir.',
                style: MfText.corpo,
              ),
              const SizedBox(height: 18),
              Text('Backup e responsabilidade', style: MfText.tituloCartao),
              const SizedBox(height: 8),
              Text(
                'Como os dados financeiros residem localmente no aparelho, recomendamos exportar backups JSON periódicos. '
                'Arquivos de backup não restauram créditos por segurança de saldo.',
                style: MfText.corpo,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
