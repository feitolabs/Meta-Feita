import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../application/app_controller.dart';
import '../../domain/engines/compound_interest_engine.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/rate_input.dart';
import '../../domain/models/simulation_models.dart';
import '../../domain/rules/formatters.dart';
import '../../domain/validation/input_validators.dart';
import '../theme/meta_feita_theme.dart';
import '../widgets/ad_banner_slot.dart';
import '../widgets/cards.dart';
import '../widgets/chart_card.dart';
import '../widgets/credit_cost_dialog.dart';
import '../widgets/inputs.dart';
import '../widgets/meta_feita_buttons.dart';
import '../widgets/meta_feita_icon.dart';

enum _RateChoice { effectiveMonthly, effectiveAnnual, nominalAnnual }

class JurosCompostosScreen extends StatefulWidget {
  final AppController controller;
  final SavedSimulation? initialSimulation;
  final VoidCallback? onBack;

  const JurosCompostosScreen({
    super.key,
    required this.controller,
    this.initialSimulation,
    this.onBack,
  });

  @override
  State<JurosCompostosScreen> createState() => _JurosCompostosScreenState();
}

class _JurosCompostosScreenState extends State<JurosCompostosScreen>
    with AutomaticKeepAliveClientMixin {
  final _capitalCtrl = TextEditingController(text: '10.000,00');
  final _aporteCtrl = TextEditingController(text: '500,00');
  final _taxaCtrl = TextEditingController(text: '0,9');
  final _prazoCtrl = TextEditingController(text: '60');

  ContributionFrequency _frequency = ContributionFrequency.monthly;
  ContributionTiming _timing = ContributionTiming.end;
  _RateChoice _rateChoice = _RateChoice.effectiveMonthly;
  final List<IrregularContribution> _irregularList = [];

  Map<String, String> _fieldErrors = {};
  CompoundInterestResult? _livePreview;
  CompoundInterestInput? _lastCalculatedInput;
  CompoundInterestResult? _calculatedResult;
  bool _showingResult = false;
  String? _editingSimulationId;
  String? _editingTitle;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitialSimulation();
    _recomputePreview();
  }

  @override
  void didUpdateWidget(covariant JurosCompostosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSimulation?.id != oldWidget.initialSimulation?.id &&
        widget.initialSimulation != null) {
      _loadInitialSimulation();
      _recomputePreview();
    }
  }

  void _loadInitialSimulation() {
    final sim = widget.initialSimulation;
    if (sim == null) return;
    try {
      final parsed = CompoundInterestInput.fromJson(sim.inputData);
      _editingSimulationId = sim.id;
      _editingTitle = sim.title;
      _capitalCtrl.text = PtBrFormatters.editableDecimal(parsed.initialCapital);
      _aporteCtrl.text = PtBrFormatters.editableDecimal(parsed.contribution);
      _taxaCtrl.text = PtBrFormatters.editablePercent(parsed.rate.value);
      _prazoCtrl.text = parsed.termMonths.toString();
      _frequency = parsed.contributionFrequency;
      _timing = parsed.contributionTiming;
      _irregularList
        ..clear()
        ..addAll(parsed.irregularContributions);
      if (parsed.rate.period == RatePeriod.monthly) {
        _rateChoice = _RateChoice.effectiveMonthly;
      } else if (parsed.rate.kind == RateKind.nominal) {
        _rateChoice = _RateChoice.nominalAnnual;
      } else {
        _rateChoice = _RateChoice.effectiveAnnual;
      }
      _showingResult = false;
    } catch (_) {}
  }

  @override
  void dispose() {
    _capitalCtrl.dispose();
    _aporteCtrl.dispose();
    _taxaCtrl.dispose();
    _prazoCtrl.dispose();
    super.dispose();
  }

  CompoundInterestInput? _buildAndValidateInput() {
    final errors = <String, String>{};
    final capital = PtBrFormatters.parseUserDecimal(_capitalCtrl.text);
    if (_capitalCtrl.text.trim().isEmpty || capital == null) {
      errors['initialCapital'] =
          'Informe o capital inicial (use 0 se partir do zero).';
    }
    final aporte = _aporteCtrl.text.trim().isEmpty
        ? Decimal.zero
        : PtBrFormatters.parseUserDecimal(_aporteCtrl.text);
    if (aporte == null) {
      errors['contribution'] = 'Valor de aporte inválido.';
    }
    final taxaPct = PtBrFormatters.parseUserDecimal(_taxaCtrl.text);
    if (_taxaCtrl.text.trim().isEmpty || taxaPct == null) {
      errors['rate'] = 'Informe a taxa de rendimento.';
    }
    final prazo = int.tryParse(_prazoCtrl.text.trim());
    if (_prazoCtrl.text.trim().isEmpty || prazo == null) {
      errors['termMonths'] = 'Informe o prazo em meses.';
    }

    if (errors.isNotEmpty) {
      _fieldErrors = errors;
      return null;
    }

    final rate = RateInput.fromPercent(
      percent: taxaPct!,
      kind: _rateChoice == _RateChoice.nominalAnnual
          ? RateKind.nominal
          : RateKind.effective,
      period: _rateChoice == _RateChoice.effectiveMonthly
          ? RatePeriod.monthly
          : RatePeriod.annual,
    );

    final candidate = CompoundInterestInput(
      initialCapital: capital!,
      contribution: aporte!,
      contributionFrequency: _frequency,
      contributionTiming: _timing,
      rate: rate,
      termMonths: prazo!,
      startDate: CivilDate.today(),
      irregularContributions: List.unmodifiable(_irregularList),
    );

    try {
      CompoundInterestEngine.calculate(candidate);
      _fieldErrors = {};
      return candidate;
    } on DomainValidationException catch (e) {
      _fieldErrors = e.fieldErrors;
      return null;
    }
  }

  void _recomputePreview() {
    final input = _buildAndValidateInput();
    if (input != null) {
      final res = CompoundInterestEngine.calculate(input);
      setState(() {
        _livePreview = res;
      });
    } else {
      setState(() {
        _livePreview = null;
      });
    }
  }

  void _onCalculatePressed() {
    final input = _buildAndValidateInput();
    if (input == null) {
      setState(() {});
      return;
    }
    final res = CompoundInterestEngine.calculate(input);
    setState(() {
      _lastCalculatedInput = input;
      _calculatedResult = res;
      _showingResult = true;
    });
    if (widget.controller.preferences.autoSaveSimulations) {
      widget.controller.saveSimulation(
        existingId: _editingSimulationId,
        title: _editingTitle ?? 'Juros compostos (${input.termMonths}m)',
        type: SimulationType.compoundInterest,
        summaryLabel: PtBrFormatters.money(res.finalValue),
        inputData: input.toJson(),
        resultData: res.toJson(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_showingResult &&
        _calculatedResult != null &&
        _lastCalculatedInput != null) {
      return _JurosResultadoView(
        controller: widget.controller,
        input: _lastCalculatedInput!,
        result: _calculatedResult!,
        existingId: _editingSimulationId,
        existingTitle: _editingTitle,
        onBackToEdit: () => setState(() => _showingResult = false),
        onSaved: (title) {
          setState(() => _editingTitle = title);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Simulação salva no histórico local.'),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Row(
                children: [
                  if (widget.onBack != null)
                    IconButton(
                      tooltip: 'Voltar',
                      onPressed: widget.onBack,
                      icon: const MetaFeitaIcon(MfIcon.voltar, size: 22),
                    ),
                  Expanded(
                    child: Text('Juros compostos', style: MfText.subtitulo),
                  ),
                  IconButton(
                    tooltip: 'Entender a fórmula',
                    onPressed: () => showFormulaExplanationSheet(
                      context,
                      title: 'Como funciona o cálculo',
                      formula:
                          'Fim do mês: VF = VP×(1+i)^n + PMT×[((1+i)^n - 1)/i]\n'
                          'Início do mês: VF = VP×(1+i)^n + PMT×[((1+i)^n - 1)/i]×(1+i)',
                      rules: const [
                        'Taxa anual efetiva é convertida por equivalência composta: (1 + ia)^(1/12) - 1, nunca dividida por 12.',
                        'Taxa nominal anual capitalizada mensalmente usa j / 12.',
                        'Quando o aporte é no início do mês, ele rende juros no próprio mês do depósito.',
                        'Frequências incompatíveis ou aportes irregulares utilizam simulação cronológica em calendário civil.',
                      ],
                    ),
                    icon: const MetaFeitaIcon(MfIcon.info, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Valores informados por você. Taxa e aporte com periodicidade e tipo explícitos.',
                style: MfText.corpo.copyWith(
                  color: MfColors.inkMuted,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20),
              MoneyInput(
                label: 'Capital inicial',
                controller: _capitalCtrl,
                errorText: _fieldErrors['initialCapital'],
                onChanged: (_) => _recomputePreview(),
              ),
              const SizedBox(height: 16),
              MoneyInput(
                label: 'Aporte periódico',
                controller: _aporteCtrl,
                suffixText: _frequency == ContributionFrequency.monthly
                    ? 'por mês'
                    : _frequency.labelPt.toLowerCase(),
                errorText: _fieldErrors['contribution'],
                onChanged: (_) => _recomputePreview(),
              ),
              const SizedBox(height: 12),
              FrequencySelector<ContributionFrequency>(
                label: 'Frequência do aporte',
                value: _frequency,
                options: const [
                  SegmentedChoiceOption(
                    value: ContributionFrequency.monthly,
                    label: 'Mensal',
                  ),
                  SegmentedChoiceOption(
                    value: ContributionFrequency.weekly,
                    label: 'Semanal',
                  ),
                  SegmentedChoiceOption(
                    value: ContributionFrequency.quarterly,
                    label: 'Trimestral',
                  ),
                  SegmentedChoiceOption(
                    value: ContributionFrequency.annual,
                    label: 'Anual',
                  ),
                  SegmentedChoiceOption(
                    value: ContributionFrequency.irregular,
                    label: 'Irregular',
                  ),
                ],
                onChanged: (v) {
                  setState(() => _frequency = v);
                  _recomputePreview();
                },
              ),
              if (_frequency == ContributionFrequency.irregular) ...[
                const SizedBox(height: 12),
                _IrregularContributionsCard(
                  items: _irregularList,
                  onChanged: () => _recomputePreview(),
                ),
              ],
              const SizedBox(height: 16),
              SegmentedChoice<ContributionTiming>(
                label: 'Momento do aporte',
                value: _timing,
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
                onChanged: (v) {
                  setState(() => _timing = v);
                  _recomputePreview();
                },
              ),
              const SizedBox(height: 16),
              PercentageInput(
                label: 'Taxa de rendimento',
                controller: _taxaCtrl,
                suffixText: _rateChoice == _RateChoice.effectiveMonthly
                    ? '% ao mês'
                    : '% ao ano',
                errorText: _fieldErrors['rate'],
                onChanged: (_) => _recomputePreview(),
              ),
              const SizedBox(height: 14),
              SegmentedChoice<_RateChoice>(
                label: 'Tipo da taxa',
                value: _rateChoice,
                options: const [
                  SegmentedChoiceOption(
                    value: _RateChoice.effectiveMonthly,
                    label: 'Efetiva ao mês',
                  ),
                  SegmentedChoiceOption(
                    value: _RateChoice.effectiveAnnual,
                    label: 'Efetiva ao ano',
                  ),
                  SegmentedChoiceOption(
                    value: _RateChoice.nominalAnnual,
                    label: 'Nominal ao ano',
                  ),
                ],
                onChanged: (v) {
                  setState(() => _rateChoice = v);
                  _recomputePreview();
                },
              ),
              const SizedBox(height: 16),
              IntegerInput(
                label: 'Prazo',
                controller: _prazoCtrl,
                suffixText: 'meses',
                errorText: _fieldErrors['termMonths'],
                onChanged: (_) => _recomputePreview(),
              ),
              if (_fieldErrors['irregularContributions'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  _fieldErrors['irregularContributions']!,
                  style: MfText.pequeno.copyWith(color: MfColors.erro),
                ),
              ],
              const SizedBox(height: 18),
              if (_livePreview != null)
                DarkHighlightCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRÉVIA DO VALOR FUTURO',
                        style: MfText.legenda.copyWith(
                          color: MfColors.azulRioClaro,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        PtBrFormatters.money(_livePreview!.finalValue),
                        style: MfText.numero.copyWith(
                          color: Colors.white,
                          fontSize: 30,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Investido ${PtBrFormatters.money(_livePreview!.totalPrincipal)} · '
                        'rendimento ${PtBrFormatters.money(_livePreview!.totalReturn)}',
                        style: MfText.pequeno.copyWith(
                          color: MfColors.nevoaClaro,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: const BoxDecoration(
            color: MfColors.areia,
            border: Border(top: BorderSide(color: MfColors.border)),
          ),
          child: BrasaPrimaryButton(
            label: 'Calcular',
            onPressed: _livePreview != null ? _onCalculatePressed : null,
          ),
        ),
      ],
    );
  }
}

class _JurosResultadoView extends StatelessWidget {
  final AppController controller;
  final CompoundInterestInput input;
  final CompoundInterestResult result;
  final String? existingId;
  final String? existingTitle;
  final VoidCallback onBackToEdit;
  final ValueChanged<String> onSaved;

  const _JurosResultadoView({
    required this.controller,
    required this.input,
    required this.result,
    required this.existingId,
    required this.existingTitle,
    required this.onBackToEdit,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final saldoSpots = result.series
        .map((p) => FlSpot(p.periodIndex.toDouble(), p.balance.toDouble()))
        .toList();
    final investidoSpots = result.series
        .map(
          (p) => FlSpot(p.periodIndex.toDouble(), p.totalInvested.toDouble()),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Voltar para editar',
              onPressed: onBackToEdit,
              icon: const MetaFeitaIcon(MfIcon.voltar, size: 22),
            ),
            Expanded(child: Text('Resultado', style: MfText.subtitulo)),
            IconButton(
              tooltip: 'Relatório detalhado',
              onPressed: () => _exportDetailedReport(context),
              icon: const MetaFeitaIcon(MfIcon.compartilhar, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DarkHighlightCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VALOR FUTURO ESTIMADO',
                style: MfText.legenda.copyWith(color: MfColors.azulRioClaro),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  PtBrFormatters.money(result.finalValue),
                  style: MfText.numero.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'em ${input.termMonths} meses · simulação hipotética',
                style: MfText.pequeno.copyWith(
                  color: MfColors.nevoaClaro,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.14)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total investido',
                          style: MfText.pequeno.copyWith(
                            color: MfColors.nevoaClaro,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          PtBrFormatters.money(result.totalPrincipal),
                          style: MfText.tituloCartao.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rendimento',
                          style: MfText.pequeno.copyWith(
                            color: MfColors.nevoaClaro,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          PtBrFormatters.money(result.totalReturn),
                          style: MfText.tituloCartao.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ChartCard(
          title: 'Evolução do saldo',
          xAxisUnit: 'meses',
          seriesList: [
            ChartSeriesData(
              label: 'Saldo',
              spots: saldoSpots,
              color: MfColors.petroleo,
              fillArea: true,
              showTerminalDot: true,
            ),
            ChartSeriesData(
              label: 'Total investido',
              spots: investidoSpots,
              color: MfColors.azulRio,
              dashed: true,
            ),
          ],
          onOpenTable: () => _showMonthByMonthTable(context),
        ),
        const SizedBox(height: 16),
        AssumptionDisclosure(
          title: 'Premissas usadas',
          assumptions: {
            'Capital inicial': PtBrFormatters.money(input.initialCapital),
            'Aporte':
                '${PtBrFormatters.money(input.contribution)} (${input.contributionFrequency.labelPt.toLowerCase()}, ${input.contributionTiming.shortPt})',
            'Taxa': input.rate.describePt(),
            'Prazo': '${input.termMonths} meses',
            'Ordem': input.contributionTiming == ContributionTiming.beginning
                ? 'Aporte no início, depois rendimento'
                : 'Rendimento, depois aporte',
          },
        ),
        const SizedBox(height: 16),
        BrasaPrimaryButton(
          label: 'Salvar simulação',
          onPressed: () => _promptSave(context),
        ),
        const SizedBox(height: 10),
        ContornoButton(
          label:
              'Relatório detalhado (${controller.catalog.findFeature('detailed_report')?.creditCost ?? 2} créditos)',
          leadingIcon: const MetaFeitaIcon(MfIcon.exportar, size: 18),
          onPressed: () => _exportDetailedReport(context),
        ),
        const SizedBox(height: 14),
        const ProjectionDisclaimer(),
        SafeAdBannerSlot(ads: controller.ads),
      ],
    );
  }

  Future<void> _promptSave(BuildContext context) async {
    final ctrl = TextEditingController(
      text: existingTitle ?? 'Aportes por ${input.termMonths} meses',
    );
    final savedTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('Salvar no histórico local', style: MfText.tituloCartao),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome da simulação',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (savedTitle != null && savedTitle.isNotEmpty) {
      controller.saveSimulation(
        existingId: existingId,
        title: savedTitle,
        type: SimulationType.compoundInterest,
        summaryLabel: PtBrFormatters.money(result.finalValue),
        inputData: input.toJson(),
        resultData: result.toJson(),
      );
      onSaved(savedTitle);
    }
  }

  Future<void> _exportDetailedReport(BuildContext context) async {
    final feature = controller.catalog.findFeature('detailed_report');
    final cost = feature?.creditCost ?? 2;
    if (!controller.isBalanceConfirmed) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conecte-se ao servidor de créditos para validar saldo antes de gerar o relatório avançado.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showCreditCostConfirmationDialog(
      context,
      featureTitle: feature?.title ?? 'Relatório detalhado',
      creditCost: cost,
      currentBalance: controller.creditBalance,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final csv = await controller.executeWithCredits<String>(
        featureId: 'detailed_report',
        action: () async {
          final buf = StringBuffer()
            ..writeln(
              'Periodo;Saldo;Total Investido;Aporte;Rendimento do Periodo',
            )
            ..writeAll(
              result.series.map(
                (p) =>
                    '${p.dateOrPeriod};${PtBrFormatters.money(p.balance)};${PtBrFormatters.money(p.totalInvested)};${PtBrFormatters.money(p.periodContribution)};${PtBrFormatters.money(p.periodReturn)}\n',
              ),
            );
          return buf.toString();
        },
      );
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text('Relatório detalhado gerado', style: MfText.tituloCartao),
          content: SizedBox(
            width: 520,
            height: 300,
            child: SingleChildScrollView(
              child: SelectableText(csv, style: MfText.pequeno),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showMonthByMonthTable(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MfColors.areiaCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tabela mês a mês',
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
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: result.series.length,
                    separatorBuilder: (_, _) => const Divider(height: 14),
                    itemBuilder: (_, idx) {
                      final p = result.series[idx];
                      return Row(
                        children: [
                          SizedBox(
                            width: 82,
                            child: Text(p.dateOrPeriod, style: MfText.rotulo),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Investido: ${PtBrFormatters.money(p.totalInvested)}',
                                  style: MfText.pequeno,
                                ),
                                Text(
                                  'Juros: ${PtBrFormatters.money(p.periodReturn)}',
                                  style: MfText.pequeno,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            PtBrFormatters.money(p.balance),
                            style: MfText.rotulo,
                          ),
                        ],
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
}

class _IrregularContributionsCard extends StatelessWidget {
  final List<IrregularContribution> items;
  final VoidCallback onChanged;

  const _IrregularContributionsCard({
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LightCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Aportes irregulares (datas civis)',
                  style: MfText.rotulo,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  items.add(
                    IrregularContribution(
                      date: CivilDate.today().addMonths(1),
                      amount: Decimal.fromInt(1000),
                    ),
                  );
                  onChanged();
                },
                icon: const MetaFeitaIcon(MfIcon.adicionar, size: 16),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          if (items.isEmpty)
            Text(
              'Nenhum aporte irregular adicionado. Toque em Adicionar para informar data e valor.',
              style: MfText.pequeno,
            )
          else
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${items[i].date.formatPtBr()} — ${PtBrFormatters.money(items[i].amount)}',
                        style: MfText.corpo.copyWith(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        items.removeAt(i);
                        onChanged();
                      },
                      icon: const MetaFeitaIcon(MfIcon.excluir, size: 18),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
