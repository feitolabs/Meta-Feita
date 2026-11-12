import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../application/app_controller.dart';
import '../../domain/engines/reinvestment_engine.dart';
import '../../domain/models/rate_input.dart';
import '../../domain/models/simulation_models.dart';
import '../../domain/rules/formatters.dart';
import '../../domain/validation/input_validators.dart';
import '../theme/meta_feita_theme.dart';
import '../widgets/ad_banner_slot.dart';
import '../widgets/cards.dart';
import '../widgets/chart_card.dart';
import '../widgets/inputs.dart';
import '../widgets/meta_feita_buttons.dart';
import '../widgets/meta_feita_icon.dart';

class ReinvestimentoScreen extends StatefulWidget {
  final AppController controller;
  final SavedSimulation? initialSimulation;
  final VoidCallback? onBack;

  const ReinvestimentoScreen({
    super.key,
    required this.controller,
    this.initialSimulation,
    this.onBack,
  });

  @override
  State<ReinvestimentoScreen> createState() => _ReinvestimentoScreenState();
}

class _ReinvestimentoScreenState extends State<ReinvestimentoScreen>
    with AutomaticKeepAliveClientMixin {
  final _qtyCtrl = TextEditingController(text: '100');
  final _priceCtrl = TextEditingController(text: '50,00');
  final _divCtrl = TextEditingController(text: '0,55');
  final _aporteCtrl = TextEditingController(text: '0,00');
  final _pctCtrl = TextEditingController(text: '100');
  final _costCtrl = TextEditingController(text: '0,00');
  final _termCtrl = TextEditingController(text: '24');

  DividendFrequency _frequency = DividendFrequency.monthly;
  ReinvestmentMode _reinvMode = ReinvestmentMode.full;
  QuantityMode _qtyMode = QuantityMode.integer;

  Map<String, String> _errors = {};
  ReinvestmentResult? _result;
  ReinvestmentInput? _lastInput;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _divCtrl.dispose();
    _aporteCtrl.dispose();
    _pctCtrl.dispose();
    _costCtrl.dispose();
    _termCtrl.dispose();
    super.dispose();
  }

  void _recompute() {
    final errors = <String, String>{};
    final qty = PtBrFormatters.parseUserDecimal(_qtyCtrl.text);
    if (qty == null) errors['initialQuantity'] = 'Quantidade inválida.';
    final price = PtBrFormatters.parseUserDecimal(_priceCtrl.text);
    if (price == null) errors['initialPrice'] = 'Preço por cota inválido.';
    final div = PtBrFormatters.parseUserDecimal(_divCtrl.text);
    if (div == null) errors['dividendPerUnit'] = 'Provento inválido.';
    final aporte = _aporteCtrl.text.trim().isEmpty
        ? Decimal.zero
        : PtBrFormatters.parseUserDecimal(_aporteCtrl.text);
    if (aporte == null) {
      errors['additionalMonthlyContribution'] = 'Valor inválido.';
    }
    final pct = _reinvMode == ReinvestmentMode.percentage
        ? PtBrFormatters.parseUserDecimal(_pctCtrl.text)
        : Decimal.fromInt(100);
    if (pct == null) errors['reinvestmentPercent'] = 'Percentual inválido.';
    final cost = _costCtrl.text.trim().isEmpty
        ? Decimal.zero
        : PtBrFormatters.parseUserDecimal(_costCtrl.text);
    if (cost == null) errors['explicitCostPerPurchase'] = 'Custo inválido.';
    final term = int.tryParse(_termCtrl.text.trim());
    if (term == null) errors['termMonths'] = 'Prazo inválido.';

    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _result = null;
      });
      return;
    }

    final input = ReinvestmentInput(
      initialQuantity: qty!,
      initialPrice: price!,
      dividendPerUnit: div!,
      frequency: _frequency,
      reinvestmentMode: _reinvMode,
      reinvestmentPercent: pct!,
      quantityMode: _qtyMode,
      termMonths: term!,
      additionalMonthlyContribution: aporte,
      explicitCostPerPurchase: cost,
    );

    try {
      final res = ReinvestmentEngine.calculate(input);
      setState(() {
        _errors = {};
        _lastInput = input;
        _result = res;
      });
    } on DomainValidationException catch (e) {
      setState(() {
        _errors = e.fieldErrors;
        _result = null;
      });
    }
  }

  Future<void> _save() async {
    if (_result == null || _lastInput == null) return;
    final titleCtrl = TextEditingController(
      text: 'Reinvestimento ${_lastInput!.termMonths}m',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('Salvar simulação', style: MfText.tituloCartao),
        content: TextField(
          controller: titleCtrl,
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
            onPressed: () => Navigator.of(ctx).pop(titleCtrl.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      widget.controller.saveSimulation(
        title: name,
        type: SimulationType.reinvestment,
        summaryLabel:
            '${PtBrFormatters.quantity(_result!.finalQuantity)} cotas · ${PtBrFormatters.money(_result!.finalEstimatedValue)}',
        inputData: {
          'initialQuantity': _lastInput!.initialQuantity.toString(),
          'initialPrice': _lastInput!.initialPrice.toString(),
          'dividendPerUnit': _lastInput!.dividendPerUnit.toString(),
          'termMonths': _lastInput!.termMonths,
        },
        resultData: {
          'finalQuantity': _result!.finalQuantity.toString(),
          'finalResidualCash': _result!.finalResidualCash.toString(),
          'finalEstimatedValue': _result!.finalEstimatedValue.toString(),
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulação de reinvestimento salva.')),
      );
    }
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
                    child: Text('Reinvestimento', style: MfText.subtitulo),
                  ),
                  IconButton(
                    onPressed: () => showFormulaExplanationSheet(
                      context,
                      title: 'Regras de reinvestimento',
                      formula:
                          'Inteiro: Cotas compradas = piso(Valor reinvestido / Preço)\n'
                          'Caixa residual = Caixa anterior + Valor - (Cotas × Preço)',
                      rules: const [
                        'Simula evolução hipotética das cotas e do caixa residual sem representar execução real de ordens.',
                        'No modo inteiro, sobra em dinheiro abaixo do preço unitário permanece como caixa residual.',
                        'O modo fracionário é hipótese de simulação e depende de disponibilidade na corretora.',
                      ],
                    ),
                    icon: const MetaFeitaIcon(MfIcon.info, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: IntegerInput(
                      label: 'Quantidade inicial',
                      controller: _qtyCtrl,
                      suffixText: 'cotas',
                      allowDecimal: _qtyMode == QuantityMode.fractional,
                      errorText: _errors['initialQuantity'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MoneyInput(
                      label: 'Preço por cota',
                      controller: _priceCtrl,
                      errorText: _errors['initialPrice'],
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
                      label: 'Provento por cota',
                      controller: _divCtrl,
                      errorText: _errors['dividendPerUnit'],
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
              const SizedBox(height: 14),
              FrequencySelector<DividendFrequency>(
                label: 'Frequência do provento',
                value: _frequency,
                options: const [
                  SegmentedChoiceOption(
                    value: DividendFrequency.monthly,
                    label: 'Mensal',
                  ),
                  SegmentedChoiceOption(
                    value: DividendFrequency.quarterly,
                    label: 'Trimestral',
                  ),
                  SegmentedChoiceOption(
                    value: DividendFrequency.semiannual,
                    label: 'Semestral',
                  ),
                  SegmentedChoiceOption(
                    value: DividendFrequency.annual,
                    label: 'Anual',
                  ),
                ],
                onChanged: (v) {
                  setState(() => _frequency = v);
                  _recompute();
                },
              ),
              const SizedBox(height: 14),
              SegmentedChoice<ReinvestmentMode>(
                label: 'Regra de reinvestimento',
                value: _reinvMode,
                options: const [
                  SegmentedChoiceOption(
                    value: ReinvestmentMode.full,
                    label: 'Integral (100%)',
                  ),
                  SegmentedChoiceOption(
                    value: ReinvestmentMode.percentage,
                    label: 'Percentual',
                  ),
                  SegmentedChoiceOption(
                    value: ReinvestmentMode.none,
                    label: 'Nenhum',
                  ),
                ],
                onChanged: (v) {
                  setState(() => _reinvMode = v);
                  _recompute();
                },
              ),
              if (_reinvMode == ReinvestmentMode.percentage) ...[
                const SizedBox(height: 12),
                PercentageInput(
                  label: 'Percentual reinvestido',
                  controller: _pctCtrl,
                  suffixText: '% dos proventos',
                  allowNegative: false,
                  errorText: _errors['reinvestmentPercent'],
                  onChanged: (_) => _recompute(),
                ),
              ],
              const SizedBox(height: 14),
              SegmentedChoice<QuantityMode>(
                label: 'Modo de quantidade',
                value: _qtyMode,
                options: const [
                  SegmentedChoiceOption(
                    value: QuantityMode.integer,
                    label: 'Cotas inteiras',
                  ),
                  SegmentedChoiceOption(
                    value: QuantityMode.fractional,
                    label: 'Fracionárias',
                  ),
                ],
                onChanged: (v) {
                  setState(() => _qtyMode = v);
                  _recompute();
                },
              ),
              if (_qtyMode == QuantityMode.fractional) ...[
                const SizedBox(height: 8),
                LightCard(
                  padding: const EdgeInsets.all(12),
                  backgroundColor: MfColors.areiaSubtle,
                  child: Text(
                    'Aviso: o modo de cotas fracionárias é uma hipótese de simulação, não confirmação de disponibilidade na corretora.',
                    style: MfText.pequeno.copyWith(color: MfColors.petroleo),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: MoneyInput(
                      label: 'Aporte extra/mês',
                      controller: _aporteCtrl,
                      errorText: _errors['additionalMonthlyContribution'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MoneyInput(
                      label: 'Custo por compra',
                      controller: _costCtrl,
                      errorText: _errors['explicitCostPerPurchase'],
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
                        'POSIÇÃO FINAL ESTIMADA',
                        style: MfText.legenda.copyWith(
                          color: MfColors.azulRioClaro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        PtBrFormatters.money(res.finalEstimatedValue),
                        style: MfText.numero.copyWith(
                          color: Colors.white,
                          fontSize: 34,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${PtBrFormatters.quantity(res.finalQuantity)} cotas totais '
                        '(+${PtBrFormatters.quantity(res.totalBoughtQuantity)} compradas)',
                        style: MfText.pequeno.copyWith(
                          color: MfColors.nevoaClaro,
                          fontSize: 14,
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
                                  'Proventos recebidos',
                                  style: MfText.pequeno.copyWith(
                                    color: MfColors.nevoaClaro,
                                  ),
                                ),
                                Text(
                                  PtBrFormatters.money(
                                    res.totalDividendsReceived,
                                  ),
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
                                  'Caixa residual',
                                  style: MfText.pequeno.copyWith(
                                    color: MfColors.nevoaClaro,
                                  ),
                                ),
                                Text(
                                  PtBrFormatters.money(res.finalResidualCash),
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
                const SizedBox(height: 14),
                ChartCard(
                  title: 'Evolução da posição',
                  xAxisUnit: 'meses',
                  seriesList: [
                    ChartSeriesData(
                      label: 'Valor da posição + caixa',
                      spots: res.series
                          .map(
                            (e) => FlSpot(
                              e.periodIndex.toDouble(),
                              e.estimatedPositionValue.toDouble(),
                            ),
                          )
                          .toList(),
                      color: MfColors.petroleo,
                      fillArea: true,
                      showTerminalDot: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SafeAdBannerSlot(ads: widget.controller.ads),
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
