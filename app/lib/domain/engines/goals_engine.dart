import 'package:decimal/decimal.dart';

import '../models/goal_models.dart';
import '../models/rate_input.dart';
import '../models/simulation_models.dart';
import '../validation/input_validators.dart';
import 'compound_interest_engine.dart';
import 'decimal_math.dart';
import 'rate_converter.dart';

class GoalsEngine {
  static final Decimal tolerance = Decimal.parse('0.01');
  static const int maxSolverIterations = 80;

  static GoalEvaluation evaluate(GoalInput input) {
    final errors = <String, String>{};
    InputValidators.requirePositiveMoney(
      input.targetValue,
      'targetValue',
      'Valor-alvo',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.currentCapital,
      'currentCapital',
      'Capital atual',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.periodicContribution,
      'periodicContribution',
      'Aporte periódico',
      errors,
    );
    InputValidators.validateRate(input.rate, 'rate', errors);
    InputValidators.validateTermMonths(input.termMonths, 'termMonths', errors);
    InputValidators.throwIfErrors(errors);

    final projection = CompoundInterestEngine.calculate(
      CompoundInterestInput(
        initialCapital: input.currentCapital,
        contribution: input.periodicContribution,
        contributionFrequency: input.contributionFrequency,
        contributionTiming: input.contributionTiming,
        rate: input.rate,
        termMonths: input.termMonths,
      ),
    );

    final projected = projection.finalValue;
    final diff = DecimalMath.moneyRound(input.targetValue - projected);
    final currentPct = DecimalMath.roundInternal(
      DecimalMath.div(input.currentCapital, input.targetValue) *
          DecimalMath.hundred,
    ).round(scale: 1);
    final projectedPct = DecimalMath.roundInternal(
      DecimalMath.div(projected, input.targetValue) * DecimalMath.hundred,
    ).round(scale: 1);

    // 1. Busca numérica (busca binária) para encontrar aporte necessário no prazo
    Decimal? requiredContribution;
    String? solverNote;

    final zeroContribRes = CompoundInterestEngine.calculate(
      CompoundInterestInput(
        initialCapital: input.currentCapital,
        contribution: Decimal.zero,
        contributionFrequency: ContributionFrequency.monthly,
        contributionTiming: input.contributionTiming,
        rate: input.rate,
        termMonths: input.termMonths,
      ),
    );

    if (zeroContribRes.finalValue >= input.targetValue) {
      requiredContribution = Decimal.zero;
      solverNote =
          'Com a taxa e o capital atuais, você atinge a meta mesmo sem novos aportes.';
    } else {
      var low = Decimal.zero;
      var high = input.targetValue;
      var guard = 0;
      while (guard < 40) {
        final testHigh = CompoundInterestEngine.calculate(
          CompoundInterestInput(
            initialCapital: input.currentCapital,
            contribution: high,
            contributionFrequency: ContributionFrequency.monthly,
            contributionTiming: input.contributionTiming,
            rate: input.rate,
            termMonths: input.termMonths,
          ),
        ).finalValue;
        if (testHigh >= input.targetValue) break;
        high = high * DecimalMath.two;
        guard++;
      }

      for (var iter = 0; iter < maxSolverIterations; iter++) {
        final mid = DecimalMath.div(low + high, DecimalMath.two, scale: 8);
        final val = CompoundInterestEngine.calculate(
          CompoundInterestInput(
            initialCapital: input.currentCapital,
            contribution: mid,
            contributionFrequency: ContributionFrequency.monthly,
            contributionTiming: input.contributionTiming,
            rate: input.rate,
            termMonths: input.termMonths,
          ),
        ).finalValue;

        if ((val - input.targetValue).abs() <= Decimal.parse('0.001') ||
            (high - low) <= Decimal.parse('0.001')) {
          requiredContribution = DecimalMath.moneyRound(mid);
          break;
        }
        if (val < input.targetValue) {
          low = mid;
        } else {
          high = mid;
        }
      }
      requiredContribution ??= DecimalMath.moneyRound(
        DecimalMath.div(low + high, DecimalMath.two, scale: 8),
      );
    }

    // 2. Prazo estimado com o aporte informado
    int? estimatedMonths;
    int? monthsDelta;

    if (input.currentCapital >= input.targetValue) {
      estimatedMonths = 0;
      monthsDelta = -input.termMonths;
    } else {
      final monthlyRate = RateConverter.toEffectiveMonthly(input.rate);
      if (input.periodicContribution == Decimal.zero &&
          monthlyRate <= Decimal.zero) {
        estimatedMonths = null;
        solverNote =
            'Com aporte zero e taxa nula ou negativa, não é possível alcançar a meta.';
      } else {
        var bal = input.currentCapital;
        for (var m = 1; m <= InputValidators.maxTermMonths; m++) {
          final pmt = input.periodicContribution;
          if (pmt > Decimal.zero &&
              input.contributionTiming == ContributionTiming.beginning) {
            bal += pmt;
          }
          bal = DecimalMath.roundInternal(bal * (Decimal.one + monthlyRate));
          if (pmt > Decimal.zero &&
              input.contributionTiming == ContributionTiming.end) {
            bal += pmt;
          }
          if (DecimalMath.moneyRound(bal) >= input.targetValue) {
            estimatedMonths = m;
            monthsDelta = m - input.termMonths;
            break;
          }
        }
        if (estimatedMonths == null) {
          solverNote ??=
              'A meta ultrapassa ${InputValidators.maxTermMonths} meses com o aporte e a taxa informados.';
        }
      }
    }

    return GoalEvaluation(
      projectedValueAtTerm: projected,
      differenceToTarget: diff,
      currentPercentage: currentPct,
      projectedPercentage: projectedPct,
      requiredMonthlyContribution: requiredContribution,
      estimatedMonthsWithCurrentContribution: estimatedMonths,
      monthsDeltaVsTerm: monthsDelta,
      solverNote: solverNote,
      assumptions: {
        'Capital atual': input.currentCapital.toString(),
        'Aporte':
            '${input.periodicContribution} por mês, ${input.contributionTiming.shortPt}',
        'Taxa': input.rate.describePt(),
        'Solução': 'Busca numérica, tolerância R\$ 0,01',
      },
    );
  }
}
