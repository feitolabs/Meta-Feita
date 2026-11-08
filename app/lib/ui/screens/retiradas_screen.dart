import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../application/app_controller.dart';
import '../../domain/engines/withdrawal_engine.dart';
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

class RetiradasScreen extends StatefulWidget {
  final AppController controller;
  final VoidCallback? onBack;

  const RetiradasScreen({
    super.key,
    required this.controller,
    this.onBack,
  });

  @override
  State<RetiradasScreen> createState() => _RetiradasScreenState();
}

class _RetiradasScreenState extends State<RetiradasScreen>
    with AutomaticKeepAliveClientMixin {
  final _capCtrl = TextEditingController(text: '300.000,00');
  final _retCtrl = TextEditingController(text: '2.500,00');
  final _taxaCtrl = TextEditingController(text: '0,8');
  final _infCtrl = TextEditingController(text: '4,0');
  final _termCtrl = TextEditingController(text: '120');

  ContributionFrequency _freq = ContributionFrequency.monthly;
  ContributionTiming _timing = ContributionTiming.end;
  bool _adjustInflation = false;

  Map<String, String> _errors = {};
  WithdrawalResult? _result;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void dispose() {
    _capCtrl.dispose();
    _retCtrl.dispose();
    _taxaCtrl.dispose();
    _infCtrl.dispose();
    _termCtrl.dispose();
    super.dispose();
  }

  void _recompute() {
    final errors = <String, String>{};
    final cap = PtBrFormatters.parseUserDecimal(_capCtrl.text);
    final ret = PtBrFormatters.parseUserDecimal(_retCtrl.text);
    final taxa = PtBrFormatters.parseUserDecimal(_taxaCtrl.text);
    final inf = _adjustInflation
        ? PtBrFormatters.parseUserDecimal(_infCtrl.text)
        : null;
    final term = int.tryParse(_termCtrl.text.trim());

    if (cap == null) errors['initialCapital'] = 'Capital inválido.';
    if (ret == null) errors['withdrawalAmount'] = 'Valor de retirada inválido.';
    if (taxa == null) errors['rate'] = 'Taxa inválida.';
    if (_adjustInflation && inf == null) errors['inflationRate'] = 'Inflação inválida.';
    if (term == null) errors['termMonths'] = 'Prazo inválido.';

    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _result = null;
      });
      return;
    }

    try {
      final res = WithdrawalEngine.calculate(
        WithdrawalInput(
          initialCapital: cap!,
          rate: RateInput.fromPercent(
            percent: taxa!,
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          withdrawalAmount: ret!,
          withdrawalFrequency: _freq,
          withdrawalTiming: _timing,
          termMonths: term!,
          inflationRate: _adjustInflation
              ? RateInput.fromPercent(
                  percent: inf!,
                  kind: RateKind.effective,
                  period: RatePeriod.annual,
                )
              : null,
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
      title: 'Retiradas (${_termCtrl.text}m)',
      type: SimulationType.withdrawal,
      summaryLabel: res.depletionPeriod != null
          ? 'Esgota no mês ${res.depletionPeriod}'
          : 'Saldo final ${PtBrFormatters.money(res.finalBalance)}',
      inputData: {
        'capital': _capCtrl.text,
        'withdrawal': _retCtrl.text,
        'rate': _taxaCtrl.text,
        'months': _termCtrl.text,
      },
      resultData: {
        'finalBalance': res.finalBalance.toString(),
        'totalWithdrawn': res.totalWithdrawn.toString(),
        'depletionPeriod': res.depletionPeriod,
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Simulação de retiradas salva.')),
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
                        Text('Simulador de retiradas', style: MfText.subtitulo),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MoneyInput(
                label: 'Capital inicial',
                controller: _capCtrl,
                errorText: _errors['initialCapital'],
                onChanged: (_) => _recompute(),
              ),
              const SizedBox(height: 14),
              MoneyInput(
                label: 'Valor da retirada',
                controller: _retCtrl,
                suffixText: _freq.labelPt.toLowerCase(),
                errorText: _errors['withdrawalAmount'],
                onChanged: (_) => _recompute(),
              ),
              const SizedBox(height: 12),
              FrequencySelector<ContributionFrequency>(
                label: 'Frequência da retirada',
                value: _freq,
                options: const [
                  SegmentedChoiceOption(
                      value: ContributionFrequency.monthly, label: 'Mensal'),
                  SegmentedChoiceOption(
                      value: ContributionFrequency.quarterly, label: 'Trimestral'),
                  SegmentedChoiceOption(
                      value: ContributionFrequency.annual, label: 'Anual'),
                ],
                onChanged: (v) {
                  setState(() => _freq = v);
                  _recompute();
                },
              ),
              const SizedBox(height: 14),
              SegmentedChoice<ContributionTiming>(
                label: 'Momento da retirada',
                value: _timing,
                options: const [
                  SegmentedChoiceOption(
                      value: ContributionTiming.beginning,
                      label: 'No início do mês'),
                  SegmentedChoiceOption(
                      value: ContributionTiming.end, label: 'No fim do mês'),
                ],
                onChanged: (v) {
                  setState(() => _timing = v);
                  _recompute();
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PercentageInput(
                      label: 'Taxa efetiva',
                      controller: _taxaCtrl,
                      suffixText: '% ao mês',
                      errorText: _errors['rate'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IntegerInput(
                      label: 'Prazo',
                      controller: _termCtrl,
                      suffixText: 'meses',
                      errorText: _errors['termMonths'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Corrigir retiradas pela inflação', style: MfText.rotulo),
                activeThumbColor: MfColors.petroleo,
                value: _adjustInflation,
                onChanged: (v) {
                  setState(() => _adjustInflation = v);
                  _recompute();
                },
              ),
              if (_adjustInflation) ...[
                PercentageInput(
                  label: 'Inflação efetiva anual',
                  controller: _infCtrl,
                  suffixText: '% ao ano',
                  errorText: _errors['inflationRate'],
                  onChanged: (_) => _recompute(),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 10),
              if (res != null) ...[
                DarkHighlightCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SALDO FINAL AO TÉRMINO DO PRAZO',
                        style: MfText.legenda
                            .copyWith(color: MfColors.azulRioClaro),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        PtBrFormatters.money(res.finalBalance),
                        style: MfText.numero.copyWith(
                          color: Colors.white,
                          fontSize: 34,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (res.depletionPeriod != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: MfColors.brasaClaro.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Saldo insuficiente a partir do mês ${res.depletionPeriod}. Déficit acumulado: ${PtBrFormatters.money(res.totalDeficit)}.',
                            style: MfText.pequeno.copyWith(
                              color: MfColors.brasaClaro,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        Text(
                          'Patrimônio sustenta todas as retiradas ao longo de ${_termCtrl.text} meses.',
                          style: MfText.pequeno.copyWith(
                            color: MfColors.nevoaClaro,
                          ),
                        ),
                      const SizedBox(height: 14),
                      Divider(color: Colors.white.withValues(alpha: 0.14)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total efetivamente sacado',
                            style: MfText.pequeno
                                .copyWith(color: MfColors.nevoaClaro),
                          ),
                          Text(
                            PtBrFormatters.money(res.totalWithdrawn),
                            style: MfText.rotulo.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ChartCard(
                  title: 'Saldo durante as retiradas',
                  xAxisUnit: 'meses',
                  seriesList: [
                    ChartSeriesData(
                      label: 'Saldo restante',
                      spots: res.series
                          .map((p) => FlSpot(p.periodIndex.toDouble(),
                              p.endingBalance.toDouble()))
                          .toList(),
                      color: MfColors.petroleo,
                      fillArea: true,
                      showTerminalDot: true,
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

