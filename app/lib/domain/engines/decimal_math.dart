import 'dart:math' as math;

import 'package:decimal/decimal.dart';

class DecimalMath {
  static const int internalScale = 20;
  static final Decimal hundred = Decimal.fromInt(100);
  static final Decimal twelve = Decimal.fromInt(12);
  static final Decimal two = Decimal.fromInt(2);

  static Decimal div(Decimal a, Decimal b, {int scale = internalScale}) {
    if (b == Decimal.zero) {
      throw ArgumentError('Divisão por zero.');
    }
    return (a / b).toDecimal(scaleOnInfinitePrecision: scale);
  }

  static Decimal roundInternal(Decimal d) => d.round(scale: internalScale);

  static Decimal moneyRound(Decimal d) => d.round(scale: 2);

  static Decimal powInt(Decimal base, int exponent) {
    if (exponent < 0) {
      final pos = powInt(base, -exponent);
      return div(Decimal.one, pos);
    }
    if (exponent == 0) return Decimal.one;
    var result = Decimal.one;
    var factor = roundInternal(base);
    var e = exponent;
    while (e > 0) {
      if (e.isOdd) {
        result = roundInternal(result * factor);
      }
      e >>= 1;
      if (e > 0) {
        factor = roundInternal(factor * factor);
      }
    }
    return result;
  }

  static Decimal nthRoot(Decimal value, int n) {
    if (n <= 0) throw ArgumentError('Índice da raiz deve ser positivo.');
    if (value < Decimal.zero) {
      throw ArgumentError(
        'Não é possível calcular raiz par/real de número negativo: $value',
      );
    }
    if (value == Decimal.zero) return Decimal.zero;
    if (value == Decimal.one || n == 1) return value;

    final doubleVal = value.toDouble();
    final approx = doubleVal.isFinite && doubleVal > 0
        ? math.pow(doubleVal, 1.0 / n).toDouble()
        : 1.0;
    var x = Decimal.parse(approx.toStringAsPrecision(16));
    final decN = Decimal.fromInt(n);
    final decNMinus1 = Decimal.fromInt(n - 1);

    for (var i = 0; i < 6; i++) {
      final xPow = powInt(x, n - 1);
      final next = div(decNMinus1 * x + div(value, xPow), decN);
      if ((next - x).abs() <= Decimal.parse('1e-22')) {
        return roundInternal(next);
      }
      x = next;
    }
    return roundInternal(x);
  }
}
