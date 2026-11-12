import 'package:decimal/decimal.dart';

enum RateKind { effective, nominal }

enum RatePeriod { monthly, annual, weekly, daily }

enum ContributionFrequency { weekly, monthly, quarterly, annual, irregular }

enum ContributionTiming { beginning, end }

enum DividendFrequency {
  monthly,
  bimonthly,
  quarterly,
  semiannual,
  annual,
  irregular,
}

extension RateKindLabel on RateKind {
  String get labelPt => switch (this) {
    RateKind.effective => 'Efetiva',
    RateKind.nominal => 'Nominal',
  };
}

extension RatePeriodLabel on RatePeriod {
  String get suffixPt => switch (this) {
    RatePeriod.monthly => 'ao mês',
    RatePeriod.annual => 'ao ano',
    RatePeriod.weekly => 'por semana',
    RatePeriod.daily => 'ao dia',
  };
}

extension ContributionFrequencyLabel on ContributionFrequency {
  String get labelPt => switch (this) {
    ContributionFrequency.weekly => 'Semanal',
    ContributionFrequency.monthly => 'Mensal',
    ContributionFrequency.quarterly => 'Trimestral',
    ContributionFrequency.annual => 'Anual',
    ContributionFrequency.irregular => 'Irregular',
  };
}

extension ContributionTimingLabel on ContributionTiming {
  String get labelPt => switch (this) {
    ContributionTiming.beginning => 'No início do mês',
    ContributionTiming.end => 'No fim do mês',
  };

  String get shortPt => switch (this) {
    ContributionTiming.beginning => 'no início',
    ContributionTiming.end => 'no fim',
  };
}

extension DividendFrequencyLabel on DividendFrequency {
  String get labelPt => switch (this) {
    DividendFrequency.monthly => 'Mensal',
    DividendFrequency.bimonthly => 'Bimestral',
    DividendFrequency.quarterly => 'Trimestral',
    DividendFrequency.semiannual => 'Semestral',
    DividendFrequency.annual => 'Anual',
    DividendFrequency.irregular => 'Irregular',
  };

  int? get eventsPerYear => switch (this) {
    DividendFrequency.monthly => 12,
    DividendFrequency.bimonthly => 6,
    DividendFrequency.quarterly => 4,
    DividendFrequency.semiannual => 2,
    DividendFrequency.annual => 1,
    DividendFrequency.irregular => null,
  };
}

class RateInput {
  /// Fração decimal: 1% = 0.01, 0.9% = 0.009, 12% = 0.12.
  final Decimal value;
  final RateKind kind;
  final RatePeriod period;

  const RateInput({
    required this.value,
    required this.kind,
    required this.period,
  });

  factory RateInput.fromPercent({
    required Decimal percent,
    required RateKind kind,
    required RatePeriod period,
  }) {
    return RateInput(value: percent.shift(-2), kind: kind, period: period);
  }

  Decimal get asPercent => value.shift(2);

  String describePt() {
    final pct = asPercent;
    final formatted = pct.toString().replaceAll('.', ',');
    return '$formatted% ${period.suffixPt} (${kind.labelPt.toLowerCase()})';
  }

  Map<String, dynamic> toJson() => {
    'value': value.toString(),
    'kind': kind.name,
    'period': period.name,
  };

  factory RateInput.fromJson(Map<String, dynamic> json) {
    return RateInput(
      value: Decimal.parse(json['value'] as String),
      kind: RateKind.values.byName(json['kind'] as String),
      period: RatePeriod.values.byName(json['period'] as String),
    );
  }
}
