import 'package:decimal/decimal.dart';

import 'civil_date.dart';
import 'rate_input.dart';

enum SimulationType {
  compoundInterest,
  dividends,
  reinvestment,
  goal,
  comparator,
  inflation,
  withdrawal,
  retirement,
}

extension SimulationTypeLabel on SimulationType {
  String get eyebrowPt => switch (this) {
        SimulationType.compoundInterest => 'JUROS COMPOSTOS',
        SimulationType.dividends => 'DIVIDENDOS',
        SimulationType.reinvestment => 'REINVESTIMENTO',
        SimulationType.goal => 'META',
        SimulationType.comparator => 'COMPARADOR',
        SimulationType.inflation => 'INFLAÇÃO',
        SimulationType.withdrawal => 'RETIRADAS',
        SimulationType.retirement => 'APOSENTADORIA',
      };

  String get labelPt => switch (this) {
        SimulationType.compoundInterest => 'Juros compostos',
        SimulationType.dividends => 'Dividendos',
        SimulationType.reinvestment => 'Reinvestimento',
        SimulationType.goal => 'Meta',
        SimulationType.comparator => 'Comparador',
        SimulationType.inflation => 'Inflação',
        SimulationType.withdrawal => 'Retiradas',
        SimulationType.retirement => 'Aposentadoria',
      };
}

class SimulationSeriesPoint {
  final int periodIndex;
  final String dateOrPeriod;
  final Decimal balance;
  final Decimal totalInvested;
  final Decimal periodContribution;
  final Decimal periodReturn;
  final Decimal cumulativeReturn;
  final Decimal withdrawals;

  const SimulationSeriesPoint({
    required this.periodIndex,
    required this.dateOrPeriod,
    required this.balance,
    required this.totalInvested,
    required this.periodContribution,
    required this.periodReturn,
    required this.cumulativeReturn,
    required this.withdrawals,
  });

  Map<String, dynamic> toJson() => {
        'periodIndex': periodIndex,
        'dateOrPeriod': dateOrPeriod,
        'balance': balance.toString(),
        'totalInvested': totalInvested.toString(),
        'periodContribution': periodContribution.toString(),
        'periodReturn': periodReturn.toString(),
        'cumulativeReturn': cumulativeReturn.toString(),
        'withdrawals': withdrawals.toString(),
      };

  factory SimulationSeriesPoint.fromJson(Map<String, dynamic> json) {
    return SimulationSeriesPoint(
      periodIndex: json['periodIndex'] as int,
      dateOrPeriod: json['dateOrPeriod'] as String,
      balance: Decimal.parse(json['balance'] as String),
      totalInvested: Decimal.parse(json['totalInvested'] as String),
      periodContribution: Decimal.parse(json['periodContribution'] as String),
      periodReturn: Decimal.parse(json['periodReturn'] as String),
      cumulativeReturn: Decimal.parse(json['cumulativeReturn'] as String),
      withdrawals: Decimal.parse(json['withdrawals'] as String),
    );
  }
}

class IrregularContribution {
  final CivilDate date;
  final Decimal amount;

  const IrregularContribution({required this.date, required this.amount});

  Map<String, dynamic> toJson() => {
        'date': date.toIso(),
        'amount': amount.toString(),
      };

  factory IrregularContribution.fromJson(Map<String, dynamic> json) {
    return IrregularContribution(
      date: CivilDate.tryParse(json['date'] as String) ?? CivilDate.today(),
      amount: Decimal.parse(json['amount'] as String),
    );
  }
}

class CompoundInterestInput {
  final Decimal initialCapital;
  final Decimal contribution;
  final ContributionFrequency contributionFrequency;
  final ContributionTiming contributionTiming;
  final RateInput rate;
  final int termMonths;
  final CivilDate? startDate;
  final List<IrregularContribution> irregularContributions;

  const CompoundInterestInput({
    required this.initialCapital,
    required this.contribution,
    required this.contributionFrequency,
    required this.contributionTiming,
    required this.rate,
    required this.termMonths,
    this.startDate,
    this.irregularContributions = const [],
  });

  Map<String, dynamic> toJson() => {
        'initialCapital': initialCapital.toString(),
        'contribution': contribution.toString(),
        'contributionFrequency': contributionFrequency.name,
        'contributionTiming': contributionTiming.name,
        'rate': rate.toJson(),
        'termMonths': termMonths,
        if (startDate != null) 'startDate': startDate!.toIso(),
        'irregularContributions':
            irregularContributions.map((e) => e.toJson()).toList(),
      };

  factory CompoundInterestInput.fromJson(Map<String, dynamic> json) {
    return CompoundInterestInput(
      initialCapital: Decimal.parse(json['initialCapital'] as String),
      contribution: Decimal.parse(json['contribution'] as String),
      contributionFrequency: ContributionFrequency.values
          .byName(json['contributionFrequency'] as String),
      contributionTiming:
          ContributionTiming.values.byName(json['contributionTiming'] as String),
      rate: RateInput.fromJson(json['rate'] as Map<String, dynamic>),
      termMonths: json['termMonths'] as int,
      startDate: json['startDate'] != null
          ? CivilDate.tryParse(json['startDate'] as String)
          : null,
      irregularContributions:
          (json['irregularContributions'] as List<dynamic>? ?? [])
              .map((e) =>
                  IrregularContribution.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class CompoundInterestResult {
  final Decimal finalValue;
  final Decimal totalPrincipal;
  final Decimal totalReturn;
  final Decimal effectiveMonthlyRate;
  final Decimal effectiveAnnualRate;
  final List<SimulationSeriesPoint> series;
  final Map<String, String> assumptions;

  const CompoundInterestResult({
    required this.finalValue,
    required this.totalPrincipal,
    required this.totalReturn,
    required this.effectiveMonthlyRate,
    required this.effectiveAnnualRate,
    required this.series,
    required this.assumptions,
  });

  Map<String, dynamic> toJson() => {
        'finalValue': finalValue.toString(),
        'totalPrincipal': totalPrincipal.toString(),
        'totalReturn': totalReturn.toString(),
        'effectiveMonthlyRate': effectiveMonthlyRate.toString(),
        'effectiveAnnualRate': effectiveAnnualRate.toString(),
        'series': series.map((e) => e.toJson()).toList(),
        'assumptions': assumptions,
      };
}

class IrregularDividendEvent {
  final CivilDate date;
  final Decimal dividendPerUnit;

  const IrregularDividendEvent({
    required this.date,
    required this.dividendPerUnit,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso(),
        'dividendPerUnit': dividendPerUnit.toString(),
      };

  factory IrregularDividendEvent.fromJson(Map<String, dynamic> json) {
    return IrregularDividendEvent(
      date: CivilDate.tryParse(json['date'] as String) ?? CivilDate.today(),
      dividendPerUnit: Decimal.parse(json['dividendPerUnit'] as String),
    );
  }
}

class DividendsInput {
  final Decimal quantity;
  final Decimal unitPrice;
  final Decimal dividendPerUnit;
  final DividendFrequency frequency;
  final bool fractionalMode;
  final Decimal? desiredMonthlyIncome;
  final Decimal? optionalAnnualGrowthRate;
  final List<IrregularDividendEvent> irregularEvents;

  const DividendsInput({
    required this.quantity,
    required this.unitPrice,
    required this.dividendPerUnit,
    required this.frequency,
    this.fractionalMode = false,
    this.desiredMonthlyIncome,
    this.optionalAnnualGrowthRate,
    this.irregularEvents = const [],
  });

  Map<String, dynamic> toJson() => {
        'quantity': quantity.toString(),
        'unitPrice': unitPrice.toString(),
        'dividendPerUnit': dividendPerUnit.toString(),
        'frequency': frequency.name,
        'fractionalMode': fractionalMode,
        if (desiredMonthlyIncome != null)
          'desiredMonthlyIncome': desiredMonthlyIncome.toString(),
        if (optionalAnnualGrowthRate != null)
          'optionalAnnualGrowthRate': optionalAnnualGrowthRate.toString(),
        'irregularEvents': irregularEvents.map((e) => e.toJson()).toList(),
      };

  factory DividendsInput.fromJson(Map<String, dynamic> json) {
    return DividendsInput(
      quantity: Decimal.parse(json['quantity'] as String),
      unitPrice: Decimal.parse(json['unitPrice'] as String),
      dividendPerUnit: Decimal.parse(json['dividendPerUnit'] as String),
      frequency: DividendFrequency.values.byName(json['frequency'] as String),
      fractionalMode: json['fractionalMode'] as bool? ?? false,
      desiredMonthlyIncome: json['desiredMonthlyIncome'] != null
          ? Decimal.parse(json['desiredMonthlyIncome'] as String)
          : null,
      optionalAnnualGrowthRate: json['optionalAnnualGrowthRate'] != null
          ? Decimal.parse(json['optionalAnnualGrowthRate'] as String)
          : null,
      irregularEvents: (json['irregularEvents'] as List<dynamic>? ?? [])
          .map((e) => IrregularDividendEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DividendMonthProjection {
  final int monthIndex;
  final String label;
  final bool hasPayment;
  final Decimal amount;

  const DividendMonthProjection({
    required this.monthIndex,
    required this.label,
    required this.hasPayment,
    required this.amount,
  });
}

class DividendsResult {
  final Decimal eventDividend;
  final Decimal estimated12MonthsTotal;
  final Decimal mathematicalMonthlyAverage;
  final Decimal? hypotheticalAnnualDyPercent;
  final Decimal? requiredQuantity;
  final Decimal? estimatedRequiredCapital;
  final String? targetWarning;
  final List<DividendMonthProjection> calendar12Months;
  final Map<String, String> assumptions;

  const DividendsResult({
    required this.eventDividend,
    required this.estimated12MonthsTotal,
    required this.mathematicalMonthlyAverage,
    required this.hypotheticalAnnualDyPercent,
    required this.requiredQuantity,
    required this.estimatedRequiredCapital,
    required this.targetWarning,
    required this.calendar12Months,
    required this.assumptions,
  });
}

enum ReinvestmentMode { full, percentage, none }

enum QuantityMode { integer, fractional }

class ReinvestmentInput {
  final Decimal initialQuantity;
  final Decimal initialPrice;
  final Decimal dividendPerUnit;
  final DividendFrequency frequency;
  final ReinvestmentMode reinvestmentMode;
  final Decimal reinvestmentPercent; // 0..100 when percentage
  final QuantityMode quantityMode;
  final int fractionalScale;
  final int termMonths;
  final Decimal initialCash;
  final Decimal additionalMonthlyContribution;
  final Decimal explicitCostPerPurchase;
  final List<Decimal> customPriceSeries;

  ReinvestmentInput({
    required this.initialQuantity,
    required this.initialPrice,
    required this.dividendPerUnit,
    required this.frequency,
    required this.reinvestmentMode,
    required this.reinvestmentPercent,
    required this.quantityMode,
    this.fractionalScale = 6,
    required this.termMonths,
    Decimal? initialCash,
    Decimal? additionalMonthlyContribution,
    Decimal? explicitCostPerPurchase,
    this.customPriceSeries = const [],
  })  : initialCash = initialCash ?? Decimal.zero,
        additionalMonthlyContribution =
            additionalMonthlyContribution ?? Decimal.zero,
        explicitCostPerPurchase = explicitCostPerPurchase ?? Decimal.zero;
}

class ReinvestmentPeriodPoint {
  final int periodIndex;
  final Decimal priceUsed;
  final Decimal dividendsReceived;
  final Decimal cashBeforePurchase;
  final Decimal boughtQuantity;
  final Decimal endingQuantity;
  final Decimal residualCash;
  final Decimal totalCash;
  final Decimal estimatedPositionValue;

  const ReinvestmentPeriodPoint({
    required this.periodIndex,
    required this.priceUsed,
    required this.dividendsReceived,
    required this.cashBeforePurchase,
    required this.boughtQuantity,
    required this.endingQuantity,
    required this.residualCash,
    required this.totalCash,
    required this.estimatedPositionValue,
  });
}

class ReinvestmentResult {
  final Decimal finalQuantity;
  final Decimal totalBoughtQuantity;
  final Decimal totalDividendsReceived;
  final Decimal finalResidualCash;
  final Decimal finalEstimatedValue;
  final bool showFractionalWarning;
  final List<ReinvestmentPeriodPoint> series;
  final Map<String, String> assumptions;

  const ReinvestmentResult({
    required this.finalQuantity,
    required this.totalBoughtQuantity,
    required this.totalDividendsReceived,
    required this.finalResidualCash,
    required this.finalEstimatedValue,
    required this.showFractionalWarning,
    required this.series,
    required this.assumptions,
  });
}

class InflationInput {
  final RateInput nominalRate;
  final RateInput inflationRate;
  final int horizonMonths;
  final Decimal nominalAmount;
  final List<Decimal> variableMonthlyInflation;

  const InflationInput({
    required this.nominalRate,
    required this.inflationRate,
    required this.horizonMonths,
    required this.nominalAmount,
    this.variableMonthlyInflation = const [],
  });
}

class InflationPeriodPoint {
  final int month;
  final Decimal nominalValue;
  final Decimal realValue;

  const InflationPeriodPoint({
    required this.month,
    required this.nominalValue,
    required this.realValue,
  });
}

class InflationResult {
  final Decimal effectiveAnnualNominal;
  final Decimal effectiveAnnualInflation;
  final Decimal realAnnualRate;
  final Decimal realMonthlyRate;
  final Decimal projectedNominalValue;
  final Decimal projectedRealValue;
  final Decimal purchasingPowerLossPercent;
  final List<InflationPeriodPoint> series;
  final Map<String, String> assumptions;

  const InflationResult({
    required this.effectiveAnnualNominal,
    required this.effectiveAnnualInflation,
    required this.realAnnualRate,
    required this.realMonthlyRate,
    required this.projectedNominalValue,
    required this.projectedRealValue,
    required this.purchasingPowerLossPercent,
    required this.series,
    required this.assumptions,
  });
}

class WithdrawalInput {
  final Decimal initialCapital;
  final RateInput rate;
  final Decimal withdrawalAmount;
  final ContributionFrequency withdrawalFrequency;
  final ContributionTiming withdrawalTiming;
  final int termMonths;
  final RateInput? inflationRate;

  const WithdrawalInput({
    required this.initialCapital,
    required this.rate,
    required this.withdrawalAmount,
    required this.withdrawalFrequency,
    required this.withdrawalTiming,
    required this.termMonths,
    this.inflationRate,
  });
}

class WithdrawalPeriodPoint {
  final int periodIndex;
  final Decimal requestedWithdrawal;
  final Decimal actualWithdrawal;
  final Decimal deficit;
  final Decimal periodReturn;
  final Decimal endingBalance;

  const WithdrawalPeriodPoint({
    required this.periodIndex,
    required this.requestedWithdrawal,
    required this.actualWithdrawal,
    required this.deficit,
    required this.periodReturn,
    required this.endingBalance,
  });
}

class WithdrawalResult {
  final Decimal finalBalance;
  final Decimal totalWithdrawn;
  final Decimal totalDeficit;
  final int? depletionPeriod;
  final List<WithdrawalPeriodPoint> series;
  final Map<String, String> assumptions;

  const WithdrawalResult({
    required this.finalBalance,
    required this.totalWithdrawn,
    required this.totalDeficit,
    required this.depletionPeriod,
    required this.series,
    required this.assumptions,
  });
}

class RetirementInput {
  final int currentAge;
  final int targetAge;
  final int withdrawalYears;
  final Decimal currentCapital;
  final Decimal monthlyContribution;
  final RateInput nominalRate;
  final RateInput inflationRate;
  final Decimal desiredMonthlyIncomeToday;

  const RetirementInput({
    required this.currentAge,
    required this.targetAge,
    required this.withdrawalYears,
    required this.currentCapital,
    required this.monthlyContribution,
    required this.nominalRate,
    required this.inflationRate,
    required this.desiredMonthlyIncomeToday,
  });
}

class RetirementResult {
  final int accumulationMonths;
  final Decimal estimatedNominalCapital;
  final Decimal estimatedRealCapital;
  final Decimal projectedSustainableMonthlyRealIncome;
  final Decimal perpetualMonthlyRealIncome;
  final Decimal? requiredMonthlyContribution;
  final Decimal realCapitalGap;
  final Decimal realAnnualRate;
  final List<SimulationSeriesPoint> accumulationSeries;
  final Map<String, String> assumptions;

  const RetirementResult({
    required this.accumulationMonths,
    required this.estimatedNominalCapital,
    required this.estimatedRealCapital,
    required this.projectedSustainableMonthlyRealIncome,
    required this.perpetualMonthlyRealIncome,
    required this.requiredMonthlyContribution,
    required this.realCapitalGap,
    required this.realAnnualRate,
    required this.accumulationSeries,
    required this.assumptions,
  });
}

class ComparatorScenarioInput {
  final String name;
  final CompoundInterestInput input;

  const ComparatorScenarioInput({
    required this.name,
    required this.input,
  });
}

class ComparatorScenarioOutput {
  final String name;
  final CompoundInterestInput input;
  final CompoundInterestResult result;

  const ComparatorScenarioOutput({
    required this.name,
    required this.input,
    required this.result,
  });
}

class ComparatorResult {
  final List<ComparatorScenarioOutput> scenarios;
  final int bestScenarioIndex;
  final Decimal spreadBetweenBestAndWorst;

  const ComparatorResult({
    required this.scenarios,
    required this.bestScenarioIndex,
    required this.spreadBetweenBestAndWorst,
  });
}

class SavedSimulation {
  static const int currentSchemaVersion = 1;

  final String id;
  final String title;
  final SimulationType type;
  final String summaryLabel;
  final Map<String, dynamic> inputData;
  final Map<String, dynamic> resultData;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const SavedSimulation({
    required this.id,
    required this.title,
    required this.type,
    required this.summaryLabel,
    required this.inputData,
    required this.resultData,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  SavedSimulation copyWith({
    String? title,
    String? summaryLabel,
    Map<String, dynamic>? inputData,
    Map<String, dynamic>? resultData,
    DateTime? updatedAt,
  }) {
    return SavedSimulation(
      id: id,
      title: title ?? this.title,
      type: type,
      summaryLabel: summaryLabel ?? this.summaryLabel,
      inputData: inputData ?? this.inputData,
      resultData: resultData ?? this.resultData,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'summaryLabel': summaryLabel,
        'inputData': inputData,
        'resultData': resultData,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'schemaVersion': schemaVersion,
      };

  factory SavedSimulation.fromJson(Map<String, dynamic> json) {
    return SavedSimulation(
      id: json['id'] as String,
      title: json['title'] as String,
      type: SimulationType.values.byName(json['type'] as String),
      summaryLabel: json['summaryLabel'] as String? ?? '',
      inputData: Map<String, dynamic>.from(json['inputData'] as Map),
      resultData: Map<String, dynamic>.from(json['resultData'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
  }
}
