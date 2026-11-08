import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_feita/domain/engines/comparator_engine.dart';
import 'package:meta_feita/domain/engines/compound_interest_engine.dart';
import 'package:meta_feita/domain/engines/dividends_engine.dart';
import 'package:meta_feita/domain/engines/goals_engine.dart';
import 'package:meta_feita/domain/engines/inflation_engine.dart';
import 'package:meta_feita/domain/engines/rate_converter.dart';
import 'package:meta_feita/domain/engines/reinvestment_engine.dart';
import 'package:meta_feita/domain/engines/retirement_engine.dart';
import 'package:meta_feita/domain/engines/withdrawal_engine.dart';
import 'package:meta_feita/domain/models/civil_date.dart';
import 'package:meta_feita/domain/models/credit_models.dart';
import 'package:meta_feita/domain/models/goal_models.dart';
import 'package:meta_feita/domain/models/rate_input.dart';
import 'package:meta_feita/domain/models/simulation_models.dart';
import 'package:meta_feita/domain/rules/backup_validator.dart';
import 'package:meta_feita/domain/rules/formatters.dart';
import 'package:meta_feita/domain/validation/input_validators.dart';

void main() {
  group('Doc 02 - Casos de referência Juros Compostos (CI)', () {
    test('CI-001: PV=1000; i=0%; n=12; sem aportes -> VF=1000,00', () {
      final res = CompoundInterestEngine.calculate(
        CompoundInterestInput(
          initialCapital: Decimal.fromInt(1000),
          contribution: Decimal.zero,
          contributionFrequency: ContributionFrequency.monthly,
          contributionTiming: ContributionTiming.end,
          rate: RateInput.fromPercent(
            percent: Decimal.zero,
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          termMonths: 12,
        ),
      );
      expect(res.finalValue, Decimal.parse('1000.00'));
      expect(res.totalReturn, Decimal.zero);
    });

    test('CI-002: PV=1000; i=1% ao mês; n=1; sem aportes -> VF=1010,00', () {
      final res = CompoundInterestEngine.calculate(
        CompoundInterestInput(
          initialCapital: Decimal.fromInt(1000),
          contribution: Decimal.zero,
          contributionFrequency: ContributionFrequency.monthly,
          contributionTiming: ContributionTiming.end,
          rate: RateInput.fromPercent(
            percent: Decimal.one,
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          termMonths: 1,
        ),
      );
      expect(res.finalValue, Decimal.parse('1010.00'));
    });

    test('CI-003: PV=0; PMT=100; i=0%; n=12; aporte fim -> VF=1200,00', () {
      final res = CompoundInterestEngine.calculate(
        CompoundInterestInput(
          initialCapital: Decimal.zero,
          contribution: Decimal.fromInt(100),
          contributionFrequency: ContributionFrequency.monthly,
          contributionTiming: ContributionTiming.end,
          rate: RateInput.fromPercent(
            percent: Decimal.zero,
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          termMonths: 12,
        ),
      );
      expect(res.finalValue, Decimal.parse('1200.00'));
    });

    test('CI-004 & §15.2: PV=1000; PMT=100; i=0%; n=12; aporte fim -> VF=2200,00', () {
      final res = CompoundInterestEngine.calculate(
        CompoundInterestInput(
          initialCapital: Decimal.fromInt(1000),
          contribution: Decimal.fromInt(100),
          contributionFrequency: ContributionFrequency.monthly,
          contributionTiming: ContributionTiming.end,
          rate: RateInput.fromPercent(
            percent: Decimal.zero,
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          termMonths: 12,
        ),
      );
      expect(res.finalValue, Decimal.parse('2200.00'));
    });

    test('§15.1: PV=1000; i=1% efetiva ao mês; n=12 -> VF=1126,83; Rend=126,83', () {
      final res = CompoundInterestEngine.calculate(
        CompoundInterestInput(
          initialCapital: Decimal.fromInt(1000),
          contribution: Decimal.zero,
          contributionFrequency: ContributionFrequency.monthly,
          contributionTiming: ContributionTiming.end,
          rate: RateInput.fromPercent(
            percent: Decimal.one,
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          termMonths: 12,
        ),
      );
      expect(res.finalValue, Decimal.parse('1126.83'));
      expect(res.totalReturn, Decimal.parse('126.83'));
    });

    test('Protótipo PDF Páginas 2-3: 10000 + 500/mês fim a 0,9% por 60 meses -> 56666,82', () {
      final res = CompoundInterestEngine.calculate(
        CompoundInterestInput(
          initialCapital: Decimal.fromInt(10000),
          contribution: Decimal.fromInt(500),
          contributionFrequency: ContributionFrequency.monthly,
          contributionTiming: ContributionTiming.end,
          rate: RateInput.fromPercent(
            percent: Decimal.parse('0.9'),
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          termMonths: 60,
        ),
      );
      expect(res.finalValue, Decimal.parse('56666.82'));
      expect(res.totalPrincipal, Decimal.parse('40000.00'));
      expect(res.totalReturn, Decimal.parse('16666.82'));
    });

    test('Aporte no início vs fim gera resultados distintos e corretos', () {
      final endRes = CompoundInterestEngine.calculate(
        CompoundInterestInput(
          initialCapital: Decimal.zero,
          contribution: Decimal.fromInt(500),
          contributionFrequency: ContributionFrequency.monthly,
          contributionTiming: ContributionTiming.end,
          rate: RateInput.fromPercent(
            percent: Decimal.one,
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          termMonths: 12,
        ),
      );
      final begRes = CompoundInterestEngine.calculate(
        CompoundInterestInput(
          initialCapital: Decimal.zero,
          contribution: Decimal.fromInt(500),
          contributionFrequency: ContributionFrequency.monthly,
          contributionTiming: ContributionTiming.beginning,
          rate: RateInput.fromPercent(
            percent: Decimal.one,
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          termMonths: 12,
        ),
      );
      expect(begRes.finalValue > endRes.finalValue, isTrue);
      // beg = end * 1.01
      final expectedBeg = (endRes.finalValue * Decimal.parse('1.01')).round(scale: 2);
      expect((begRes.finalValue - expectedBeg).abs() <= Decimal.parse('0.01'), isTrue);
    });

    test('Taxa efetiva anual NÃO divide por 12; taxa nominal anual divide por 12', () {
      final effMonthly = RateConverter.toEffectiveMonthly(
        RateInput.fromPercent(
          percent: Decimal.fromInt(12),
          kind: RateKind.effective,
          period: RatePeriod.annual,
        ),
      );
      final nomMonthly = RateConverter.toEffectiveMonthly(
        RateInput.fromPercent(
          percent: Decimal.fromInt(12),
          kind: RateKind.nominal,
          period: RatePeriod.annual,
        ),
      );
      expect(nomMonthly, Decimal.parse('0.01'));
      expect(effMonthly < nomMonthly, isTrue);
      // (1 + effMonthly)^12 == 1.12
      final res = CompoundInterestEngine.calculate(
        CompoundInterestInput(
          initialCapital: Decimal.fromInt(1000),
          contribution: Decimal.zero,
          contributionFrequency: ContributionFrequency.monthly,
          contributionTiming: ContributionTiming.end,
          rate: RateInput.fromPercent(
            percent: Decimal.fromInt(12),
            kind: RateKind.effective,
            period: RatePeriod.annual,
          ),
          termMonths: 12,
        ),
      );
      expect(res.finalValue, Decimal.parse('1120.00'));
    });

    test('Rejeita taxa <= -100% e valores negativos', () {
      expect(
        () => CompoundInterestEngine.calculate(
          CompoundInterestInput(
            initialCapital: Decimal.fromInt(1000),
            contribution: Decimal.zero,
            contributionFrequency: ContributionFrequency.monthly,
            contributionTiming: ContributionTiming.end,
            rate: RateInput.fromPercent(
              percent: Decimal.fromInt(-100),
              kind: RateKind.effective,
              period: RatePeriod.monthly,
            ),
            termMonths: 12,
          ),
        ),
        throwsA(isA<DomainValidationException>()),
      );
      expect(
        () => CompoundInterestEngine.calculate(
          CompoundInterestInput(
            initialCapital: Decimal.fromInt(-10),
            contribution: Decimal.zero,
            contributionFrequency: ContributionFrequency.monthly,
            contributionTiming: ContributionTiming.end,
            rate: RateInput.fromPercent(
              percent: Decimal.one,
              kind: RateKind.effective,
              period: RatePeriod.monthly,
            ),
            termMonths: 12,
          ),
        ),
        throwsA(isA<DomainValidationException>()),
      );
    });

    test('Propriedade: aumentar taxa ou prazo nunca reduz VF (condições positivas)', () {
      for (final ratePct in [0, 1, 2, 5]) {
        final r1 = CompoundInterestEngine.calculate(
          CompoundInterestInput(
            initialCapital: Decimal.fromInt(1000),
            contribution: Decimal.fromInt(200),
            contributionFrequency: ContributionFrequency.monthly,
            contributionTiming: ContributionTiming.end,
            rate: RateInput.fromPercent(
              percent: Decimal.fromInt(ratePct),
              kind: RateKind.effective,
              period: RatePeriod.monthly,
            ),
            termMonths: 12,
          ),
        );
        final r2 = CompoundInterestEngine.calculate(
          CompoundInterestInput(
            initialCapital: Decimal.fromInt(1000),
            contribution: Decimal.fromInt(200),
            contributionFrequency: ContributionFrequency.monthly,
            contributionTiming: ContributionTiming.end,
            rate: RateInput.fromPercent(
              percent: Decimal.fromInt(ratePct + 1),
              kind: RateKind.effective,
              period: RatePeriod.monthly,
            ),
            termMonths: 12,
          ),
        );
        final rLonger = CompoundInterestEngine.calculate(
          CompoundInterestInput(
            initialCapital: Decimal.fromInt(1000),
            contribution: Decimal.fromInt(200),
            contributionFrequency: ContributionFrequency.monthly,
            contributionTiming: ContributionTiming.end,
            rate: RateInput.fromPercent(
              percent: Decimal.fromInt(ratePct),
              kind: RateKind.effective,
              period: RatePeriod.monthly,
            ),
            termMonths: 24,
          ),
        );
        expect(r2.finalValue >= r1.finalValue, isTrue);
        expect(rLonger.finalValue >= r1.finalValue, isTrue);
      }
    });

    test('Simulação cronológica com aportes irregulares funciona por data civil', () {
      final res = CompoundInterestEngine.calculate(
        CompoundInterestInput(
          initialCapital: Decimal.fromInt(1000),
          contribution: Decimal.zero,
          contributionFrequency: ContributionFrequency.irregular,
          contributionTiming: ContributionTiming.end,
          rate: RateInput.fromPercent(
            percent: Decimal.fromInt(12),
            kind: RateKind.effective,
            period: RatePeriod.annual,
          ),
          termMonths: 12,
          startDate: const CivilDate(2026, 1, 1),
          irregularContributions: [
            IrregularContribution(
              date: const CivilDate(2026, 7, 2),
              amount: Decimal.fromInt(500),
            ),
          ],
        ),
      );
      expect(res.totalPrincipal, Decimal.parse('1500.00'));
      expect(res.finalValue > Decimal.fromInt(1620), isTrue);
    });
  });

  group('Doc 02 - Dividendos (DIV)', () {
    test('DIV-001: Quantidade=100; provento=0,50 -> Provento do evento=50,00', () {
      final res = DividendsEngine.calculate(
        DividendsInput(
          quantity: Decimal.fromInt(100),
          unitPrice: Decimal.fromInt(20),
          dividendPerUnit: Decimal.parse('0.50'),
          frequency: DividendFrequency.quarterly,
        ),
      );
      expect(res.eventDividend, Decimal.parse('50.00'));
      expect(res.estimated12MonthsTotal, Decimal.parse('200.00'));
      expect(res.mathematicalMonthlyAverage, Decimal.parse('16.67'));
    });

    test('DIV-002: Meta=100; provento=2,50 mensal -> Quantidade necessária=40', () {
      final res = DividendsEngine.calculate(
        DividendsInput(
          quantity: Decimal.fromInt(10),
          unitPrice: Decimal.fromInt(50),
          dividendPerUnit: Decimal.parse('2.50'),
          frequency: DividendFrequency.monthly,
          desiredMonthlyIncome: Decimal.fromInt(100),
        ),
      );
      expect(res.requiredQuantity, Decimal.fromInt(40));
    });

    test('DIV-003: Provento por unidade=0 -> Não divide e informa impossibilidade', () {
      final res = DividendsEngine.calculate(
        DividendsInput(
          quantity: Decimal.fromInt(100),
          unitPrice: Decimal.fromInt(50),
          dividendPerUnit: Decimal.zero,
          frequency: DividendFrequency.monthly,
          desiredMonthlyIncome: Decimal.fromInt(1000),
        ),
      );
      expect(res.requiredQuantity, isNull);
      expect(res.targetWarning, isNotNull);
    });

    test(r'Protótipo PDF Página 4: 250 cotas, R$ 98,40, R$ 0,85 mensal, meta R$ 1.000 -> 1.177 cotas', () {
      final res = DividendsEngine.calculate(
        DividendsInput(
          quantity: Decimal.fromInt(250),
          unitPrice: Decimal.parse('98.40'),
          dividendPerUnit: Decimal.parse('0.85'),
          frequency: DividendFrequency.monthly,
          desiredMonthlyIncome: Decimal.fromInt(1000),
        ),
      );
      expect(res.eventDividend, Decimal.parse('212.50'));
      expect(res.estimated12MonthsTotal, Decimal.parse('2550.00'));
      expect(res.hypotheticalAnnualDyPercent, Decimal.parse('10.37'));
      expect(res.requiredQuantity, Decimal.fromInt(1177));
    });
  });

  group('Doc 02 - Reinvestimento (REI)', () {
    test('REI-001: Caixa=105; preço=50; modo inteiro -> Compra=2; caixa residual=5,00', () {
      final res = ReinvestmentEngine.calculate(
        ReinvestmentInput(
          initialQuantity: Decimal.zero,
          initialPrice: Decimal.fromInt(50),
          dividendPerUnit: Decimal.zero,
          frequency: DividendFrequency.monthly,
          reinvestmentMode: ReinvestmentMode.full,
          reinvestmentPercent: Decimal.fromInt(100),
          quantityMode: QuantityMode.integer,
          termMonths: 1,
          initialCash: Decimal.fromInt(105),
        ),
      );
      expect(res.totalBoughtQuantity, Decimal.fromInt(2));
      expect(res.finalResidualCash, Decimal.parse('5.00'));
    });

    test('REI-002: Caixa=105; preço=50; modo fracionário -> Compra=2,1; caixa residual=0,00', () {
      final res = ReinvestmentEngine.calculate(
        ReinvestmentInput(
          initialQuantity: Decimal.zero,
          initialPrice: Decimal.fromInt(50),
          dividendPerUnit: Decimal.zero,
          frequency: DividendFrequency.monthly,
          reinvestmentMode: ReinvestmentMode.full,
          reinvestmentPercent: Decimal.fromInt(100),
          quantityMode: QuantityMode.fractional,
          termMonths: 1,
          initialCash: Decimal.fromInt(105),
        ),
      );
      expect(res.totalBoughtQuantity, Decimal.parse('2.1'));
      expect(res.finalResidualCash, Decimal.parse('0.00'));
      expect(res.showFractionalWarning, isTrue);
    });
  });

  group('Doc 02 - Metas (Protótipo PDF Página 5)', () {
    test('Reserva de emergência: 30000 alvo, 12000 atual, 800/mês, 0,8%, 18 meses', () {
      final eval = GoalsEngine.evaluate(
        GoalInput(
          targetValue: Decimal.fromInt(30000),
          currentCapital: Decimal.fromInt(12000),
          periodicContribution: Decimal.fromInt(800),
          contributionFrequency: ContributionFrequency.monthly,
          contributionTiming: ContributionTiming.end,
          rate: RateInput.fromPercent(
            percent: Decimal.parse('0.8'),
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          termMonths: 18,
        ),
      );
      expect(eval.projectedValueAtTerm, Decimal.parse('29272.93'));
      expect(eval.differenceToTarget, Decimal.parse('727.07'));
      expect(eval.currentPercentage, Decimal.parse('40.0'));
      expect(eval.projectedPercentage, Decimal.parse('97.6'));
      expect(eval.requiredMonthlyContribution, Decimal.parse('837.72'));
      expect(eval.estimatedMonthsWithCurrentContribution, 19);
      expect(eval.monthsDeltaVsTerm, 1);
    });
  });

  group('Doc 02 - Inflação (INF), Retiradas (RET), Comparador e Aposentadoria', () {
    test('INF-001 & §15.4: Retorno nominal=10%; inflação=4% -> ~5,7692308%', () {
      final res = InflationEngine.calculate(
        InflationInput(
          nominalRate: RateInput.fromPercent(
            percent: Decimal.fromInt(10),
            kind: RateKind.effective,
            period: RatePeriod.annual,
          ),
          inflationRate: RateInput.fromPercent(
            percent: Decimal.fromInt(4),
            kind: RateKind.effective,
            period: RatePeriod.annual,
          ),
          horizonMonths: 12,
          nominalAmount: Decimal.fromInt(1000),
        ),
      );
      final pct = res.realAnnualRate.shift(2).round(scale: 7);
      expect(pct, Decimal.parse('5.7692308'));
    });

    test('RET-001: Capital=1000; taxa=0%; retirada=100 ao fim por 5 períodos -> Saldo=500,00', () {
      final res = WithdrawalEngine.calculate(
        WithdrawalInput(
          initialCapital: Decimal.fromInt(1000),
          rate: RateInput.fromPercent(
            percent: Decimal.zero,
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          withdrawalAmount: Decimal.fromInt(100),
          withdrawalFrequency: ContributionFrequency.monthly,
          withdrawalTiming: ContributionTiming.end,
          termMonths: 5,
        ),
      );
      expect(res.finalBalance, Decimal.parse('500.00'));
      expect(res.depletionPeriod, isNull);
    });

    test('Retiradas identificam insuficiência e nunca mostram saldo negativo', () {
      final res = WithdrawalEngine.calculate(
        WithdrawalInput(
          initialCapital: Decimal.fromInt(250),
          rate: RateInput.fromPercent(
            percent: Decimal.zero,
            kind: RateKind.effective,
            period: RatePeriod.monthly,
          ),
          withdrawalAmount: Decimal.fromInt(100),
          withdrawalFrequency: ContributionFrequency.monthly,
          withdrawalTiming: ContributionTiming.end,
          termMonths: 5,
        ),
      );
      expect(res.finalBalance, Decimal.zero);
      expect(res.depletionPeriod, 3);
      expect(res.totalWithdrawn, Decimal.parse('250.00'));
      expect(res.totalDeficit, Decimal.parse('250.00'));
      for (final p in res.series) {
        expect(p.endingBalance >= Decimal.zero, isTrue);
      }
    });

    test('Comparador valida 2 a 4 cenários e identifica vencedor', () {
      final cmp = ComparatorEngine.compare([
        ComparatorScenarioInput(
          name: 'Conservador',
          input: CompoundInterestInput(
            initialCapital: Decimal.fromInt(10000),
            contribution: Decimal.fromInt(500),
            contributionFrequency: ContributionFrequency.monthly,
            contributionTiming: ContributionTiming.end,
            rate: RateInput.fromPercent(
              percent: Decimal.parse('0.7'),
              kind: RateKind.effective,
              period: RatePeriod.monthly,
            ),
            termMonths: 36,
          ),
        ),
        ComparatorScenarioInput(
          name: 'Base',
          input: CompoundInterestInput(
            initialCapital: Decimal.fromInt(10000),
            contribution: Decimal.fromInt(500),
            contributionFrequency: ContributionFrequency.monthly,
            contributionTiming: ContributionTiming.end,
            rate: RateInput.fromPercent(
              percent: Decimal.parse('0.9'),
              kind: RateKind.effective,
              period: RatePeriod.monthly,
            ),
            termMonths: 36,
          ),
        ),
      ]);
      expect(cmp.bestScenarioIndex, 1);
      expect(cmp.spreadBetweenBestAndWorst > Decimal.zero, isTrue);
    });

    test('Aposentadoria calcula patrimônio real e renda sustentável', () {
      final ret = RetirementEngine.calculate(
        RetirementInput(
          currentAge: 35,
          targetAge: 65,
          withdrawalYears: 25,
          currentCapital: Decimal.fromInt(20000),
          monthlyContribution: Decimal.fromInt(1000),
          nominalRate: RateInput.fromPercent(
            percent: Decimal.fromInt(10),
            kind: RateKind.effective,
            period: RatePeriod.annual,
          ),
          inflationRate: RateInput.fromPercent(
            percent: Decimal.fromInt(4),
            kind: RateKind.effective,
            period: RatePeriod.annual,
          ),
          desiredMonthlyIncomeToday: Decimal.fromInt(5000),
        ),
      );
      expect(ret.accumulationMonths, 360);
      expect(ret.estimatedNominalCapital > ret.estimatedRealCapital, isTrue);
      expect(ret.projectedSustainableMonthlyRealIncome > Decimal.zero, isTrue);
      expect(ret.requiredMonthlyContribution, isNotNull);
    });
  });

  group('Formatadores e BackupValidator', () {
    test('Formatação pt-BR corresponde ao protótipo', () {
      expect(PtBrFormatters.money(Decimal.parse('56666.82')), 'R\$ 56.666,82');
      expect(PtBrFormatters.percent(Decimal.parse('10.37')), '10,37%');
      expect(PtBrFormatters.quantity(Decimal.fromInt(1177)), '1.177');
      expect(PtBrFormatters.parseUserDecimal('R\$ 10.000,50'), Decimal.parse('10000.50'));
      expect(PtBrFormatters.parseUserDecimal('0,9'), Decimal.parse('0.9'));
    });

    test('BackupValidator valida esquema, versão e bloqueia campos proibidos', () {
      final payload = BackupPayload(
        app: 'Meta Feita',
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 11, 8, 12, 0),
        simulations: const [],
        goals: const [],
        preferences: const PreferenceModel(),
      );
      final json = payload.toPrettyJson();
      final parsed = BackupValidator.parseAndValidate(json);
      expect(parsed.app, 'Meta Feita');

      expect(
        () => BackupValidator.parseAndValidate(
          '{"app":"Meta Feita","schemaVersion":1,"exportedAt":"2026-11-08T12:00:00Z","credits":99,"simulations":[],"goals":[]}',
        ),
        throwsA(isA<BackupValidationException>()),
      );
    });
  });
}
