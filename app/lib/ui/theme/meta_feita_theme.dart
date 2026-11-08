import 'package:flutter/material.dart';

class MfColors {
  static const Color areia = Color(0xFFF3EDE2);
  static const Color areiaCard = Color(0xFFF9F5EE);
  static const Color areiaSubtle = Color(0xFFEDE5D7);
  static const Color petroleo = Color(0xFF0E3B43);
  static const Color petroleoDeep = Color(0xFF0A2E35);
  static const Color azulRio = Color(0xFF1F7A8C);
  static const Color nevoa = Color(0xFF8FC1C9);
  static const Color nevoaSoft = Color(0xFF9AC7CE);
  static const Color brasa = Color(0xFFF26B21);

  // Tokens sobre fundo Petróleo
  static const Color azulRioClaro = Color(0xFF5FB3C2);
  static const Color nevoaClaro = Color(0xFFA9D3DA);
  static const Color brasaClaro = Color(0xFFFF8A4C);

  // Utilitários semânticos
  static const Color inkMuted = Color(0xBD0E3B43); // ~74% Petróleo
  static const Color border = Color(0x260E3B43); // 15% Petróleo
  static const Color borderStrong = Color(0x4D0E3B43); // 30% Petróleo
  static const Color erro = Color(0xFFB9382C);
  static const Color erroSurface = Color(0x1AB9382C);
  static const Color disabledBg = Color(0xFFE3DDD1);
  static const Color disabledInk = Color(0x730E3B43);
}

class MfText {
  static const String displayFamily = 'BricolageGrotesque';
  static const String bodyFamily = 'HankenGrotesk';

  static const TextStyle numero = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w800,
    fontSize: 40,
    height: 1.08,
    letterSpacing: -0.8,
    color: MfColors.petroleo,
  );

  static const TextStyle titulo = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w800,
    fontSize: 34,
    height: 38 / 34,
    letterSpacing: -0.6,
    color: MfColors.petroleo,
  );

  static const TextStyle subtitulo = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w800,
    fontSize: 22,
    height: 1.2,
    letterSpacing: -0.3,
    color: MfColors.petroleo,
  );

  static const TextStyle tituloCartao = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w800,
    fontSize: 20,
    height: 1.25,
    letterSpacing: -0.2,
    color: MfColors.petroleo,
  );

  static const TextStyle corpo = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 24 / 16,
    color: MfColors.petroleo,
  );

  static const TextStyle rotulo = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    height: 1.35,
    color: MfColors.petroleo,
  );

  static const TextStyle pequeno = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 18 / 13,
    color: MfColors.inkMuted,
  );

  static const TextStyle legenda = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w700,
    fontSize: 13,
    height: 1.2,
    letterSpacing: 0.9,
    color: MfColors.petroleo,
  );
}

class MetaFeitaTheme {
  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: MfColors.areia,
      fontFamily: MfText.bodyFamily,
      colorScheme: const ColorScheme.light(
        primary: MfColors.petroleo,
        onPrimary: MfColors.areia,
        secondary: MfColors.azulRio,
        onSecondary: Colors.white,
        surface: MfColors.areia,
        onSurface: MfColors.petroleo,
        error: MfColors.erro,
        onError: Colors.white,
      ),
      dividerColor: MfColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: MfColors.areia,
        foregroundColor: MfColors.petroleo,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MfColors.petroleo,
        contentTextStyle: MfText.corpo.copyWith(color: MfColors.areia),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MfColors.areiaCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: MfColors.border),
        ),
      ),
    );
    return base;
  }
}

