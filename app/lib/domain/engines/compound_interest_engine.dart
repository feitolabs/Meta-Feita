import 'package:decimal/decimal.dart';

import '../models/civil_date.dart';
import '../models/rate_input.dart';
import '../models/simulation_models.dart';
import '../validation/input_validators.dart';
import 'decimal_math.dart';
import 'rate_converter.dart';

class CompoundInterestEngine {
  static CompoundInterestResult calculate(
    CompoundInterestInput input, {
    bool allowZeroTerm = false,
  }) {
    final errors = <String, String>{};
    InputValidators.requireNonNegativeMoney(
      input.initialCapital,
      'initialCapital',
      'Capital inicial',
      errors,
    );
    InputValidators.requireNonNegativeMoney(
      input.contribution,
      'contribution',
      'Aporte',
      errors,
    );
    InputValidators.validateRate(input.rate, 'rate', errors);
    InputValidators.validateTermMonths(
      input.termMonths,
      'termMonths',
      errors,
      allowZero: allowZeroTerm,
    );

    final startDate = input.startDate ?? CivilDate.today();
    final endDate = startDate.addMonths(input.termMonths);
    for (var idx = 0; idx < input.irregularContributions.length; idx++) {
      final item = input.irregularContributions[idx];
      if (item.amount < Decimal.zero) {
        errors['irregularContributions'] =
            'Aportes extras não podem ser negativos.';
      }
      if (item.date.compareTo(startDate) < 0 ||
          item.date.compareTo(endDate) > 0) {
        errors['irregularContributions'] =
            'As datas dos aportes irregulares devem estar dentro do prazo simulado.';
      }
    }
    InputValidators.throwIfErrors(errors);

    final effectiveMonthlyRate = RateConverter.toEffectiveMonthly(input.rate);
    final effectiveAnnualRate = RateConverter.toEffectiveAnnual(input.rate);

    if (input.termMonths == 0) {
      final pvRounded = DecimalMath.moneyRound(input.initialCapital);
      return CompoundInterestResult(
        finalValue: pvRounded,
        totalPrincipal: pvRounded,
        totalReturn: Decimal.zero,
        effectiveMonthlyRate: effectiveMonthlyRate,
        effectiveAnnualRate: effectiveAnnualRate,
        series: [
          SimulationSeriesPoint(
            periodIndex: 0,
            dateOrPeriod: 'Mês 0',
            balance: pvRounded,
            totalInvested: pvRounded,
            periodContribution: Decimal.zero,
            periodReturn: Decimal.zero,
            cumulativeReturn: Decimal.zero,
            withdrawals: Decimal.zero,
          ),
        ],
        assumptions: _buildAssumptions(
          input,
          effectiveMonthlyRate,
          effectiveAnnualRate,
        ),
      );
    }

    // Frequência semanal ou aportes irregulares puros usam simulação cronológica em calendário civil.
    if (input.contributionFrequency == ContributionFrequency.weekly ||
        input.contributionFrequency == ContributionFrequency.irregular ||
        input.irregularContributions.isNotEmpty) {
      return _simulateChronologicalCalendar(
        input,
        startDate,
        effectiveMonthlyRate,
        effectiveAnnualRate,
      );
    }

    // Simulação discreta mensal ordenada (cobre mensal, trimestral, anual e taxa anual convertida por equivalência)
    var balance = input.initialCapital;
    var totalInvested = input.initialCapital;
    var cumulativeReturn = Decimal.zero;

    final series = <SimulationSeriesPoint>[
      SimulationSeriesPoint(
        periodIndex: 0,
        dateOrPeriod: 'Mês 0',
        balance: DecimalMath.moneyRound(balance),
        totalInvested: DecimalMath.moneyRound(totalInvested),
        periodContribution: Decimal.zero,
        periodReturn: Decimal.zero,
        cumulativeReturn: Decimal.zero,
        withdrawals: Decimal.zero,
      ),
    ];

    for (var month = 1; month <= input.termMonths; month++) {
      final pmt = _periodicContributionForMonth(
        month: month,
        frequency: input.contributionFrequency,
        amount: input.contribution,
        timing: input.contributionTiming,
      );

      if (pmt > Decimal.zero &&
          input.contributionTiming == ContributionTiming.beginning) {
        balance += pmt;
        totalInvested += pmt;
      }

      final periodReturn = effectiveMonthlyRate == Decimal.zero
          ? Decimal.zero
          : DecimalMath.roundInternal(balance * effectiveMonthlyRate);
      balance = DecimalMath.roundInternal(balance + periodReturn);
      cumulativeReturn = DecimalMath.roundInternal(
        cumulativeReturn + periodReturn,
      );

      if (pmt > Decimal.zero &&
          input.contributionTiming == ContributionTiming.end) {
        balance += pmt;
        totalInvested += pmt;
      }

      series.add(
        SimulationSeriesPoint(
          periodIndex: month,
          dateOrPeriod: 'Mês $month',
          balance: DecimalMath.moneyRound(balance),
          totalInvested: DecimalMath.moneyRound(totalInvested),
          periodContribution: DecimalMath.moneyRound(pmt),
          periodReturn: DecimalMath.moneyRound(periodReturn),
          cumulativeReturn: DecimalMath.moneyRound(cumulativeReturn),
          withdrawals: Decimal.zero,
        ),
      );
    }

    final finalRounded = DecimalMath.moneyRound(balance);
    final investedRounded = DecimalMath.moneyRound(totalInvested);
    final returnRounded = DecimalMath.moneyRound(balance - totalInvested);

    return CompoundInterestResult(
      finalValue: finalRounded,
      totalPrincipal: investedRounded,
      totalReturn: returnRounded,
      effectiveMonthlyRate: effectiveMonthlyRate,
      effectiveAnnualRate: effectiveAnnualRate,
      series: series,
      assumptions: _buildAssumptions(
        input,
        effectiveMonthlyRate,
        effectiveAnnualRate,
      ),
    );
  }

  static Decimal _periodicContributionForMonth({
    required int month,
    required ContributionFrequency frequency,
    required Decimal amount,
    required ContributionTiming timing,
  }) {
    if (amount <= Decimal.zero) return Decimal.zero;
    switch (frequency) {
      case ContributionFrequency.monthly:
        return amount;
      case ContributionFrequency.quarterly:
        if (timing == ContributionTiming.beginning) {
          return (month - 1) % 3 == 0 ? amount : Decimal.zero;
        }
        return month % 3 == 0 ? amount : Decimal.zero;
      case ContributionFrequency.annual:
        if (timing == ContributionTiming.beginning) {
          return (month - 1) % 12 == 0 ? amount : Decimal.zero;
        }
        return month % 12 == 0 ? amount : Decimal.zero;
      case ContributionFrequency.weekly:
      case ContributionFrequency.irregular:
        return Decimal.zero;
    }
  }

  static CompoundInterestResult _simulateChronologicalCalendar(
    CompoundInterestInput input,
    CivilDate startDate,
    Decimal effectiveMonthlyRate,
    Decimal effectiveAnnualRate,
  ) {
    final endDate = startDate.addMonths(input.termMonths);
    final dailyRate = DecimalMath.roundInternal(
      DecimalMath.nthRoot(Decimal.one + effectiveAnnualRate, 365) - Decimal.one,
    );

    // Mapeia aportes por data civil dentro do intervalo
    final eventsByDate = <CivilDate, Decimal>{};

    void addEvent(CivilDate d, Decimal amount) {
      if (amount <= Decimal.zero) return;
      eventsByDate[d] = (eventsByDate[d] ?? Decimal.zero) + amount;
    }

    if (input.contribution > Decimal.zero) {
      if (input.contributionFrequency == ContributionFrequency.weekly) {
        var cursor = input.contributionTiming == ContributionTiming.beginning
            ? startDate
            : startDate.addDays(7);
        while (cursor.compareTo(endDate) <= 0) {
          if (!(input.contributionTiming == ContributionTiming.beginning &&
              cursor == endDate)) {
            addEvent(cursor, input.contribution);
          }
          cursor = cursor.addDays(7);
        }
      } else if (input.contributionFrequency !=
          ContributionFrequency.irregular) {
        for (var m = 1; m <= input.termMonths; m++) {
          final pmt = _periodicContributionForMonth(
            month: m,
            frequency: input.contributionFrequency,
            amount: input.contribution,
            timing: input.contributionTiming,
          );
          if (pmt > Decimal.zero) {
            final d = input.contributionTiming == ContributionTiming.beginning
                ? startDate.addMonths(m - 1)
                : startDate.addMonths(m);
            addEvent(d, pmt);
          }
        }
      }
    }

    for (final irr in input.irregularContributions) {
      addEvent(irr.date, irr.amount);
    }

    var balance = input.initialCapital;
    var totalInvested = input.initialCapital;
    var cumulativeReturn = Decimal.zero;

    final series = <SimulationSeriesPoint>[
      SimulationSeriesPoint(
        periodIndex: 0,
        dateOrPeriod: startDate.formatPtBr(),
        balance: DecimalMath.moneyRound(balance),
        totalInvested: DecimalMath.moneyRound(totalInvested),
        periodContribution: Decimal.zero,
        periodReturn: Decimal.zero,
        cumulativeReturn: Decimal.zero,
        withdrawals: Decimal.zero,
      ),
    ];

    var prevCheckpoint = startDate;
    for (var m = 1; m <= input.termMonths; m++) {
      final nextCheckpoint = startDate.addMonths(m);
      var monthContrib = Decimal.zero;
      var monthReturn = Decimal.zero;

      // Ordena eventos neste intervalo [prevCheckpoint, nextCheckpoint]
      final intervalDates =
          eventsByDate.keys
              .where(
                (d) =>
                    (m == 1
                        ? d.compareTo(prevCheckpoint) >= 0
                        : d.compareTo(prevCheckpoint) > 0) &&
                    d.compareTo(nextCheckpoint) <= 0,
              )
              .toList()
            ..sort();

      var cursor = prevCheckpoint;
      for (final d in intervalDates) {
        final days = cursor.daysBetween(d);
        if (days > 0 && dailyRate != Decimal.zero) {
          final factor = DecimalMath.powInt(Decimal.one + dailyRate, days);
          final ret = DecimalMath.roundInternal(
            balance * (factor - Decimal.one),
          );
          balance = DecimalMath.roundInternal(balance + ret);
          monthReturn += ret;
          cumulativeReturn = DecimalMath.roundInternal(cumulativeReturn + ret);
        }
        final amt = eventsByDate[d] ?? Decimal.zero;
        balance += amt;
        totalInvested += amt;
        monthContrib += amt;
        cursor = d;
      }

      final remainingDays = cursor.daysBetween(nextCheckpoint);
      if (remainingDays > 0 && dailyRate != Decimal.zero) {
        final factor = DecimalMath.powInt(
          Decimal.one + dailyRate,
          remainingDays,
        );
        final ret = DecimalMath.roundInternal(balance * (factor - Decimal.one));
        balance = DecimalMath.roundInternal(balance + ret);
        monthReturn += ret;
        cumulativeReturn = DecimalMath.roundInternal(cumulativeReturn + ret);
      }

      series.add(
        SimulationSeriesPoint(
          periodIndex: m,
          dateOrPeriod: nextCheckpoint.formatPtBr(),
          balance: DecimalMath.moneyRound(balance),
          totalInvested: DecimalMath.moneyRound(totalInvested),
          periodContribution: DecimalMath.moneyRound(monthContrib),
          periodReturn: DecimalMath.moneyRound(monthReturn),
          cumulativeReturn: DecimalMath.moneyRound(cumulativeReturn),
          withdrawals: Decimal.zero,
        ),
      );
      prevCheckpoint = nextCheckpoint;
    }

    return CompoundInterestResult(
      finalValue: DecimalMath.moneyRound(balance),
      totalPrincipal: DecimalMath.moneyRound(totalInvested),
      totalReturn: DecimalMath.moneyRound(balance - totalInvested),
      effectiveMonthlyRate: effectiveMonthlyRate,
      effectiveAnnualRate: effectiveAnnualRate,
      series: series,
      assumptions: {
        ..._buildAssumptions(input, effectiveMonthlyRate, effectiveAnnualRate),
        'Calendário':
            'Simulação cronológica em datas civis (base 365 dias/ano)',
      },
    );
  }

  static Map<String, String> _buildAssumptions(
    CompoundInterestInput input,
    Decimal effectiveMonthlyRate,
    Decimal effectiveAnnualRate,
  ) {
    final orderDesc = input.contributionTiming == ContributionTiming.beginning
        ? 'Aporte no início, depois rendimento'
        : 'Rendimento, depois aporte';
    return {
      'Capital inicial': input.initialCapital.toString(),
      'Aporte':
          '${input.contribution} (${input.contributionFrequency.labelPt}, ${input.contributionTiming.shortPt})',
      'Taxa informada': input.rate.describePt(),
      'Taxa mensal equivalente':
          '${DecimalMath.roundInternal(effectiveMonthlyRate.shift(2)).round(scale: 4)}% ao mês',
      'Taxa anual efetiva':
          '${DecimalMath.roundInternal(effectiveAnnualRate.shift(2)).round(scale: 4)}% ao ano',
      'Prazo': '${input.termMonths} meses',
      'Ordem': orderDesc,
    };
  }
}
