import 'package:decimal/decimal.dart';

import 'civil_date.dart';
import 'rate_input.dart';

class GoalInput {
  final Decimal targetValue;
  final Decimal currentCapital;
  final Decimal periodicContribution;
  final ContributionFrequency contributionFrequency;
  final ContributionTiming contributionTiming;
  final RateInput rate;
  final int termMonths;

  const GoalInput({
    required this.targetValue,
    required this.currentCapital,
    required this.periodicContribution,
    required this.contributionFrequency,
    required this.contributionTiming,
    required this.rate,
    required this.termMonths,
  });

  Map<String, dynamic> toJson() => {
    'targetValue': targetValue.toString(),
    'currentCapital': currentCapital.toString(),
    'periodicContribution': periodicContribution.toString(),
    'contributionFrequency': contributionFrequency.name,
    'contributionTiming': contributionTiming.name,
    'rate': rate.toJson(),
    'termMonths': termMonths,
  };

  factory GoalInput.fromJson(Map<String, dynamic> json) {
    return GoalInput(
      targetValue: Decimal.parse(json['targetValue'] as String),
      currentCapital: Decimal.parse(json['currentCapital'] as String),
      periodicContribution: Decimal.parse(
        json['periodicContribution'] as String,
      ),
      contributionFrequency: ContributionFrequency.values.byName(
        json['contributionFrequency'] as String,
      ),
      contributionTiming: ContributionTiming.values.byName(
        json['contributionTiming'] as String,
      ),
      rate: RateInput.fromJson(json['rate'] as Map<String, dynamic>),
      termMonths: json['termMonths'] as int,
    );
  }
}

class GoalEvaluation {
  final Decimal projectedValueAtTerm;
  final Decimal differenceToTarget; // >0 falta para a meta; <=0 superávit
  final Decimal currentPercentage;
  final Decimal projectedPercentage;
  final Decimal? requiredMonthlyContribution;
  final int? estimatedMonthsWithCurrentContribution;
  final int? monthsDeltaVsTerm;
  final String? solverNote;
  final Map<String, String> assumptions;

  const GoalEvaluation({
    required this.projectedValueAtTerm,
    required this.differenceToTarget,
    required this.currentPercentage,
    required this.projectedPercentage,
    required this.requiredMonthlyContribution,
    required this.estimatedMonthsWithCurrentContribution,
    required this.monthsDeltaVsTerm,
    required this.solverNote,
    required this.assumptions,
  });
}

class SavedGoal {
  static const int currentSchemaVersion = 1;

  final String id;
  final String title;
  final GoalInput input;
  final CivilDate targetDate;
  final bool isFocus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const SavedGoal({
    required this.id,
    required this.title,
    required this.input,
    required this.targetDate,
    required this.isFocus,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  SavedGoal copyWith({
    String? title,
    GoalInput? input,
    CivilDate? targetDate,
    bool? isFocus,
    DateTime? updatedAt,
  }) {
    return SavedGoal(
      id: id,
      title: title ?? this.title,
      input: input ?? this.input,
      targetDate: targetDate ?? this.targetDate,
      isFocus: isFocus ?? this.isFocus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'targetValue': input.targetValue.toString(),
    'initialValue': input.currentCapital.toString(),
    'contribution': input.periodicContribution.toString(),
    'targetDate': targetDate.toIso(),
    'assumptions': input.toJson(),
    'isFocus': isFocus,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  factory SavedGoal.fromJson(Map<String, dynamic> json) {
    final assumptionsMap = Map<String, dynamic>.from(
      json['assumptions'] as Map,
    );
    return SavedGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      input: GoalInput.fromJson(assumptionsMap),
      targetDate:
          CivilDate.tryParse(json['targetDate'] as String) ?? CivilDate.today(),
      isFocus: json['isFocus'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
  }
}
