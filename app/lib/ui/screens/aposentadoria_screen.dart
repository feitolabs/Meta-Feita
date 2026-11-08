import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../application/app_controller.dart';
import '../../domain/engines/retirement_engine.dart';
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

class AposentadoriaScreen extends StatefulWidget {
  final AppController controller;
  final VoidCallback? onBack;

  const AposentadoriaScreen({
    super.key,
    required this.controller,
    this.onBack,
  });

  @override
  State<AposentadoriaScreen> createState() => _AposentadoriaScreenState();
}

class _AposentadoriaScreenState extends State<AposentadoriaScreen>
    with AutomaticKeepAliveClientMixin {
  final _ageCtrl = TextEditingController(text: '32');
  final _targetAgeCtrl = TextEditingController(text: '65');
  final _withdrawYearsCtrl = TextEditingController(text: '25');
  final _capCtrl = TextEditingController(text: '25.000,00');
  final _pmtCtrl = TextEditingController(text: '1.200,00');
  final _nomCtrl = TextEditingController(text: '10,5');
  final _infCtrl = TextEditingController(text: '4,2');
  final _incomeCtrl = TextEditingController(text: '6.000,00');

  Map<String, String> _errors = {};
  RetirementResult? _result;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _targetAgeCtrl.dispose();
    _withdrawYearsCtrl.dispose();
    _capCtrl.dispose();
    _pmtCtrl.dispose();
    _nomCtrl.dispose();
    _infCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  void _recompute() {
    final errors = <String, String>{};
    final age = int.tryParse(_ageCtrl.text.trim());
    final targetAge = int.tryParse(_targetAgeCtrl.text.trim());
    final years = int.tryParse(_withdrawYearsCtrl.text.trim());
    final cap = PtBrFormatters.parseUserDecimal(_capCtrl.text);
    final pmt = PtBrFormatters.parseUserDecimal(_pmtCtrl.text);
    final nom = PtBrFormatters.parseUserDecimal(_nomCtrl.text);
    final inf = PtBrFormatters.parseUserDecimal(_infCtrl.text);
    final income = PtBrFormatters.parseUserDecimal(_incomeCtrl.text);

    if (age == null) errors['currentAge'] = 'Idade inválida.';
    if (targetAge == null) errors['targetAge'] = 'Idade-alvo inválida.';
    if (years == null) errors['withdrawalYears'] = 'Anos de usufruto inválidos.';
    if (cap == null) errors['currentCapital'] = 'Capital inválido.';
    if (pmt == null) errors['monthlyContribution'] = 'Aporte inválido.';
    if (nom == null) errors['nominalRate'] = 'Taxa nominal inválida.';
    if (inf == null) errors['inflationRate'] = 'Inflação inválida.';
    if (income == null) errors['desiredMonthlyIncomeToday'] = 'Renda inválida.';

    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _result = null;
      });
      return;
    }

    try {
      final res = RetirementEngine.calculate(
        RetirementInput(
          currentAge: age!,
          targetAge: targetAge!,
          withdrawalYears: years!,
          currentCapital: cap!,
          monthlyContribution: pmt!,
          nominalRate: RateInput.fromPercent(
            percent: nom!,
            kind: RateKind.effective,
            period: RatePeriod.annual,
          ),
          inflationRate: RateInput.fromPercent(
            percent: inf!,
            kind: RateKind.effective,
            period: RatePeriod.annual,
          ),
          desiredMonthlyIncomeToday: income!,
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
      title: 'Aposentadoria aos ${_targetAgeCtrl.text} anos',
      type: SimulationType.retirement,
      summaryLabel:
          'Renda real ${PtBrFormatters.money(res.projectedSustainableMonthlyRealIncome)}/mês',
      inputData: {
        'currentAge': _ageCtrl.text,
        'targetAge': _targetAgeCtrl.text,
        'desiredIncome': _incomeCtrl.text,
      },
      resultData: {
        'estimatedRealCapital': res.estimatedRealCapital.toString(),
        'projectedSustainableMonthlyRealIncome':
            res.projectedSustainableMonthlyRealIncome.toString(),
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Planejamento de aposentadoria salvo.')),
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
                    child: Text('Aposentadoria', style: MfText.subtitulo),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: IntegerInput(
                      label: 'Idade atual',
                      controller: _ageCtrl,
                      suffixText: 'anos',
                      errorText: _errors['currentAge'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IntegerInput(
                      label: 'Idade-alvo',
                      controller: _targetAgeCtrl,
                      suffixText: 'anos',
                      errorText: _errors['targetAge'],
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
                      label: 'Capital atual',
                      controller: _capCtrl,
                      errorText: _errors['currentCapital'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MoneyInput(
                      label: 'Aporte mensal',
                      controller: _pmtCtrl,
                      errorText: _errors['monthlyContribution'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PercentageInput(
                      label: 'Taxa nominal',
                      controller: _nomCtrl,
                      suffixText: '% ao ano',
                      errorText: _errors['nominalRate'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PercentageInput(
                      label: 'Inflação',
                      controller: _infCtrl,
                      suffixText: '% ao ano',
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
                      label: 'Renda mensal desejada (hoje)',
                      controller: _incomeCtrl,
                      errorText: _errors['desiredMonthlyIncomeToday'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IntegerInput(
                      label: 'Período de retiradas',
                      controller: _withdrawYearsCtrl,
                      suffixText: 'anos',
                      errorText: _errors['withdrawalYears'],
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
                        'RENDA REAL ESTIMADA NA APOSENTADORIA',
                        style: MfText.legenda
                            .copyWith(color: MfColors.azulRioClaro),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${PtBrFormatters.money(res.projectedSustainableMonthlyRealIncome)} / mês',
                        style: MfText.numero.copyWith(
                          color: Colors.white,
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Em valores reais de hoje (${_withdrawYearsCtrl.text} anos de retiradas) · '
                        'Perpétua: ${PtBrFormatters.money(res.perpetualMonthlyRealIncome)}/mês',
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
                                  'Patrimônio em poder de hoje',
                                  style: MfText.pequeno
                                      .copyWith(color: MfColors.nevoaClaro),
                                ),
                                Text(
                                  PtBrFormatters.money(res.estimatedRealCapital),
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
                                  'Aporte ideal (hoje)',
                                  style: MfText.pequeno
                                      .copyWith(color: MfColors.nevoaClaro),
                                ),
                                Text(
                                  res.requiredMonthlyContribution != null
                                      ? PtBrFormatters.money(
                                          res.requiredMonthlyContribution!)
                                      : '—',
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
                  title: 'Acumulação nominal até os ${_targetAgeCtrl.text} anos',
                  xAxisUnit: 'meses',
                  seriesList: [
                    ChartSeriesData(
                      label: 'Saldo nominal acumulado',
                      spots: res.accumulationSeries
                          .map((p) => FlSpot(
                              p.periodIndex.toDouble(), p.balance.toDouble()))
                          .toList(),
                      color: MfColors.petroleo,
                      fillArea: true,
                      showTerminalDot: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AssumptionDisclosure(assumptions: res.assumptions),
                const SizedBox(height: 8),
                const ProjectionDisclaimer(
                  extraNotice:
                      'Esta simulação não constitui aconselhamento financeiro nem garantia de renda na aposentadoria.',
                ),
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

