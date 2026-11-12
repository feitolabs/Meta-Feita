import 'package:decimal/decimal.dart';

import '../models/rate_input.dart';
import '../validation/input_validators.dart';
import 'decimal_math.dart';

class RateConverter {
  static Decimal toEffectiveMonthly(RateInput rate) {
    final errors = <String, String>{};
    InputValidators.validateRate(rate, 'rate', errors);
    InputValidators.throwIfErrors(errors);

    final onePlus = Decimal.one + rate.value;
    if (onePlus <= Decimal.zero) {
      throw const DomainValidationException({
        'rate': 'Taxa por período deve ser maior que -100%.',
      }, 'Taxa por período deve ser maior que -100%.');
    }

    switch (rate.period) {
      case RatePeriod.monthly:
        return rate.value;
      case RatePeriod.annual:
        if (rate.kind == RateKind.nominal) {
          // Nominal anual capitalizada mensalmente: j / 12
          final monthly = DecimalMath.div(rate.value, DecimalMath.twelve);
          if (monthly <= Decimal.fromInt(-1)) {
            throw const DomainValidationException({
              'rate': 'Taxa mensal equivalente deve ser maior que -100%.',
            }, 'Taxa mensal equivalente deve ser maior que -100%.');
          }
          return monthly;
        }
        // Efetiva anual: (1 + ia)^(1/12) - 1
        return DecimalMath.roundInternal(
          DecimalMath.nthRoot(onePlus, 12) - Decimal.one,
        );
      case RatePeriod.weekly:
        if (rate.kind == RateKind.nominal) {
          // Nominal semanal -> equivalente composta com 52 semanas/ano -> 12 meses
          final annual = DecimalMath.powInt(Decimal.one + rate.value, 52);
          return DecimalMath.roundInternal(
            DecimalMath.nthRoot(annual, 12) - Decimal.one,
          );
        }
        final annualFactor = DecimalMath.powInt(onePlus, 52);
        return DecimalMath.roundInternal(
          DecimalMath.nthRoot(annualFactor, 12) - Decimal.one,
        );
      case RatePeriod.daily:
        final annualFactor = DecimalMath.powInt(onePlus, 365);
        return DecimalMath.roundInternal(
          DecimalMath.nthRoot(annualFactor, 12) - Decimal.one,
        );
    }
  }

  static Decimal toEffectiveAnnual(RateInput rate) {
    final im = toEffectiveMonthly(rate);
    return DecimalMath.roundInternal(
      DecimalMath.powInt(Decimal.one + im, 12) - Decimal.one,
    );
  }
}
