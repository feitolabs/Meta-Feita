import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../application/app_controller.dart';
import '../../domain/engines/dividends_engine.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/rate_input.dart';
import '../../domain/models/simulation_models.dart';
import '../../domain/rules/formatters.dart';
import '../../domain/validation/input_validators.dart';
import '../theme/meta_feita_theme.dart';
import '../widgets/cards.dart';
import '../widgets/inputs.dart';
import '../widgets/meta_feita_buttons.dart';
import '../widgets/meta_feita_icon.dart';

class DividendosScreen extends StatefulWidget {
  final AppController controller;
  final SavedSimulation? initialSimulation;
  final VoidCallback? onBack;

  const DividendosScreen({
    super.key,
    required this.controller,
    this.initialSimulation,
    this.onBack,
  });

  @override
  State<DividendosScreen> createState() => _DividendosScreenState();
}

class _DividendosScreenState extends State<DividendosScreen>
    with AutomaticKeepAliveClientMixin {
  final _qtyCtrl = TextEditingController(text: '250');
  final _priceCtrl = TextEditingController(text: '98,40');
  final _divCtrl = TextEditingController(text: '0,85');
  final _targetIncomeCtrl = TextEditingController(text: '1.000,00');

  DividendFrequency _frequency = DividendFrequency.monthly;
  bool _fractionalMode = false;
  final List<IrregularDividendEvent> _irregularEvents = [
    IrregularDividendEvent(
      date: const CivilDate(2026, 3, 15),
      dividendPerUnit: Decimal.parse('0.85'),
    ),
    IrregularDividendEvent(
      date: const CivilDate(2026, 9, 15),
      dividendPerUnit: Decimal.parse('0.85'),
    ),
  ];

  Map<String, String> _errors = {};
  DividendsResult? _result;
  DividendsInput? _lastInput;
  String? _editingId;
  String? _editingTitle;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _recompute();
  }

  @override
  void didUpdateWidget(covariant DividendosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSimulation?.id != oldWidget.initialSimulation?.id &&
        widget.initialSimulation != null) {
      _loadInitial();
      _recompute();
    }
  }

  void _loadInitial() {
    final sim = widget.initialSimulation;
    if (sim == null) return;
    try {
      final parsed = DividendsInput.fromJson(sim.inputData);
      _editingId = sim.id;
      _editingTitle = sim.title;
      _qtyCtrl.text = PtBrFormatters.quantity(parsed.quantity);
      _priceCtrl.text = PtBrFormatters.editableDecimal(parsed.unitPrice);
      _divCtrl.text = PtBrFormatters.editableDecimal(parsed.dividendPerUnit);
      _targetIncomeCtrl.text = parsed.desiredMonthlyIncome != null
          ? PtBrFormatters.editableDecimal(parsed.desiredMonthlyIncome!)
          : '';
      _frequency = parsed.frequency;
      _fractionalMode = parsed.fractionalMode;
      if (parsed.irregularEvents.isNotEmpty) {
        _irregularEvents
          ..clear()
          ..addAll(parsed.irregularEvents);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _divCtrl.dispose();
    _targetIncomeCtrl.dispose();
    super.dispose();
  }

  void _recompute() {
    final errors = <String, String>{};
    final qty = PtBrFormatters.parseUserDecimal(_qtyCtrl.text);
    if (_qtyCtrl.text.trim().isEmpty || qty == null) {
      errors['quantity'] = 'Informe a quantidade.';
    }
    final price = PtBrFormatters.parseUserDecimal(_priceCtrl.text);
    if (_priceCtrl.text.trim().isEmpty || price == null) {
      errors['unitPrice'] = 'Informe o preço por cota.';
    }
    final div = PtBrFormatters.parseUserDecimal(_divCtrl.text);
    if (_divCtrl.text.trim().isEmpty || div == null) {
      errors['dividendPerUnit'] = 'Informe o provento por cota.';
    }
    final target = _targetIncomeCtrl.text.trim().isEmpty
        ? null
        : PtBrFormatters.parseUserDecimal(_targetIncomeCtrl.text);
    if (_targetIncomeCtrl.text.trim().isNotEmpty && target == null) {
      errors['desiredMonthlyIncome'] = 'Renda desejada inválida.';
    }

    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _result = null;
        _lastInput = null;
      });
      return;
    }

    final input = DividendsInput(
      quantity: qty!,
      unitPrice: price!,
      dividendPerUnit: div!,
      frequency: _frequency,
      fractionalMode: _fractionalMode,
      desiredMonthlyIncome: target,
      irregularEvents: List.unmodifiable(_irregularEvents),
    );

    try {
      final res = DividendsEngine.calculate(input);
      setState(() {
        _errors = {};
        _lastInput = input;
        _result = res;
      });
    } on DomainValidationException catch (e) {
      setState(() {
        _errors = e.fieldErrors;
        _result = null;
        _lastInput = null;
      });
    }
  }

  Future<void> _saveSimulation() async {
    if (_result == null || _lastInput == null) return;
    final ctrl = TextEditingController(
      text: _editingTitle ?? 'Renda com dividendos (${_frequency.labelPt})',
    );
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Salvar simulação', style: MfText.tituloCartao),
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

    if (title != null && title.isNotEmpty && mounted) {
      widget.controller.saveSimulation(
        existingId: _editingId,
        title: title,
        type: SimulationType.dividends,
        summaryLabel:
            '${PtBrFormatters.money(_result!.eventDividend)} por pagamento',
        inputData: _lastInput!.toJson(),
        resultData: {
          'eventDividend': _result!.eventDividend.toString(),
          'estimated12MonthsTotal': _result!.estimated12MonthsTotal.toString(),
          'dyPercent': _result!.hypotheticalAnnualDyPercent?.toString(),
        },
      );
      setState(() => _editingTitle = title);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulação de dividendos salva.')),
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
                      tooltip: 'Voltar',
                      onPressed: widget.onBack,
                      icon: const MetaFeitaIcon(MfIcon.voltar, size: 22),
                    ),
                  Expanded(
                    child: Text('Dividendos', style: MfText.subtitulo),
                  ),
                  IconButton(
                    tooltip: 'Entender o cálculo',
                    onPressed: () => showFormulaExplanationSheet(
                      context,
                      title: 'Como calculamos dividendos',
                      formula:
                          'Provento por pagamento = Quantidade × Provento por cota\n'
                          'DY hipotético = (Provento anual / Preço por cota) × 100',
                      rules: const [
                        'Um pagamento trimestral ou semestral nunca é tratado como se ocorresse todos os meses.',
                        'A média mensal matemática divide o total anual estimado por 12 apenas como referência.',
                        'Dividendos não são garantidos e podem variar ou deixar de ocorrer.',
                      ],
                    ),
                    icon: const MetaFeitaIcon(MfIcon.info, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: IntegerInput(
                      label: 'Quantidade',
                      controller: _qtyCtrl,
                      suffixText: 'cotas',
                      allowDecimal: _fractionalMode,
                      errorText: _errors['quantity'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MoneyInput(
                      label: 'Preço por cota',
                      controller: _priceCtrl,
                      errorText: _errors['unitPrice'],
                      onChanged: (_) => _recompute(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MoneyInput(
                label: 'Provento por cota',
                controller: _divCtrl,
                suffixText: 'por pagamento',
                errorText: _errors['dividendPerUnit'],
                onChanged: (_) => _recompute(),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Modo fracionário', style: MfText.rotulo),
                subtitle: Text(
                  _fractionalMode
                      ? 'Hipótese de simulação: nem toda corretora aceita cotas fracionárias.'
                      : 'Cotas inteiras',
                  style: MfText.pequeno,
                ),
                activeThumbColor: MfColors.petroleo,
                value: _fractionalMode,
                onChanged: (v) {
                  setState(() => _fractionalMode = v);
                  _recompute();
                },
              ),
              const SizedBox(height: 8),
              FrequencySelector<DividendFrequency>(
                label: 'Frequência de pagamento',
                value: _frequency,
                options: const [
                  SegmentedChoiceOption(
                    value: DividendFrequency.monthly,
                    label: 'Mensal',
                  ),
                  SegmentedChoiceOption(
                    value: DividendFrequency.bimonthly,
                    label: 'Bimestral',
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
                  SegmentedChoiceOption(
                    value: DividendFrequency.irregular,
                    label: 'Irregular',
                  ),
                ],
                onChanged: (v) {
                  setState(() => _frequency = v);
                  _recompute();
                },
              ),
              if (_frequency == DividendFrequency.irregular) ...[
                const SizedBox(height: 12),
                LightCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pagamentos irregulares em 12 meses',
                              style: MfText.rotulo,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _irregularEvents.add(
                                IrregularDividendEvent(
                                  date: CivilDate(
                                    2026,
                                    ((_irregularEvents.length * 3) % 12) + 1,
                                    15,
                                  ),
                                  dividendPerUnit:
                                      PtBrFormatters.parseUserDecimal(
                                              _divCtrl.text) ??
                                          Decimal.parse('0.50'),
                                ),
                              );
                              _recompute();
                            },
                            child: const Text('+ Evento'),
                          ),
                        ],
                      ),
                      for (var i = 0; i < _irregularEvents.length; i++)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_irregularEvents[i].date.formatMonthYearPtBr()} — '
                                '${PtBrFormatters.money(_irregularEvents[i].dividendPerUnit)}/cota',
                                style: MfText.pequeno.copyWith(
                                  color: MfColors.petroleo,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                _irregularEvents.removeAt(i);
                                _recompute();
                              },
                              icon: const MetaFeitaIcon(MfIcon.excluir, size: 18),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (res != null) ...[
                DarkHighlightCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROVENTO POR PAGAMENTO',
                        style: MfText.legenda.copyWith(
                          color: MfColors.azulRioClaro,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          PtBrFormatters.money(res.eventDividend),
                          style: MfText.numero.copyWith(color: Colors.white),
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
                                  'Em 12 meses\n(estimativa)',
                                  style: MfText.pequeno.copyWith(
                                    color: MfColors.nevoaClaro,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  PtBrFormatters.money(
                                      res.estimated12MonthsTotal),
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
                                  'DY hipotético',
                                  style: MfText.pequeno.copyWith(
                                    color: MfColors.nevoaClaro,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  res.hypotheticalAnnualDyPercent != null
                                      ? '${PtBrFormatters.percent(res.hypotheticalAnnualDyPercent!)} ao ano'
                                      : 'Informe preço > 0',
                                  style: MfText.tituloCartao.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Média mensal matemática de ${PtBrFormatters.money(res.mathematicalMonthlyAverage)}. '
                        'Não significa pagamento todo mês.',
                        style: MfText.pequeno.copyWith(
                          color: MfColors.nevoaClaro,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LightCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Renda que você quer', style: MfText.subtitulo),
                      const SizedBox(height: 12),
                      MoneyInput(
                        label: 'Renda média por mês',
                        controller: _targetIncomeCtrl,
                        errorText: _errors['desiredMonthlyIncome'],
                        onChanged: (_) => _recompute(),
                      ),
                      const SizedBox(height: 14),
                      if (res.targetWarning != null)
                        Text(
                          res.targetWarning!,
                          style: MfText.pequeno.copyWith(
                            color: MfColors.erro,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (res.requiredQuantity != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Cotas necessárias',
                                style: MfText.corpo.copyWith(
                                  color: MfColors.inkMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${PtBrFormatters.quantity(res.requiredQuantity!)} cotas',
                              style: MfText.tituloCartao,
                            ),
                          ],
                        ),
                        if (res.estimatedRequiredCapital != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Capital estimado',
                                  style: MfText.pequeno,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                PtBrFormatters.money(
                                    res.estimatedRequiredCapital!),
                                style: MfText.rotulo,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                LightCard(
                  padding: const EdgeInsets.all(16),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Calendário estimado de 12 meses',
                        style: MfText.tituloCartao,
                      ),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: res.calendar12Months.map((m) {
                            return Container(
                              width: 96,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: m.hasPayment
                                    ? MfColors.petroleo
                                    : MfColors.areiaSubtle,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.label,
                                    style: MfText.pequeno.copyWith(
                                      color: m.hasPayment
                                          ? MfColors.nevoaClaro
                                          : MfColors.inkMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    m.hasPayment
                                        ? PtBrFormatters.money(m.amount)
                                        : '—',
                                    style: MfText.rotulo.copyWith(
                                      fontSize: 13,
                                      color: m.hasPayment
                                          ? Colors.white
                                          : MfColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const ProjectionDisclaimer(
                  extraNotice:
                      'Proventos e preços informados são hipóteses. Dividendos não são garantidos.',
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
            onPressed: res != null ? _saveSimulation : null,
          ),
        ),
      ],
    );
  }
}
