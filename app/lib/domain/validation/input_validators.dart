import 'package:decimal/decimal.dart';

import '../models/civil_date.dart';
import '../models/rate_input.dart';

class DomainValidationException implements Exception {
  final Map<String, String> fieldErrors;
  final String message;

  const DomainValidationException(this.fieldErrors, this.message);

  @override
  String toString() => message;
}

class InputValidators {
  static final Decimal maxMoney = Decimal.parse('1000000000000'); // 1 trilhão
  static final Decimal maxQuantity = Decimal.parse('1000000000');
  static const int maxTermMonths = 1200; // 100 anos

  static void requireNonNegativeMoney(
    Decimal value,
    String fieldKey,
    String label,
    Map<String, String> errors,
  ) {
    if (value < Decimal.zero) {
      errors[fieldKey] = '$label não pode ser negativo.';
    } else if (value > maxMoney) {
      errors[fieldKey] = '$label excede o limite máximo suportado.';
    }
  }

  static void requirePositiveMoney(
    Decimal value,
    String fieldKey,
    String label,
    Map<String, String> errors,
  ) {
    requireNonNegativeMoney(value, fieldKey, label, errors);
    if (!errors.containsKey(fieldKey) && value <= Decimal.zero) {
      errors[fieldKey] = '$label deve ser maior que zero.';
    }
  }

  static void validateRate(
    RateInput rate,
    String fieldKey,
    Map<String, String> errors, {
    Decimal? maxPercentPerPeriod,
  }) {
    if (rate.value <= Decimal.fromInt(-1)) {
      errors[fieldKey] = 'A taxa por período deve ser maior que -100%.';
      return;
    }
    final maxPct = maxPercentPerPeriod ?? Decimal.fromInt(10000);
    if (rate.asPercent > maxPct) {
      errors[fieldKey] = 'A taxa informada excede o limite máximo permitido.';
    }
  }

  static void validateTermMonths(
    int months,
    String fieldKey,
    Map<String, String> errors, {
    bool allowZero = false,
  }) {
    if (months < 0 || (!allowZero && months == 0)) {
      errors[fieldKey] = allowZero
          ? 'O prazo não pode ser negativo.'
          : 'Informe um prazo maior que zero.';
    } else if (months > maxTermMonths) {
      errors[fieldKey] =
          'O prazo máximo permitido é de $maxTermMonths meses (100 anos).';
    }
  }

  static void validateDateRange(
    CivilDate start,
    CivilDate end,
    String fieldKey,
    Map<String, String> errors,
  ) {
    if (end.compareTo(start) < 0) {
      errors[fieldKey] = 'A data final não pode ser anterior à data inicial.';
    }
  }

  static void throwIfErrors(Map<String, String> errors) {
    if (errors.isNotEmpty) {
      throw DomainValidationException(errors, errors.values.first);
    }
  }
}
