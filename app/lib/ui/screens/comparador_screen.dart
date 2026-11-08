import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../application/app_controller.dart';
import '../../domain/engines/comparator_engine.dart';
import '../../domain/models/rate_input.dart';
import '../../domain/models/simulation_models.dart';
import '../../domain/rules/formatters.dart';
import '../theme/meta_feita_theme.dart';
import '../widgets/cards.dart';
import '../widgets/chart_card.dart';
import '../widgets/credit_cost_dialog.dart';
import '../widgets/inputs.dart';
import '../widgets/meta_feita_buttons.dart';
import '../widgets/meta_feita_icon.dart';

class _EditableScenario {
  final TextEditingController name;
  final TextEditingController capital;
  final TextEditingController aporte;
  final TextEditingController taxa;
  RatePeriod period = RatePeriod.monthly;

  _EditableScenario({
    required String name,
    required String capital,
    required String aporte,
    required String taxa,
  })  : name = TextEditingController(text: name),
        capital = TextEditingController(text: capital),
        aporte = TextEditingController(text: aporte),
        taxa = TextEditingController(text: taxa);

  void dispose() {
    name.dispose();
    capital.dispose();
    aporte.dispose();
    taxa.dispose();
  }
}

class ComparadorScreen extends StatefulWidget {
  final AppController controller;
  final VoidCallback? onBack;

  const ComparadorScreen({
    super.key,
    required this.controller,
    this.onBack,
  });

  @override
  State<ComparadorScreen> createState() => _ComparadorScreenState();
}

class _ComparadorScreenState extends State<ComparadorScreen>
    with AutomaticKeepAliveClientMixin {
  final _termCtrl = TextEditingController(text: '60');
  ContributionTiming _timing = ContributionTiming.end;
  final List<_EditableScenario> _scenarios = [
    _EditableScenario(
      name: 'Conservador',
      capital: '10.000,00',
      aporte: '500,00',
      taxa: '0,7',
    ),
    _EditableScenario(
      name: 'Moderado',
      capital: '10.000,00',
      aporte: '500,00',
      taxa: '0,9',
    ),
  ];

  bool _extendedUnlocked = false;
  ComparatorResult? _result;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _compare();
  }

  @override
  void dispose() {
    _termCtrl.dispose();
    for (final s in _scenarios) {
      s.dispose();
    }
    super.dispose();
  }

  void _compare() {
    final term = int.tryParse(_termCtrl.text.trim());
    if (term == null || term <= 0) {
      setState(() {
        _error = 'Informe um prazo compartilhado válido em meses.';
        _result = null;
      });
      return;
    }

    try {
      final inputs = <ComparatorScenarioInput>[];
      for (final s in _scenarios) {
        final cap = PtBrFormatters.parseUserDecimal(s.capital.text);
        final pmt = PtBrFormatters.parseUserDecimal(s.aporte.text);
        final ratePct = PtBrFormatters.parseUserDecimal(s.taxa.text);
        if (cap == null || pmt == null || ratePct == null) {
          throw Exception(
              'Verifique os números do cenário "${s.name.text.trim()}".');
        }
        inputs.add(
          ComparatorScenarioInput(
            name: s.name.text.trim().isEmpty ? 'Cenário' : s.name.text.trim(),
            input: CompoundInterestInput(
              initialCapital: cap,
              contribution: pmt,
              contributionFrequency: ContributionFrequency.monthly,
              contributionTiming: _timing,
              rate: RateInput.fromPercent(
                percent: ratePct,
                kind: RateKind.effective,
                period: s.period,
              ),
              termMonths: term,
            ),
          ),
        );
      }

      final cmp = ComparatorEngine.compare(inputs);
      setState(() {
        _error = null;
        _result = cmp;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _result = null;
      });
    }
  }

  Future<void> _addScenario() async {
    if (_scenarios.length >= 4) return;
    if (_scenarios.length >= 2 && !_extendedUnlocked) {
      final feat = widget.controller.catalog.findFeature('extended_comparison');
      final cost = feat?.creditCost ?? 2;
      if (widget.controller.isBalanceConfirmed) {
        final ok = await showCreditCostConfirmationDialog(
          context,
          featureTitle: feat?.title ?? 'Comparação ampliada (3 a 4 cenários)',
          creditCost: cost,
          currentBalance: widget.controller.creditBalance,
        );
        if (!ok || !mounted) return;
        try {
          await widget.controller.executeWithCredits<void>(
            featureId: 'extended_comparison',
            action: () async {},
          );
          _extendedUnlocked = true;
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
          return;
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Comparar 2 cenários é gratuito offline. Para ampliar para 3 ou 4 cenários, conecte-se ao servidor de créditos.',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _scenarios.add(
        _EditableScenario(
          name: 'Cenário ${_scenarios.length + 1}',
          capital: '10.000,00',
          aporte: '700,00',
          taxa: '1,1',
        ),
      );
    });
    _compare();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = [
      MfColors.petroleo,
      MfColors.azulRio,
      const Color(0xFF3E6E77),
      MfColors.azulRioClaro,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            if (widget.onBack != null)
              IconButton(
                onPressed: widget.onBack,
                icon: const MetaFeitaIcon(MfIcon.voltar, size: 22),
              ),
            Expanded(
              child: Text('Comparador', style: MfText.subtitulo),
            ),
            if (_scenarios.length < 4)
              ContornoButton(
                label: '+ Cenário',
                fullWidth: false,
                compact: true,
                onPressed: _addScenario,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Compare de 2 a 4 cenários com o mesmo prazo e a mesma ordem de eventos.',
          style: MfText.corpo.copyWith(color: MfColors.inkMuted, fontSize: 15),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: IntegerInput(
                label: 'Prazo comum',
                controller: _termCtrl,
                suffixText: 'meses',
                onChanged: (_) => _compare(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SegmentedChoice<ContributionTiming>(
                label: 'Momento do aporte',
                value: _timing,
                options: const [
                  SegmentedChoiceOption(
                      value: ContributionTiming.beginning, label: 'Início'),
                  SegmentedChoiceOption(
                      value: ContributionTiming.end, label: 'Fim do mês'),
                ],
                onChanged: (v) {
                  setState(() => _timing = v);
                  _compare();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _scenarios.length; i++) ...[
          LightCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[i],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _scenarios[i].name,
                        onChanged: (_) => _compare(),
                        style: MfText.tituloCartao,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Nome do cenário',
                        ),
                      ),
                    ),
                    if (_scenarios.length > 2)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _scenarios[i].dispose();
                            _scenarios.removeAt(i);
                          });
                          _compare();
                        },
                        icon: const MetaFeitaIcon(MfIcon.excluir, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: MoneyInput(
                        label: 'Capital',
                        controller: _scenarios[i].capital,
                        onChanged: (_) => _compare(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MoneyInput(
                        label: 'Aporte/mês',
                        controller: _scenarios[i].aporte,
                        onChanged: (_) => _compare(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: PercentageInput(
                        label: 'Taxa efetiva',
                        controller: _scenarios[i].taxa,
                        suffixText: _scenarios[i].period == RatePeriod.monthly
                            ? '% a.m.'
                            : '% a.a.',
                        onChanged: (_) => _compare(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SegmentedChoice<RatePeriod>(
                        label: 'Período',
                        value: _scenarios[i].period,
                        options: const [
                          SegmentedChoiceOption(
                              value: RatePeriod.monthly, label: 'Mês'),
                          SegmentedChoiceOption(
                              value: RatePeriod.annual, label: 'Ano'),
                        ],
                        onChanged: (v) {
                          setState(() => _scenarios[i].period = v);
                          _compare();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null)
          Text(_error!, style: MfText.pequeno.copyWith(color: MfColors.erro)),
        if (_result != null) ...[
          DarkHighlightCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MAIOR VALOR FUTURO',
                  style: MfText.legenda.copyWith(color: MfColors.azulRioClaro),
                ),
                const SizedBox(height: 6),
                Text(
                  _result!.scenarios[_result!.bestScenarioIndex].name,
                  style: MfText.subtitulo.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${PtBrFormatters.money(_result!.scenarios[_result!.bestScenarioIndex].result.finalValue)} '
                  '· diferença de ${PtBrFormatters.money(_result!.spreadBetweenBestAndWorst)} para o menor cenário',
                  style: MfText.pequeno.copyWith(
                    color: MfColors.nevoaClaro,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ChartCard(
            title: 'Comparação lado a lado',
            xAxisUnit: 'meses',
            seriesList: [
              for (var i = 0; i < _result!.scenarios.length; i++)
                ChartSeriesData(
                  label: _result!.scenarios[i].name,
                  spots: _result!.scenarios[i].result.series
                      .map((p) => FlSpot(
                          p.periodIndex.toDouble(), p.balance.toDouble()))
                      .toList(),
                  color: colors[i],
                  dashed: i.isOdd,
                  showTerminalDot: true,
                ),
            ],
          ),
          const SizedBox(height: 14),
          LightCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resumo comparativo', style: MfText.tituloCartao),
                const SizedBox(height: 12),
                for (var i = 0; i < _result!.scenarios.length; i++) ...[
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _result!.scenarios[i].name,
                          style: MfText.rotulo,
                        ),
                      ),
                      Text(
                        PtBrFormatters.money(
                            _result!.scenarios[i].result.finalValue),
                        style: MfText.rotulo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aportado: ${PtBrFormatters.money(_result!.scenarios[i].result.totalPrincipal)} · '
                    'Rendimento: ${PtBrFormatters.money(_result!.scenarios[i].result.totalReturn)} · '
                    'Taxa: ${_result!.scenarios[i].input.rate.describePt()}',
                    style: MfText.pequeno,
                  ),
                  if (i < _result!.scenarios.length - 1)
                    const Divider(height: 18),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const ProjectionDisclaimer(),
      ],
    );
  }
}
