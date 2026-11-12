import 'package:decimal/decimal.dart';

class PtBrFormatters {
  static String money(Decimal value, {bool includeSymbol = true}) {
    final rounded = value.round(scale: 2);
    final negative = rounded < Decimal.zero;
    final absVal = rounded.abs();
    final fixed = absVal.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final grouped = _groupThousands(intPart);
    final prefix = includeSymbol ? 'R\$ ' : '';
    return '${negative ? '-' : ''}$prefix$grouped,$decPart';
  }

  static String compactMoney(Decimal value) {
    final abs = value.abs();
    if (abs >= Decimal.fromInt(1000000)) {
      final m = (abs / Decimal.fromInt(1000000))
          .toDecimal(scaleOnInfinitePrecision: 4)
          .round(scale: 1);
      final str = m.toString().replaceAll('.', ',').replaceAll(',0', '');
      return '${value < Decimal.zero ? '-' : ''}$str mi';
    }
    if (abs >= Decimal.fromInt(1000)) {
      final k = (abs / Decimal.fromInt(1000))
          .toDecimal(scaleOnInfinitePrecision: 4)
          .round(scale: 1);
      final str = k.toString().replaceAll('.', ',').replaceAll(',0', '');
      return '${value < Decimal.zero ? '-' : ''}$str mil';
    }
    return abs.round(scale: 0).toString();
  }

  static String percentFromFraction(Decimal fraction, {int decimals = 2}) {
    return percent(fraction.shift(2), decimals: decimals);
  }

  static String percent(
    Decimal pct, {
    int decimals = 2,
    bool trimTrailingZeros = false,
  }) {
    final rounded = pct.round(scale: decimals);
    var str = rounded.toStringAsFixed(decimals).replaceAll('.', ',');
    if (trimTrailingZeros && decimals > 0) {
      str = str.replaceAll(RegExp(r',?0+$'), '');
    }
    return '$str%';
  }

  static String quantity(Decimal qty, {int maxDecimals = 4}) {
    if (qty.isInteger) {
      return _groupThousands(qty.toBigInt().toString());
    }
    final rounded = qty.round(scale: maxDecimals);
    var fixed = rounded.toString();
    if (!fixed.contains('.')) {
      return _groupThousands(fixed);
    }
    final parts = fixed.split('.');
    var dec = parts[1].replaceAll(RegExp(r'0+$'), '');
    if (dec.isEmpty) return _groupThousands(parts[0]);
    return '${_groupThousands(parts[0])},$dec';
  }

  /// Faz parse flexível de entrada pt-BR ou numérica padrão ("10.000,50", "0,9", "1000.5").
  static Decimal? parseUserDecimal(String raw) {
    var cleaned = raw.trim();
    if (cleaned.isEmpty) return null;
    cleaned = cleaned
        .replaceAll('R\$', '')
        .replaceAll('%', '')
        .replaceAll(' ', '');
    if (cleaned.isEmpty) return null;

    if (cleaned.contains(',')) {
      // Formato pt-BR: ponto é separador de milhar, vírgula é decimal
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Se houver múltiplos pontos (ex: "10.000.000"), trata como separadores de milhar
      final dotCount = '.'.allMatches(cleaned).length;
      if (dotCount > 1) {
        cleaned = cleaned.replaceAll('.', '');
      }
    }
    return Decimal.tryParse(cleaned);
  }

  static String editableDecimal(Decimal value, {int decimals = 2}) {
    final rounded = value.round(scale: decimals);
    return rounded.toStringAsFixed(decimals).replaceAll('.', ',');
  }

  static String editablePercent(Decimal fraction, {int maxDecimals = 4}) {
    final pct = fraction.shift(2).round(scale: maxDecimals);
    var str = pct.toString();
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return str.replaceAll('.', ',');
  }

  static String _groupThousands(String digits) {
    final negative = digits.startsWith('-');
    final body = negative ? digits.substring(1) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < body.length; i++) {
      final posFromRight = body.length - i;
      buf.write(body[i]);
      if (posFromRight > 1 && posFromRight % 3 == 1) {
        buf.write('.');
      }
    }
    return negative ? '-${buf.toString()}' : buf.toString();
  }
}
