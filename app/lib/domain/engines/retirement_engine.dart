import 'package:decimal/decimal.dart';

import '../models/rate_input.dart';
import '../models/simulation_models.dart';
import '../validation/input_validators.dart';
import 'compound_interest_engine.dart';
import 'decimal_math.dart';
import 'inflation_engine.dart';
import 'rate_converter.dart';

class RetirementEngine {
  static RetirementResult calculate(RetirementInput input) {
    final errors = <String, String>{};
    if (input.currentAge < 0 || input.currentAge > 110) {
      errors['currentAge'] = 'Idade atual inválida.';
    }
    if (input.targetAge <= input.currentAge) {
      errors['targetAge'] = 'A idade-alvo deve ser maior que a idade atual.';
    } else if ((input.targetAge - input.currentAge) * 12 >
        InputValidators.maxTermMonths) {
      errors['targetAge'] =
          'Horizonte de acumulação excede o limite suportado.';
    }
    if (input.withdrawalYears <= 0 || input.withdrawalYears > 80) {
      errors['withdrawalYears'] =
          'Informe um período de usufruto entre 1 e 80 anos.';
    }
    InputValidators.requireNonNegativeMoney(
      input.currentCapital,
      'currentCapital',
      'Capital atual',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.monthlyContribution,
      'monthlyContribution',
      'Aporte mensal',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.desiredMonthlyIncomeToday,
      'desiredMonthlyIncomeToday',
      'Renda mensal desejada',
      errors,
    );
    InputValidators.validateRate(input.nominalRate, 'nominalRate', errors);
    InputValidators.validateRate(input.inflationRate, 'inflationRate', errors);
    InputValidators.throwIfErrors(errors);

    final accMonths = (input.targetAge - input.currentAge) * 12;
    final retMonths = input.withdrawalYears * 12;

    final accResult = CompoundInterestEngine.calculate(
      CompoundInterestInput(
        initialCapital: input.currentCapital,
        contribution: input.monthlyContribution,
        contributionFrequency: ContributionFrequency.monthly,
        contributionTiming: ContributionTiming.end,
        rate: input.nominalRate,
        termMonths: accMonths,
      ),
    );

    final infEval = InflationEngine.calculate(
      InflationInput(
        nominalRate: input.nominalRate,
        inflationRate: input.inflationRate,
        horizonMonths: accMonths,
        nominalAmount: accResult.finalValue,
      ),
    );

    final monthlyInflation = RateConverter.toEffectiveMonthly(
      input.inflationRate,
    );
    final cumInflationFactor = DecimalMath.powInt(
      Decimal.one + monthlyInflation,
      accMonths,
    );
    final realCapital = cumInflationFactor <= Decimal.zero
        ? Decimal.zero
        : DecimalMath.moneyRound(
            DecimalMath.div(accResult.finalValue, cumInflationFactor),
          );

    final realMonthly = infEval.realMonthlyRate;
    final sustainableIncome = _sustainableMonthlyWithdrawal(
      capital: realCapital,
      monthlyRate: realMonthly,
      months: retMonths,
    );

    final perpetualIncome = realMonthly > Decimal.zero
        ? DecimalMath.moneyRound(realCapital * realMonthly)
        : Decimal.zero;

    final requiredRealCorpus = _requiredCapitalForMonthlyWithdrawal(
      desiredIncome: input.desiredMonthlyIncomeToday,
      monthlyRate: realMonthly,
      months: retMonths,
    );

    final gap = DecimalMath.moneyRound(requiredRealCorpus - realCapital);
    final requiredNominalAtRetirement = DecimalMath.roundInternal(
      requiredRealCorpus * cumInflationFactor,
    );

    Decimal? requiredContribution;
    if (gap <= Decimal.zero) {
      requiredContribution = Decimal.zero;
    } else {
      final zeroPmt = CompoundInterestEngine.calculate(
        CompoundInterestInput(
          initialCapital: input.currentCapital,
          contribution: Decimal.zero,
          contributionFrequency: ContributionFrequency.monthly,
          contributionTiming: ContributionTiming.end,
          rate: input.nominalRate,
          termMonths: accMonths,
        ),
      ).finalValue;

      if (zeroPmt >= requiredNominalAtRetirement) {
        requiredContribution = Decimal.zero;
      } else {
        var low = Decimal.zero;
        var high = requiredNominalAtRetirement;
        for (var i = 0; i < 40; i++) {
          final vf = CompoundInterestEngine.calculate(
            CompoundInterestInput(
              initialCapital: input.currentCapital,
              contribution: high,
              contributionFrequency: ContributionFrequency.monthly,
              contributionTiming: ContributionTiming.end,
              rate: input.nominalRate,
              termMonths: accMonths,
            ),
          ).finalValue;
          if (vf >= requiredNominalAtRetirement) break;
          high = high * DecimalMath.two;
        }
        for (var i = 0; i < 65; i++) {
          final mid = DecimalMath.div(low + high, DecimalMath.two, scale: 6);
          final vf = CompoundInterestEngine.calculate(
            CompoundInterestInput(
              initialCapital: input.currentCapital,
              contribution: mid,
              contributionFrequency: ContributionFrequency.monthly,
              contributionTiming: ContributionTiming.end,
              rate: input.nominalRate,
              termMonths: accMonths,
            ),
          ).finalValue;
          if ((vf - requiredNominalAtRetirement).abs() <=
                  Decimal.parse('0.01') ||
              (high - low) <= Decimal.parse('0.001')) {
            requiredContribution = DecimalMath.moneyRound(mid);
            break;
          }
          if (vf < requiredNominalAtRetirement) {
            low = mid;
          } else {
            high = mid;
          }
        }
        requiredContribution ??= DecimalMath.moneyRound(
          DecimalMath.div(low + high, DecimalMath.two, scale: 6),
        );
      }
    }

    return RetirementResult(
      accumulationMonths: accMonths,
      estimatedNominalCapital: accResult.finalValue,
      estimatedRealCapital: realCapital,
      projectedSustainableMonthlyRealIncome: sustainableIncome,
      perpetualMonthlyRealIncome: perpetualIncome,
      requiredMonthlyContribution: requiredContribution,
      realCapitalGap: gap,
      realAnnualRate: infEval.realAnnualRate,
      accumulationSeries: accResult.series,
      assumptions: {
        'Horizonte de acumulação':
            '${input.currentAge} aos ${input.targetAge} anos ($accMonths meses)',
        'Horizonte de retiradas':
            '${input.withdrawalYears} anos ($retMonths meses)',
        'Retorno nominal': input.nominalRate.describePt(),
        'Inflação': input.inflationRate.describePt(),
        'Aviso':
            'Não é aconselhamento financeiro nem garantia de renda na aposentadoria.',
      },
    );
  }

  static Decimal _sustainableMonthlyWithdrawal({
    required Decimal capital,
    required Decimal monthlyRate,
    required int months,
  }) {
    if (capital <= Decimal.zero || months <= 0) return Decimal.zero;
    if (monthlyRate == Decimal.zero) {
      return DecimalMath.moneyRound(
        DecimalMath.div(capital, Decimal.fromInt(months)),
      );
    }
    final onePlus = Decimal.one + monthlyRate;
    final factor = DecimalMath.powInt(onePlus, months);
    final denom = factor - Decimal.one;
    if (denom <= Decimal.zero) {
      return DecimalMath.moneyRound(
        DecimalMath.div(capital, Decimal.fromInt(months)),
      );
    }
    final numerator = capital * monthlyRate * factor;
    return DecimalMath.moneyRound(DecimalMath.div(numerator, denom));
  }

  static Decimal _requiredCapitalForMonthlyWithdrawal({
    required Decimal desiredIncome,
    required Decimal monthlyRate,
    required int months,
  }) {
    if (desiredIncome <= Decimal.zero || months <= 0) return Decimal.zero;
    if (monthlyRate == Decimal.zero) {
      return DecimalMath.moneyRound(desiredIncome * Decimal.fromInt(months));
    }
    final onePlus = Decimal.one + monthlyRate;
    final factor = DecimalMath.powInt(onePlus, months);
    final numerator = desiredIncome * (factor - Decimal.one);
    final denom = monthlyRate * factor;
    return DecimalMath.moneyRound(DecimalMath.div(numerator, denom));
  }
}
