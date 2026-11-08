import 'package:decimal/decimal.dart';

import '../models/simulation_models.dart';
import '../validation/input_validators.dart';
import 'decimal_math.dart';
import 'rate_converter.dart';

class InflationEngine {
  static InflationResult calculate(InflationInput input) {
    final errors = <String, String>{};
    InputValidators.validateRate(input.nominalRate, 'nominalRate', errors);
    InputValidators.validateRate(input.inflationRate, 'inflationRate', errors);
    InputValidators.validateTermMonths(
      input.horizonMonths,
      'horizonMonths',
      errors,
      allowZero: true,
    );
    InputValidators.requireNonNegativeMoney(
      input.nominalAmount,
      'nominalAmount',
      'Valor nominal',
      errors,
    );
    InputValidators.throwIfErrors(errors);

    final nomAnnual = RateConverter.toEffectiveAnnual(input.nominalRate);
    final infAnnual = RateConverter.toEffectiveAnnual(input.inflationRate);
    final nomMonthly = RateConverter.toEffectiveMonthly(input.nominalRate);
    final infMonthly = RateConverter.toEffectiveMonthly(input.inflationRate);

    // Fórmula de Fisher: ((1 + retorno_nominal) / (1 + inflacao)) - 1
    final realAnnual = DecimalMath.roundInternal(
      DecimalMath.div(Decimal.one + nomAnnual, Decimal.one + infAnnual) -
          Decimal.one,
    );
    final realMonthly = DecimalMath.roundInternal(
      DecimalMath.div(Decimal.one + nomMonthly, Decimal.one + infMonthly) -
          Decimal.one,
    );

    var nomVal = input.nominalAmount;
    var infFactorCum = Decimal.one;

    final series = <InflationPeriodPoint>[
      InflationPeriodPoint(
        month: 0,
        nominalValue: DecimalMath.moneyRound(nomVal),
        realValue: DecimalMath.moneyRound(nomVal),
      ),
    ];

    for (var m = 1; m <= input.horizonMonths; m++) {
      nomVal = DecimalMath.roundInternal(nomVal * (Decimal.one + nomMonthly));
      final monthInf = (m - 1) < input.variableMonthlyInflation.length
          ? input.variableMonthlyInflation[m - 1]
          : infMonthly;
      infFactorCum =
          DecimalMath.roundInternal(infFactorCum * (Decimal.one + monthInf));
      final realVal = infFactorCum <= Decimal.zero
          ? Decimal.zero
          : DecimalMath.div(nomVal, infFactorCum);

      series.add(
        InflationPeriodPoint(
          month: m,
          nominalValue: DecimalMath.moneyRound(nomVal),
          realValue: DecimalMath.moneyRound(realVal),
        ),
      );
    }

    final finalNominal = series.last.nominalValue;
    final finalReal = series.last.realValue;
    final lossPct = finalNominal > Decimal.zero
        ? DecimalMath.roundInternal(
            (Decimal.one - DecimalMath.div(finalReal, finalNominal)) *
                DecimalMath.hundred,
          ).round(scale: 2)
        : Decimal.zero;

    return InflationResult(
      effectiveAnnualNominal: nomAnnual,
      effectiveAnnualInflation: infAnnual,
      realAnnualRate: realAnnual,
      realMonthlyRate: realMonthly,
      projectedNominalValue: finalNominal,
      projectedRealValue: finalReal,
      purchasingPowerLossPercent: lossPct,
      series: series,
      assumptions: {
        'Retorno nominal': input.nominalRate.describePt(),
        'Inflação': input.inflationRate.describePt(),
        'Horizonte': '${input.horizonMonths} meses',
        'Fórmula': 'Retorno real = ((1 + nominal) / (1 + inflação)) - 1',
      },
    );
  }
}
