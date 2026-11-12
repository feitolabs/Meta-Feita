import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../application/app_controller.dart';
import '../../domain/engines/goals_engine.dart';
import '../../domain/models/goal_models.dart';
import '../../domain/models/simulation_models.dart';
import '../../domain/rules/formatters.dart';
import '../navigation/app_route.dart';
import '../theme/meta_feita_theme.dart';
import '../widgets/cards.dart';
import '../widgets/meta_feita_buttons.dart';
import '../widgets/meta_feita_icon.dart';

class PainelScreen extends StatelessWidget {
  final AppController controller;
  final void Function(AppRoute route, {SavedSimulation? openSimulation})
  onNavigate;
  final bool isDesktop;

  const PainelScreen({
    super.key,
    required this.controller,
    required this.onNavigate,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final focusGoal = controller.focusGoal;
    final recent = controller.simulations.take(3).toList();

    if (isDesktop) {
      return _buildDesktopPainel(context, focusGoal, recent);
    }
    return _buildMobilePainel(context, focusGoal, recent);
  }

  Widget _buildMobilePainel(
    BuildContext context,
    SavedGoal? focusGoal,
    List<SavedSimulation> recent,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        // Header Mobile: [Logo] Meta Feita  |  [Ajustes] [X créditos]
        Row(
          children: [
            const MetaFeitaLogo(size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Meta Feita',
                style: MfText.tituloCartao.copyWith(fontSize: 21),
              ),
            ),
            IconButton(
              tooltip: 'Configurações e backup',
              onPressed: () => onNavigate(AppRoute.configuracoes),
              icon: const MetaFeitaIcon(MfIcon.ajustes, size: 22),
            ),
            const SizedBox(width: 4),
            // Limite em vez de flex: o título mantém todo o espaço que sobrar.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.42,
              ),
              child: _CreditBalanceChip(
                balance: controller.creditBalance,
                confirmed: controller.isBalanceConfirmed,
                onTap: () => onNavigate(AppRoute.creditos),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'PAINEL',
          style: MfText.legenda.copyWith(color: MfColors.inkMuted),
        ),
        const SizedBox(height: 6),
        Text('Planeje com números que você entende.', style: MfText.titulo),
        const SizedBox(height: 10),
        Text(
          'Simulações feitas com os valores que você informa, guardadas só neste aparelho.',
          style: MfText.corpo.copyWith(color: MfColors.inkMuted),
        ),
        const SizedBox(height: 18),
        BrasaPrimaryButton(
          label: '+ Nova simulação',
          onPressed: () => _openNewSimulationChooser(context),
        ),
        const SizedBox(height: 20),
        _FocusGoalCard(
          goal: focusGoal,
          isDesktop: false,
          onTap: () => onNavigate(AppRoute.metas),
        ),
        const SizedBox(height: 24),
        Text('Calculadoras', style: MfText.subtitulo),
        const SizedBox(height: 12),
        _buildToolsGrid(crossAxisCount: 2),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Últimas simulações', style: MfText.subtitulo),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => onNavigate(AppRoute.historico),
                child: Text(
                  'Ver histórico',
                  style: MfText.rotulo.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final sim in recent) ...[
            _RecentSimulationTile(
              sim: sim,
              onTap: () =>
                  onNavigate(_routeForType(sim.type), openSimulation: sim),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 16),
        const ProjectionDisclaimer(),
      ],
    );
  }

  Widget _buildDesktopPainel(
    BuildContext context,
    SavedGoal? focusGoal,
    List<SavedSimulation> recent,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAINEL',
                    style: MfText.legenda.copyWith(color: MfColors.inkMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Planeje com números que você entende.',
                    style: MfText.titulo.copyWith(fontSize: 36),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Simulações com os valores que você informa. Tudo fica guardado só neste aparelho.',
                    style: MfText.corpo.copyWith(color: MfColors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            BrasaPrimaryButton(
              label: '+ Nova simulação',
              fullWidth: false,
              compactPill: true,
              onPressed: () => _openNewSimulationChooser(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildToolsGrid(crossAxisCount: 4),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _FocusGoalCard(
                goal: focusGoal,
                isDesktop: true,
                onTap: () => onNavigate(AppRoute.metas),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 6,
              child: LightCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Últimas simulações',
                            style: MfText.tituloCartao,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => onNavigate(AppRoute.historico),
                          child: Text(
                            'Ver histórico',
                            style: MfText.rotulo.copyWith(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (recent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'Você ainda não salvou simulações. Use uma calculadora ao lado ou acima para começar.',
                          style: MfText.pequeno.copyWith(fontSize: 14),
                        ),
                      )
                    else
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3.2),
                          1: FlexColumnWidth(2.0),
                          2: FlexColumnWidth(1.8),
                          3: FlexColumnWidth(2.4),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: MfColors.border),
                              ),
                            ),
                            children: [
                              _th('Nome'),
                              _th('Tipo'),
                              _th('Data'),
                              _th('Resultado', alignRight: true),
                            ],
                          ),
                          for (final sim in recent)
                            TableRow(
                              children: [
                                _tdInk(
                                  sim.title,
                                  bold: true,
                                  onTap: () => onNavigate(
                                    _routeForType(sim.type),
                                    openSimulation: sim,
                                  ),
                                ),
                                _td(sim.type.labelPt),
                                _td(_formatDate(sim.updatedAt)),
                                _td(
                                  sim.summaryLabel,
                                  alignRight: true,
                                  bold: true,
                                ),
                              ],
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Divider(color: MfColors.border),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(child: ProjectionDisclaimer()),
            TextButton(
              onPressed: () => onNavigate(AppRoute.privacidade),
              child: Text(
                'Privacidade',
                style: MfText.pequeno.copyWith(
                  decoration: TextDecoration.underline,
                  color: MfColors.petroleo,
                ),
              ),
            ),
            TextButton(
              onPressed: () => onNavigate(AppRoute.termos),
              child: Text(
                'Termos de uso',
                style: MfText.pequeno.copyWith(
                  decoration: TextDecoration.underline,
                  color: MfColors.petroleo,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _th(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: MfText.pequeno.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _td(String text, {bool alignRight = false, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: MfText.pequeno.copyWith(
          color: MfColors.petroleo,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _tdInk(String text, {bool bold = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: _td(text, bold: bold),
    );
  }

  Widget _buildToolsGrid({required int crossAxisCount}) {
    final items = [
      (
        route: AppRoute.jurosCompostos,
        icon: MfIcon.jurosCompostos,
        title: 'Juros compostos',
        desc: 'Capital, aportes, taxa e prazo.',
      ),
      (
        route: AppRoute.dividendos,
        icon: MfIcon.dividendos,
        title: 'Dividendos',
        desc: 'Proventos, renda e DY hipotético.',
      ),
      (
        route: AppRoute.metas,
        icon: MfIcon.metas,
        title: 'Metas',
        desc: 'Quanto aportar e em quanto tempo.',
      ),
      (
        route: AppRoute.comparador,
        icon: MfIcon.comparador,
        title: 'Comparador',
        desc: 'Até 4 cenários lado a lado.',
      ),
      (
        route: AppRoute.reinvestimento,
        icon: MfIcon.reinvestimento,
        title: 'Reinvestimento',
        desc: 'Reinvestir proventos e caixa residual.',
      ),
      (
        route: AppRoute.inflacao,
        icon: MfIcon.inflacao,
        title: 'Inflação',
        desc: 'Poder de compra e taxa real.',
      ),
      (
        route: AppRoute.retirada,
        icon: MfIcon.retirada,
        title: 'Retiradas',
        desc: 'Saques e duração do patrimônio.',
      ),
      (
        route: AppRoute.aposentadoria,
        icon: MfIcon.aposentadoria,
        title: 'Aposentadoria',
        desc: 'Acumulação e renda sustentável.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (crossAxisCount - 1))) /
            crossAxisCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: LightCard(
                padding: const EdgeInsets.all(16),
                onTap: () => onNavigate(item.route),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: MfColors.nevoaSoft.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: MetaFeitaIcon(
                        item.icon,
                        size: 21,
                        color: MfColors.petroleo,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.title,
                      style: MfText.tituloCartao.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MfText.pequeno.copyWith(fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _openNewSimulationChooser(BuildContext context) {
    final options = [
      (
        AppRoute.jurosCompostos,
        MfIcon.jurosCompostos,
        'Juros compostos',
        'Capital, aportes, taxa e evolução mês a mês',
      ),
      (
        AppRoute.dividendos,
        MfIcon.dividendos,
        'Dividendos',
        'Proventos por cota, calendário e meta de renda',
      ),
      (
        AppRoute.reinvestimento,
        MfIcon.reinvestimento,
        'Reinvestimento',
        'Cotas compradas e caixa residual',
      ),
      (
        AppRoute.metas,
        MfIcon.metas,
        'Metas financeiras',
        'Aporte necessário e prazo estimado',
      ),
      (
        AppRoute.comparador,
        MfIcon.comparador,
        'Comparador de cenários',
        'Compare de 2 a 4 cenários lado a lado',
      ),
      (
        AppRoute.inflacao,
        MfIcon.inflacao,
        'Inflação e retorno real',
        'Taxa real de Fisher e poder de compra',
      ),
      (
        AppRoute.retirada,
        MfIcon.retirada,
        'Simulador de retiradas',
        'Saques periódicos e risco de esgotamento',
      ),
      (
        AppRoute.aposentadoria,
        MfIcon.aposentadoria,
        'Aposentadoria',
        'Acumulação e renda real estimada',
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MfColors.areiaCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Escolha uma simulação',
                          style: MfText.subtitulo,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const MetaFeitaIcon(MfIcon.fechar),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final opt = options[index];
                      return LightCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onNavigate(opt.$1);
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: MfColors.nevoaSoft.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: MetaFeitaIcon(opt.$2, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.$3,
                                    style: MfText.rotulo.copyWith(fontSize: 16),
                                  ),
                                  Text(opt.$4, style: MfText.pequeno),
                                ],
                              ),
                            ),
                            const MetaFeitaIcon(MfIcon.avancar, size: 18),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  AppRoute _routeForType(SimulationType type) => switch (type) {
    SimulationType.compoundInterest => AppRoute.jurosCompostos,
    SimulationType.dividends => AppRoute.dividendos,
    SimulationType.reinvestment => AppRoute.reinvestimento,
    SimulationType.goal => AppRoute.metas,
    SimulationType.comparator => AppRoute.comparador,
    SimulationType.inflation => AppRoute.inflacao,
    SimulationType.withdrawal => AppRoute.retirada,
    SimulationType.retirement => AppRoute.aposentadoria,
  };

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }
}

class _CreditBalanceChip extends StatelessWidget {
  final int balance;
  final bool confirmed;
  final VoidCallback onTap;

  const _CreditBalanceChip({
    required this.balance,
    required this.confirmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MfColors.areiaCard,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: MfColors.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MetaFeitaIcon(MfIcon.creditos, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$balance crédito${balance == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MfText.rotulo.copyWith(fontSize: 13.5),
                ),
              ),
              if (!confirmed) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: MfColors.petroleo, width: 1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusGoalCard extends StatelessWidget {
  final SavedGoal? goal;
  final bool isDesktop;
  final VoidCallback onTap;

  const _FocusGoalCard({
    required this.goal,
    required this.isDesktop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (goal == null) {
      return GestureDetector(
        onTap: onTap,
        child: DarkHighlightCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'META EM FOCO',
                style: MfText.legenda.copyWith(color: MfColors.azulRioClaro),
              ),
              const SizedBox(height: 10),
              Text(
                'Nenhuma meta criada ainda',
                style: MfText.subtitulo.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Crie uma meta financeira para acompanhar quanto falta e qual aporte mensal leva até lá.',
                style: MfText.pequeno.copyWith(
                  color: MfColors.nevoaClaro,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ContornoButton(
                label: 'Criar primeira meta',
                compact: true,
                fullWidth: false,
                lightOnDark: true,
                onPressed: onTap,
              ),
            ],
          ),
        ),
      );
    }

    final eval = GoalsEngine.evaluate(goal!.input);
    final pct = (eval.currentPercentage / Decimal.fromInt(100)).toDouble();

    return GestureDetector(
      onTap: onTap,
      child: DarkHighlightCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'META EM FOCO',
                    style: MfText.legenda.copyWith(
                      color: MfColors.azulRioClaro,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'até ${goal!.targetDate.formatMonthYearPtBr()}',
                    textAlign: TextAlign.right,
                    style: MfText.pequeno.copyWith(
                      color: MfColors.nevoaClaro,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              goal!.title,
              style: MfText.subtitulo.copyWith(
                color: Colors.white,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    PtBrFormatters.money(goal!.input.currentCapital),
                    style: MfText.numero.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'de ${PtBrFormatters.money(goal!.input.targetValue)}',
                    style: MfText.corpo.copyWith(
                      color: MfColors.nevoaClaro,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            MfProgressBar(progress: pct, darkSurface: true, height: 10),
            const SizedBox(height: 12),
            Text(
              isDesktop && eval.requiredMonthlyContribution != null
                  ? 'Aporte necessário para o prazo: ${PtBrFormatters.money(eval.requiredMonthlyContribution!)} por mês'
                  : '${PtBrFormatters.percent(eval.currentPercentage, decimals: 0)} da meta · aporte de ${PtBrFormatters.money(goal!.input.periodicContribution)} por mês',
              style: MfText.pequeno.copyWith(
                color: MfColors.nevoaClaro,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSimulationTile extends StatelessWidget {
  final SavedSimulation sim;
  final VoidCallback onTap;

  const _RecentSimulationTile({required this.sim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = sim.updatedAt.day.toString().padLeft(2, '0');
    final m = sim.updatedAt.month.toString().padLeft(2, '0');
    return LightCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sim.type.eyebrowPt,
                  style: MfText.legenda.copyWith(
                    color: MfColors.inkMuted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(sim.title, style: MfText.rotulo.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  '${sim.summaryLabel} · $d/$m/${sim.updatedAt.year}',
                  style: MfText.pequeno,
                ),
              ],
            ),
          ),
          const MetaFeitaIcon(MfIcon.avancar, size: 18),
        ],
      ),
    );
  }
}
