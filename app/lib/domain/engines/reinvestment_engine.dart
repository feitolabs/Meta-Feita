import 'package:decimal/decimal.dart';

import '../models/rate_input.dart';
import '../models/simulation_models.dart';
import '../validation/input_validators.dart';
import 'decimal_math.dart';

class ReinvestmentEngine {
  static ReinvestmentResult calculate(ReinvestmentInput input) {
    final errors = <String, String>{};
    InputValidators.requireNonNegativeMoney(
      input.initialQuantity,
      'initialQuantity',
      'Quantidade inicial',
      errors,
    );
    InputValidators.requirePositiveMoney(
      input.initialPrice,
      'initialPrice',
      'Preço por cota',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.dividendPerUnit,
      'dividendPerUnit',
      'Provento por cota',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.initialCash,
      'initialCash',
      'Caixa inicial',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.additionalMonthlyContribution,
      'additionalMonthlyContribution',
      'Aporte adicional',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.explicitCostPerPurchase,
      'explicitCostPerPurchase',
      'Custo por compra',
      errors,
    );
    if (input.reinvestmentMode == ReinvestmentMode.percentage &&
        (input.reinvestmentPercent < Decimal.zero ||
            input.reinvestmentPercent > DecimalMath.hundred)) {
      errors['reinvestmentPercent'] =
          'O percentual de reinvestimento deve estar entre 0% e 100%.';
    }
    InputValidators.validateTermMonths(input.termMonths, 'termMonths', errors);
    if (input.quantityMode == QuantityMode.integer &&
        !input.initialQuantity.isInteger) {
      errors['initialQuantity'] =
          'No modo inteiro, a quantidade inicial deve ser um número inteiro.';
    }
    InputValidators.throwIfErrors(errors);

    final fraction = switch (input.reinvestmentMode) {
      ReinvestmentMode.full => Decimal.one,
      ReinvestmentMode.none => Decimal.zero,
      ReinvestmentMode.percentage => DecimalMath.div(
        input.reinvestmentPercent,
        DecimalMath.hundred,
      ),
    };

    final paymentStep = switch (input.frequency) {
      DividendFrequency.monthly => 1,
      DividendFrequency.bimonthly => 2,
      DividendFrequency.quarterly => 3,
      DividendFrequency.semiannual => 6,
      DividendFrequency.annual => 12,
      DividendFrequency.irregular => 1,
    };

    var quantity = input.initialQuantity;
    var cash = input.initialCash;
    var totalBought = Decimal.zero;
    var totalDividends = Decimal.zero;
    var lastPrice = input.initialPrice;

    final series = <ReinvestmentPeriodPoint>[];

    for (var m = 1; m <= input.termMonths; m++) {
      final price =
          (m - 1) < input.customPriceSeries.length &&
              input.customPriceSeries[m - 1] > Decimal.zero
          ? input.customPriceSeries[m - 1]
          : input.initialPrice;
      lastPrice = price;

      final paysThisMonth = (m - 1) % paymentStep == 0;
      final dividend = paysThisMonth
          ? DecimalMath.moneyRound(quantity * input.dividendPerUnit)
          : Decimal.zero;

      totalDividends += dividend;
      cash = DecimalMath.moneyRound(
        cash + dividend + input.additionalMonthlyContribution,
      );

      final cashBeforePurchase = cash;
      final budget = DecimalMath.moneyRound(cash * fraction);
      final netBudget = budget > input.explicitCostPerPurchase
          ? budget - input.explicitCostPerPurchase
          : Decimal.zero;

      var bought = Decimal.zero;
      var spent = Decimal.zero;

      if (netBudget > Decimal.zero && fraction > Decimal.zero) {
        if (input.quantityMode == QuantityMode.integer) {
          final rawUnits = DecimalMath.div(netBudget, price).floor();
          if (rawUnits > Decimal.zero) {
            bought = rawUnits;
            spent =
                DecimalMath.moneyRound(bought * price) +
                input.explicitCostPerPurchase;
          }
        } else {
          final rawUnits = DecimalMath.div(
            netBudget,
            price,
          ).floor(scale: input.fractionalScale);
          if (rawUnits > Decimal.zero) {
            bought = rawUnits;
            spent =
                DecimalMath.moneyRound(bought * price) +
                input.explicitCostPerPurchase;
          }
        }
      }

      if (spent > cash) {
        spent = cash;
      }

      quantity += bought;
      totalBought += bought;
      cash = DecimalMath.moneyRound(cash - spent);

      final residualOfReinvest = DecimalMath.moneyRound(
        budget - spent < Decimal.zero ? Decimal.zero : budget - spent,
      );
      final estimatedPosition = DecimalMath.moneyRound(quantity * price + cash);

      series.add(
        ReinvestmentPeriodPoint(
          periodIndex: m,
          priceUsed: price,
          dividendsReceived: dividend,
          cashBeforePurchase: cashBeforePurchase,
          boughtQuantity: bought,
          endingQuantity: quantity,
          residualCash: fraction == Decimal.one ? cash : residualOfReinvest,
          totalCash: cash,
          estimatedPositionValue: estimatedPosition,
        ),
      );
    }

    final finalResidual = series.isEmpty ? cash : series.last.totalCash;
    final finalPos = DecimalMath.moneyRound(quantity * lastPrice + cash);

    return ReinvestmentResult(
      finalQuantity: quantity,
      totalBoughtQuantity: totalBought,
      totalDividendsReceived: DecimalMath.moneyRound(totalDividends),
      finalResidualCash: finalResidual,
      finalEstimatedValue: finalPos,
      showFractionalWarning: input.quantityMode == QuantityMode.fractional,
      series: series,
      assumptions: {
        'Modo de quantidade': input.quantityMode == QuantityMode.integer
            ? 'Cotas inteiras (piso da divisão)'
            : 'Cotas fracionárias (até ${input.fractionalScale} casas)',
        'Regra de reinvestimento': switch (input.reinvestmentMode) {
          ReinvestmentMode.full => 'Integral (100%)',
          ReinvestmentMode.percentage =>
            'Parcial (${input.reinvestmentPercent}%)',
          ReinvestmentMode.none => 'Nenhum (0%)',
        },
        'Custos explícitos': '${input.explicitCostPerPurchase} por evento',
        'Aviso':
            'Simulação hipotética; não representa execução real de ordens.',
      },
    );
  }
}
