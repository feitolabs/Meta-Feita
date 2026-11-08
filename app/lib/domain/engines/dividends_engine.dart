import 'package:decimal/decimal.dart';

import '../models/rate_input.dart';
import '../models/simulation_models.dart';
import '../validation/input_validators.dart';
import 'decimal_math.dart';

class DividendsEngine {
  static DividendsResult calculate(DividendsInput input) {
    final errors = <String, String>{};
    InputValidators.requireNonNegativeMoney(
      input.quantity,
      'quantity',
      'Quantidade',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.unitPrice,
      'unitPrice',
      'Preço por cota',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.dividendPerUnit,
      'dividendPerUnit',
      'Provento por cota',
      errors,
    );
    if (!input.fractionalMode && !input.quantity.isInteger) {
      errors['quantity'] = 'No modo inteiro, a quantidade deve ser um número inteiro.';
    }
    if (input.desiredMonthlyIncome != null &&
        input.desiredMonthlyIncome! < Decimal.zero) {
      errors['desiredMonthlyIncome'] = 'A renda desejada não pode ser negativa.';
    }
    InputValidators.throwIfErrors(errors);

    final growth = input.optionalAnnualGrowthRate ?? Decimal.zero;
    final eventDividend =
        DecimalMath.moneyRound(input.quantity * input.dividendPerUnit);

    final monthsNames = const [
      'Mês 1',
      'Mês 2',
      'Mês 3',
      'Mês 4',
      'Mês 5',
      'Mês 6',
      'Mês 7',
      'Mês 8',
      'Mês 9',
      'Mês 10',
      'Mês 11',
      'Mês 12',
    ];

    final calendar = <DividendMonthProjection>[];
    var annualPerUnit = Decimal.zero;
    var annualTotal = Decimal.zero;

    if (input.frequency == DividendFrequency.irregular) {
      final monthBuckets = List<Decimal>.filled(12, Decimal.zero);
      for (final evt in input.irregularEvents) {
        final bucket = (evt.date.month - 1).clamp(0, 11);
        monthBuckets[bucket] += evt.dividendPerUnit;
      }
      for (var m = 0; m < 12; m++) {
        final perUnit = monthBuckets[m];
        final totalMonth = DecimalMath.moneyRound(perUnit * input.quantity);
        annualPerUnit += perUnit;
        annualTotal += totalMonth;
        calendar.add(
          DividendMonthProjection(
            monthIndex: m + 1,
            label: monthsNames[m],
            hasPayment: perUnit > Decimal.zero,
            amount: totalMonth,
          ),
        );
      }
    } else {
      final step = switch (input.frequency) {
        DividendFrequency.monthly => 1,
        DividendFrequency.bimonthly => 2,
        DividendFrequency.quarterly => 3,
        DividendFrequency.semiannual => 6,
        DividendFrequency.annual => 12,
        DividendFrequency.irregular => 12,
      };
      for (var m = 1; m <= 12; m++) {
        final pays = (m - 1) % step == 0;
        final perUnit = pays ? input.dividendPerUnit : Decimal.zero;
        final totalMonth = pays ? eventDividend : Decimal.zero;
        annualPerUnit += perUnit;
        annualTotal += totalMonth;
        calendar.add(
          DividendMonthProjection(
            monthIndex: m,
            label: monthsNames[m - 1],
            hasPayment: pays,
            amount: totalMonth,
          ),
        );
      }
    }

    if (growth != Decimal.zero) {
      final factor = Decimal.one + growth;
      annualPerUnit = DecimalMath.roundInternal(annualPerUnit * factor);
      annualTotal = DecimalMath.moneyRound(annualTotal * factor);
    }

    final monthlyAvg = DecimalMath.moneyRound(
      DecimalMath.div(annualTotal, DecimalMath.twelve),
    );

    Decimal? dyPercent;
    if (input.unitPrice > Decimal.zero) {
      dyPercent = DecimalMath.roundInternal(
        DecimalMath.div(annualPerUnit, input.unitPrice) * DecimalMath.hundred,
      ).round(scale: 2);
    }

    Decimal? requiredQuantity;
    Decimal? estimatedCapital;
    String? targetWarning;

    if (input.desiredMonthlyIncome != null &&
        input.desiredMonthlyIncome! > Decimal.zero) {
      if (annualPerUnit <= Decimal.zero) {
        targetWarning =
            'Com provento de R\$ 0,00 por cota, a meta de renda não pode ser atingida com a premissa informada.';
      } else {
        final desiredAnnual = input.desiredMonthlyIncome! * DecimalMath.twelve;
        final rawQty = DecimalMath.div(desiredAnnual, annualPerUnit);
        requiredQuantity = input.fractionalMode
            ? rawQty.ceil(scale: 6)
            : rawQty.ceil();
        if (input.unitPrice > Decimal.zero) {
          estimatedCapital =
              DecimalMath.moneyRound(requiredQuantity * input.unitPrice);
        }
      }
    }

    return DividendsResult(
      eventDividend: eventDividend,
      estimated12MonthsTotal: DecimalMath.moneyRound(annualTotal),
      mathematicalMonthlyAverage: monthlyAvg,
      hypotheticalAnnualDyPercent: dyPercent,
      requiredQuantity: requiredQuantity,
      estimatedRequiredCapital: estimatedCapital,
      targetWarning: targetWarning,
      calendar12Months: calendar,
      assumptions: {
        'Frequência': input.frequency.labelPt,
        'Modo de cotas':
            input.fractionalMode ? 'Fracionário (hipotético)' : 'Inteiro',
        'Crescimento': growth == Decimal.zero
            ? '0% (sem crescimento presumido)'
            : '${growth.shift(2)}% ao ano',
        'Aviso':
            'Proventos são estimativas com suas premissas. Dividendos não são garantidos.',
      },
    );
  }
}

