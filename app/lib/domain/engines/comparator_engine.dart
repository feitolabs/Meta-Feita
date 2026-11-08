import '../models/simulation_models.dart';
import '../validation/input_validators.dart';
import 'compound_interest_engine.dart';
import 'decimal_math.dart';

class ComparatorEngine {
  static ComparatorResult compare(List<ComparatorScenarioInput> scenarios) {
    final errors = <String, String>{};
    if (scenarios.length < 2 || scenarios.length > 4) {
      errors['scenarios'] = 'Selecione entre 2 e 4 cenários para comparar.';
    }
    InputValidators.throwIfErrors(errors);

    final outputs = <ComparatorScenarioOutput>[];
    for (final s in scenarios) {
      final result = CompoundInterestEngine.calculate(s.input);
      outputs.add(
        ComparatorScenarioOutput(
          name: s.name,
          input: s.input,
          result: result,
        ),
      );
    }

    var bestIdx = 0;
    var worstVal = outputs.first.result.finalValue;
    var bestVal = outputs.first.result.finalValue;

    for (var i = 1; i < outputs.length; i++) {
      final val = outputs[i].result.finalValue;
      if (val > bestVal) {
        bestVal = val;
        bestIdx = i;
      }
      if (val < worstVal) {
        worstVal = val;
      }
    }

    return ComparatorResult(
      scenarios: outputs,
      bestScenarioIndex: bestIdx,
      spreadBetweenBestAndWorst: DecimalMath.moneyRound(bestVal - worstVal),
    );
  }
}
