import 'package:decimal/decimal.dart';

import '../models/rate_input.dart';
import '../models/simulation_models.dart';
import '../validation/input_validators.dart';
import 'decimal_math.dart';
import 'rate_converter.dart';

class WithdrawalEngine {
  static WithdrawalResult calculate(WithdrawalInput input) {
    final errors = <String, String>{};
    InputValidators.requireNonNegativeMoney(
      input.initialCapital,
      'initialCapital',
      'Capital inicial',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.withdrawalAmount,
      'withdrawalAmount',
      'Retirada',
      errors,
    );
    InputValidators.validateRate(input.rate, 'rate', errors);
    if (input.inflationRate != null) {
      InputValidators.validateRate(
        input.inflationRate!,
        'inflationRate',
        errors,
      );
    }
    InputValidators.validateTermMonths(input.termMonths, 'termMonths', errors);
    InputValidators.throwIfErrors(errors);

    final monthlyRate = RateConverter.toEffectiveMonthly(input.rate);
    final monthlyInflation = input.inflationRate != null
        ? RateConverter.toEffectiveMonthly(input.inflationRate!)
        : Decimal.zero;

    var balance = input.initialCapital;
    var totalWithdrawn = Decimal.zero;
    var totalDeficit = Decimal.zero;
    int? depletionPeriod;

    final series = <WithdrawalPeriodPoint>[];
    var inflationFactor = Decimal.one;

    for (var m = 1; m <= input.termMonths; m++) {
      if (m > 1 && monthlyInflation != Decimal.zero) {
        inflationFactor = DecimalMath.roundInternal(
          inflationFactor * (Decimal.one + monthlyInflation),
        );
      }

      final hasWithdrawal = _withdrawsInMonth(
        month: m,
        frequency: input.withdrawalFrequency,
        timing: input.withdrawalTiming,
      );
      final requested = hasWithdrawal
          ? DecimalMath.moneyRound(input.withdrawalAmount * inflationFactor)
          : Decimal.zero;

      var actual = Decimal.zero;
      var deficit = Decimal.zero;

      if (hasWithdrawal &&
          input.withdrawalTiming == ContributionTiming.beginning) {
        if (balance >= requested) {
          actual = requested;
          balance = DecimalMath.roundInternal(balance - requested);
        } else {
          actual = balance > Decimal.zero
              ? DecimalMath.moneyRound(balance)
              : Decimal.zero;
          deficit = DecimalMath.moneyRound(requested - actual);
          balance = Decimal.zero;
          depletionPeriod ??= m;
        }
      }

      final periodReturn =
          (balance > Decimal.zero && monthlyRate != Decimal.zero)
          ? DecimalMath.roundInternal(balance * monthlyRate)
          : Decimal.zero;
      balance = DecimalMath.roundInternal(balance + periodReturn);
      if (balance < Decimal.zero) {
        balance = Decimal.zero;
      }

      if (hasWithdrawal && input.withdrawalTiming == ContributionTiming.end) {
        if (balance >= requested) {
          actual = requested;
          balance = DecimalMath.roundInternal(balance - requested);
        } else {
          actual = balance > Decimal.zero
              ? DecimalMath.moneyRound(balance)
              : Decimal.zero;
          deficit = DecimalMath.moneyRound(requested - actual);
          balance = Decimal.zero;
          depletionPeriod ??= m;
        }
      }

      totalWithdrawn += actual;
      totalDeficit += deficit;

      series.add(
        WithdrawalPeriodPoint(
          periodIndex: m,
          requestedWithdrawal: requested,
          actualWithdrawal: DecimalMath.moneyRound(actual),
          deficit: DecimalMath.moneyRound(deficit),
          periodReturn: DecimalMath.moneyRound(periodReturn),
          endingBalance: DecimalMath.moneyRound(balance),
        ),
      );
    }

    return WithdrawalResult(
      finalBalance: DecimalMath.moneyRound(balance),
      totalWithdrawn: DecimalMath.moneyRound(totalWithdrawn),
      totalDeficit: DecimalMath.moneyRound(totalDeficit),
      depletionPeriod: depletionPeriod,
      series: series,
      assumptions: {
        'Capital inicial': input.initialCapital.toString(),
        'Taxa': input.rate.describePt(),
        'Retirada':
            '${input.withdrawalAmount} (${input.withdrawalFrequency.labelPt}, ${input.withdrawalTiming.shortPt})',
        'Correção por inflação': input.inflationRate != null
            ? input.inflationRate!.describePt()
            : 'Não aplicada',
        'Prazo': '${input.termMonths} meses',
      },
    );
  }

  static bool _withdrawsInMonth({
    required int month,
    required ContributionFrequency frequency,
    required ContributionTiming timing,
  }) {
    switch (frequency) {
      case ContributionFrequency.monthly:
        return true;
      case ContributionFrequency.quarterly:
        return timing == ContributionTiming.beginning
            ? (month - 1) % 3 == 0
            : month % 3 == 0;
      case ContributionFrequency.annual:
        return timing == ContributionTiming.beginning
            ? (month - 1) % 12 == 0
            : month % 12 == 0;
      case ContributionFrequency.weekly:
      case ContributionFrequency.irregular:
        return true;
    }
  }
}
