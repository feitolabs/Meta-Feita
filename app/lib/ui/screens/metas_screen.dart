import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../application/app_controller.dart';
import '../../domain/engines/goals_engine.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/goal_models.dart';
import '../../domain/models/rate_input.dart';
import '../../domain/rules/formatters.dart';
import '../theme/meta_feita_theme.dart';
import '../widgets/cards.dart';
import '../widgets/inputs.dart';
import '../widgets/meta_feita_buttons.dart';
import '../widgets/meta_feita_icon.dart';

class MetasScreen extends StatelessWidget {
  final AppController controller;

  const MetasScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final goals = controller.goals;
    final focus = controller.focusGoal;
    final others = goals.where((g) => g.id != focus?.id).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            Expanded(child: Text('Metas', style: MfText.titulo)),
            BrasaPrimaryButton(
              label: '+ Nova meta',
              fullWidth: false,
              compactPill: true,
              onPressed: () => _openGoalEditor(context),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (focus == null)
          EmptyStateCard(
            icon: MfIcon.metas,
            title: 'Crie sua primeira meta financeira',
            description:
                'Informe valor-alvo, capital atual, aporte mensal, taxa e prazo para calcular quanto falta e o aporte ideal.',
            action: PetroleoDarkButton(
              label: 'Preencher meta de exemplo',
              fullWidth: false,
              compact: true,
              onPressed: () => _openGoalEditor(context, useExampleDefaults: true),
            ),
          )
        else ...[
          _buildFocusDetails(context, focus),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Outras metas', style: MfText.subtitulo),
            const SizedBox(height: 12),
            for (final g in others) ...[
              _buildOtherGoalCard(context, g),
              const SizedBox(height: 10),
            ],
          ],
        ],
        const SizedBox(height: 16),
        const ProjectionDisclaimer(),
      ],
    );
  }

  Widget _buildFocusDetails(BuildContext context, SavedGoal focus) {
    final eval = GoalsEngine.evaluate(focus.input);
    final currentRatio =
        (eval.currentPercentage / Decimal.fromInt(100)).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DarkHighlightCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'META EM FOCO',
                      style: MfText.legenda.copyWith(color: MfColors.azulRioClaro),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'prazo: ${focus.input.termMonths} meses',
                      textAlign: TextAlign.right,
                      style: MfText.pequeno.copyWith(color: MfColors.nevoaClaro),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      focus.title,
                      style: MfText.subtitulo.copyWith(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar meta',
                    onPressed: () => _openGoalEditor(context, existing: focus),
                    icon: const MetaFeitaIcon(
                      MfIcon.editar,
                      size: 19,
                      color: MfColors.nevoaClaro,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      PtBrFormatters.money(focus.input.targetValue),
                      style: MfText.numero.copyWith(
                        color: Colors.white,
                        fontSize: 34,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'valor-alvo',
                      style: MfText.pequeno.copyWith(
                        color: MfColors.nevoaClaro,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              MfProgressBar(
                progress: currentRatio,
                darkSurface: true,
                height: 10,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Hoje: ${PtBrFormatters.money(focus.input.currentCapital)} '
                      '(${PtBrFormatters.percent(eval.currentPercentage, decimals: 0)})',
                      style: MfText.pequeno.copyWith(color: MfColors.nevoaClaro),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'No prazo: ${PtBrFormatters.percent(eval.projectedPercentage, decimals: 1)}',
                      textAlign: TextAlign.right,
                      style: MfText.pequeno.copyWith(
                        color: MfColors.nevoaClaro,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: tileWidth,
                  child: LightCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Projeção no prazo', style: MfText.pequeno),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            PtBrFormatters.money(eval.projectedValueAtTerm),
                            style: MfText.tituloCartao,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: LightCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eval.differenceToTarget > Decimal.zero
                              ? 'Falta para a meta'
                              : 'Excedente previsto',
                          style: MfText.pequeno,
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            PtBrFormatters.money(eval.differenceToTarget.abs()),
                            style: MfText.tituloCartao,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: LightCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Aporte necessário', style: MfText.pequeno),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            eval.requiredMonthlyContribution != null
                                ? PtBrFormatters.money(
                                    eval.requiredMonthlyContribution!)
                                : 'Indisponível',
                            style: MfText.tituloCartao,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'por mês, em ${focus.input.termMonths} meses',
                          style: MfText.pequeno,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: LightCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prazo com o aporte atual', style: MfText.pequeno),
                        const SizedBox(height: 6),
                        Text(
                          eval.estimatedMonthsWithCurrentContribution != null
                              ? '${eval.estimatedMonthsWithCurrentContribution} meses'
                              : 'Acima de 1.200m',
                          style: MfText.tituloCartao,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _deltaLabel(eval.monthsDeltaVsTerm),
                          style: MfText.pequeno,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (eval.solverNote != null) ...[
          const SizedBox(height: 12),
          LightCard(
            padding: const EdgeInsets.all(14),
            child: Text(eval.solverNote!, style: MfText.pequeno),
          ),
        ],
        const SizedBox(height: 14),
        AssumptionDisclosure(
          title: 'Premissas desta meta',
          initiallyExpanded: false,
          assumptions: {
            'Capital atual': PtBrFormatters.money(focus.input.currentCapital),
            'Aporte':
                '${PtBrFormatters.money(focus.input.periodicContribution)} por mês, ${focus.input.contributionTiming.shortPt}',
            'Taxa': focus.input.rate.describePt(),
            'Solução': 'Busca numérica, tolerância R\$ 0,01',
          },
        ),
      ],
    );
  }

  String _deltaLabel(int? delta) {
    if (delta == null) return 'Sem convergência no limite';
    if (delta == 0) return 'Exatamente no prazo';
    if (delta > 0) return '$delta mês${delta == 1 ? '' : 'es'} além do prazo';
    final ahead = delta.abs();
    return '$ahead mês${ahead == 1 ? '' : 'es'} antes do prazo';
  }

  Widget _buildOtherGoalCard(BuildContext context, SavedGoal goal) {
    final pct = goal.input.targetValue > Decimal.zero
        ? ((goal.input.currentCapital / goal.input.targetValue)
                .toDecimal(scaleOnInfinitePrecision: 4) *
            Decimal.fromInt(100))
        : Decimal.zero;

    return LightCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(goal.title, style: MfText.tituloCartao),
              ),
              Text(
                PtBrFormatters.percent(pct, decimals: 0),
                style: MfText.rotulo,
              ),
            ],
          ),
          const SizedBox(height: 10),
          MfProgressBar(
            progress: (pct / Decimal.fromInt(100)).toDouble(),
            height: 8,
          ),
          const SizedBox(height: 10),
          Text(
            '${PtBrFormatters.money(goal.input.currentCapital)} de '
            '${PtBrFormatters.money(goal.input.targetValue)} · até ${goal.targetDate.formatMonthYearPtBr()}',
            style: MfText.pequeno,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () => controller.setFocusGoal(goal.id),
                child: const Text('Definir em foco'),
              ),
              TextButton(
                onPressed: () => _openGoalEditor(context, existing: goal),
                child: const Text('Editar'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Excluir meta',
                onPressed: () => _confirmDeleteGoal(context, goal),
                icon: const MetaFeitaIcon(MfIcon.excluir, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteGoal(BuildContext context, SavedGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir meta?', style: MfText.tituloCartao),
        content: Text(
          'A meta "${goal.title}" será removida deste aparelho.',
          style: MfText.corpo,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      controller.deleteGoal(goal.id);
    }
  }

  Future<void> _openGoalEditor(
    BuildContext context, {
    SavedGoal? existing,
    bool useExampleDefaults = false,
  }) async {
    final titleCtrl = TextEditingController(
      text: existing?.title ??
          (useExampleDefaults ? 'Reserva de emergência' : ''),
    );
    final targetCtrl = TextEditingController(
      text: existing != null
          ? PtBrFormatters.editableDecimal(existing.input.targetValue)
          : (useExampleDefaults ? '30.000,00' : ''),
    );
    final currentCtrl = TextEditingController(
      text: existing != null
          ? PtBrFormatters.editableDecimal(existing.input.currentCapital)
          : (useExampleDefaults ? '12.000,00' : '0,00'),
    );
    final contribCtrl = TextEditingController(
      text: existing != null
          ? PtBrFormatters.editableDecimal(existing.input.periodicContribution)
          : (useExampleDefaults ? '800,00' : ''),
    );
    final rateCtrl = TextEditingController(
      text: existing != null
          ? PtBrFormatters.editablePercent(existing.input.rate.value)
          : (useExampleDefaults ? '0,8' : ''),
    );
    final termCtrl = TextEditingController(
      text: existing != null
          ? existing.input.termMonths.toString()
          : (useExampleDefaults ? '18' : ''),
    );

    var ratePeriod = existing?.input.rate.period ?? RatePeriod.monthly;
    var rateKind = existing?.input.rate.kind ?? RateKind.effective;
    var timing = existing?.input.contributionTiming ?? ContributionTiming.end;
    var isFocus = existing?.isFocus ?? true;
    String? errorMsg;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MfColors.areiaCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              existing == null ? 'Nova meta' : 'Editar meta',
                              style: MfText.subtitulo,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const MetaFeitaIcon(MfIcon.fechar),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome da meta',
                          hintText: 'Ex.: Reserva de emergência',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      MoneyInput(
                        label: 'Valor-alvo',
                        controller: targetCtrl,
                      ),
                      const SizedBox(height: 12),
                      MoneyInput(
                        label: 'Capital atual',
                        controller: currentCtrl,
                      ),
                      const SizedBox(height: 12),
                      MoneyInput(
                        label: 'Aporte mensal',
                        controller: contribCtrl,
                        suffixText: 'por mês',
                      ),
                      const SizedBox(height: 12),
                      PercentageInput(
                        label: 'Taxa de rendimento',
                        controller: rateCtrl,
                        suffixText: ratePeriod == RatePeriod.monthly
                            ? '% ao mês'
                            : '% ao ano',
                      ),
                      const SizedBox(height: 10),
                      SegmentedChoice<RatePeriod>(
                        label: 'Periodicidade da taxa',
                        value: ratePeriod,
                        options: const [
                          SegmentedChoiceOption(
                            value: RatePeriod.monthly,
                            label: 'Efetiva ao mês',
                          ),
                          SegmentedChoiceOption(
                            value: RatePeriod.annual,
                            label: 'Efetiva ao ano',
                          ),
                        ],
                        onChanged: (v) => setModalState(() {
                          ratePeriod = v;
                          rateKind = RateKind.effective;
                        }),
                      ),
                      const SizedBox(height: 12),
                      SegmentedChoice<ContributionTiming>(
                        label: 'Momento do aporte',
                        value: timing,
                        options: const [
                          SegmentedChoiceOption(
                            value: ContributionTiming.beginning,
                            label: 'No início do mês',
                          ),
                          SegmentedChoiceOption(
                            value: ContributionTiming.end,
                            label: 'No fim do mês',
                          ),
                        ],
                        onChanged: (v) => setModalState(() => timing = v),
                      ),
                      const SizedBox(height: 12),
                      IntegerInput(
                        label: 'Prazo desejado',
                        controller: termCtrl,
                        suffixText: 'meses',
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Definir como meta em foco',
                          style: MfText.rotulo,
                        ),
                        value: isFocus,
                        onChanged: (v) =>
                            setModalState(() => isFocus = v ?? true),
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          errorMsg!,
                          style: MfText.pequeno.copyWith(color: MfColors.erro),
                        ),
                      ],
                      const SizedBox(height: 14),
                      PetroleoDarkButton(
                        label: 'Salvar meta',
                        onPressed: () {
                          final name = titleCtrl.text.trim();
                          final target =
                              PtBrFormatters.parseUserDecimal(targetCtrl.text);
                          final curr =
                              PtBrFormatters.parseUserDecimal(currentCtrl.text);
                          final contrib =
                              PtBrFormatters.parseUserDecimal(contribCtrl.text);
                          final ratePct =
                              PtBrFormatters.parseUserDecimal(rateCtrl.text);
                          final term = int.tryParse(termCtrl.text.trim());

                          if (name.isEmpty ||
                              target == null ||
                              curr == null ||
                              contrib == null ||
                              ratePct == null ||
                              term == null) {
                            setModalState(() {
                              errorMsg =
                                  'Preencha todos os campos com valores válidos.';
                            });
                            return;
                          }

                          try {
                            final goalInput = GoalInput(
                              targetValue: target,
                              currentCapital: curr,
                              periodicContribution: contrib,
                              contributionFrequency:
                                  ContributionFrequency.monthly,
                              contributionTiming: timing,
                              rate: RateInput.fromPercent(
                                percent: ratePct,
                                kind: rateKind,
                                period: ratePeriod,
                              ),
                              termMonths: term,
                            );
                            GoalsEngine.evaluate(goalInput);
                            final now = DateTime.now();
                            final saved = SavedGoal(
                              id: existing?.id ?? const Uuid().v4(),
                              title: name,
                              input: goalInput,
                              targetDate: CivilDate.today().addMonths(term),
                              isFocus: isFocus,
                              createdAt: existing?.createdAt ?? now,
                              updatedAt: now,
                            );
                            controller.saveGoal(saved);
                            Navigator.of(ctx).pop();
                          } catch (e) {
                            setModalState(() => errorMsg = e.toString());
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
