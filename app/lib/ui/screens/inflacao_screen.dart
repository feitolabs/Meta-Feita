import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../application/app_controller.dart';
import '../../domain/engines/inflation_engine.dart';
import '../../domain/models/rate_input.dart';
import '../../domain/models/simulation_models.dart';
import '../../domain/rules/formatters.dart';
import '../../domain/validation/input_validators.dart';
import '../theme/meta_feita_theme.dart';
import '../widgets/cards.dart';
import '../widgets/chart_card.dart';
import '../widgets/inputs.dart';
import '../widgets/meta_feita_buttons.dart';
import '../widgets/meta_feita_icon.dart';

class InflacaoScreen extends StatefulWidget {
  final AppController controller;
  final VoidCallback? onBack;

  const InflacaoScreen({
    super.key,
    required this.controller,
    this.onBack,
  });

  @override
  State<InflacaoScreen> createState() => _InflacaoScreenState();
}

class _InflacaoScreenState extends State<InflacaoScreen>
    with AutomaticKeepAliveClientMixin {
  final _nomCtrl = TextEditingController(text: '10,0');
  final _infCtrl = TextEditingController(text: '4,0');
  final _valCtrl = TextEditingController(text: '10.000,00');
  final _termCtrl = TextEditingController(text: '60');

  RatePeriod _period = RatePeriod.annual;
  Map<String, String> _errors = {};
  InflationResult? _result;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _infCtrl.dispose();
    _valCtrl.dispose();
    _termCtrl.dispose();
    super.dispose();
  }

  void _recompute() {
    final errors = <String, String>{};
    final nom = PtBrFormatters.parseUserDecimal(_nomCtrl.text);
    final inf = PtBrFormatters.parseUserDecimal(_infCtrl.text);
    final val = PtBrFormatters.parseUserDecimal(_valCtrl.text);
    final term = int.tryParse(_termCtrl.text.trim());

    if (nom == null) errors['nominalRate'] = 'Informe a taxa nominal.';
    if (inf == null) errors['inflationRate'] = 'Informe a inflação.';
    if (val == null) errors['nominalAmount'] = 'Informe o valor.';
    if (term == null) errors['horizonMonths'] = 'Informe o prazo em meses.';

    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _result = null;
      });
      return;
    }

    try {
      final res = InflationEngine.calculate(
        InflationInput(
          nominalRate: RateInput.fromPercent(
            percent: nom!,
            kind: RateKind.effective,
            period: _period,
          ),
          inflationRate: RateInput.fromPercent(
            percent: inf!,
            kind: RateKind.effective,
            period: _period,
          ),
          horizonMonths: term!,
          nominalAmount: val!,
        ),
      );
      setState(() {
        _errors = {};
        _result = res;
      });
    } on DomainValidationException catch (e) {
      setState(() {
        _errors = e.fieldErrors;
        _result = null;
      });
    }
  }

  void _save() {
    final res = _result;
    if (res == null) return;
    widget.controller.saveSimulation(
      title: 'Inflação e retorno real (${_termCtrl.text}m)',
      type: SimulationType.inflation,
      summaryLabel:
          '${PtBrFormatters.percentFromFraction(res.realAnnualRate)} real ao ano',
      inputData: {
        'nominal': _nomCtrl.text,
        'inflation': _infCtrl.text,
        'amount': _valCtrl.text,
        'months': _termCtrl.text,
      },
      resultData: {
        'realAnnualRate': res.realAnnualRate.toString(),
        'projectedRealValue': res.projectedRealValue.toString(),
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Simulação de inflação salva no histórico.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final res = _result;

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
                      onPressed: widget.onBack,
                      icon: const MetaFeitaIcon(MfIcon.voltar, size: 22),
                    ),
                  Expanded(
                    child:
                        Text('Inflação e retorno real', style: MfText.subtitulo),
                  ),
                  IconButton(
                    onPressed: () => showFormulaExplanationSheet(
                      context,
                      title: 'Fórmula de retorno real',
                      formula:
                          'Retorno real = ((1 + retorno nominal) / (1 + inflação)) - 1\n'
                          'Valor real futuro = Valor nominal futuro / (1 + inflação)^n',
                      rules: const [
                        'Taxa nominal e inflação são convertidas para a mesma periodicidade efetiva antes do cálculo.',
                        'Nunca subtrai simplesmente uma taxa da outra (Fisher é sempre exato).',
                      ],
                    ),
                    icon: const MetaFeitaIcon(MfIcon.info, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedChoice<RatePeriod>(
                label: 'Periodicidade das taxas (efetivas)',
                value: _period,
                options: const [
                  SegmentedChoiceOption(
                      value: RatePeriod.annual, label: 'Ao ano'),
                  SegmentedChoiceOption(
                      value: RatePeriod.monthly, label: 'Ao mês'),
                ],
                onChanged: (v) {
                  setState(() => _period = v);
                  _recompute();
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PercentageInput(
                      label: 'Retorno nominal',
                      controller: _nomCtrl,
                      suffixText:
                          _period == RatePeriod.annual ? '% a.a.' : '% a.m.',
                      errorText: _errors['nominalRate'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PercentageInput(
                      label: 'Inflação',
                      controller: _infCtrl,
                      suffixText:
                          _period == RatePeriod.annual ? '% a.a.' : '% a.m.',
                      errorText: _errors['inflationRate'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: MoneyInput(
                      label: 'Valor inicial',
                      controller: _valCtrl,
                      errorText: _errors['nominalAmount'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IntegerInput(
                      label: 'Horizonte',
                      controller: _termCtrl,
                      suffixText: 'meses',
                      errorText: _errors['horizonMonths'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (res != null) ...[
                DarkHighlightCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RETORNO REAL ANUAL (FISHER)',
                        style: MfText.legenda
                            .copyWith(color: MfColors.azulRioClaro),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${PtBrFormatters.percentFromFraction(res.realAnnualRate, decimals: 2)} ao ano',
                        style: MfText.numero.copyWith(
                          color: Colors.white,
                          fontSize: 34,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Equivalente a ${PtBrFormatters.percentFromFraction(res.realMonthlyRate, decimals: 4)} ao mês',
                        style: MfText.pequeno.copyWith(
                          color: MfColors.nevoaClaro,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: Colors.white.withValues(alpha: 0.14)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Valor nominal futuro',
                                  style: MfText.pequeno
                                      .copyWith(color: MfColors.nevoaClaro),
                                ),
                                Text(
                                  PtBrFormatters.money(res.projectedNominalValue),
                                  style: MfText.tituloCartao
                                      .copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Poder de compra hoje',
                                  style: MfText.pequeno
                                      .copyWith(color: MfColors.nevoaClaro),
                                ),
                                Text(
                                  PtBrFormatters.money(res.projectedRealValue),
                                  style: MfText.tituloCartao
                                      .copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ChartCard(
                  title: 'Valor nominal vs poder de compra',
                  xAxisUnit: 'meses',
                  seriesList: [
                    ChartSeriesData(
                      label: 'Valor nominal',
                      spots: res.series
                          .map((p) => FlSpot(
                              p.month.toDouble(), p.nominalValue.toDouble()))
                          .toList(),
                      color: MfColors.petroleo,
                      fillArea: true,
                    ),
                    ChartSeriesData(
                      label: 'Poder de compra (real)',
                      spots: res.series
                          .map((p) =>
                              FlSpot(p.month.toDouble(), p.realValue.toDouble()))
                          .toList(),
                      color: MfColors.azulRio,
                      dashed: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AssumptionDisclosure(assumptions: res.assumptions),
              ],
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
            label: 'Salvar simulação',
            onPressed: res != null ? _save : null,
          ),
        ),
      ],
    );
  }
}
