import 'package:flutter/material.dart';

import '../theme/meta_feita_theme.dart';
import '../widgets/meta_feita_icon.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MfColors.petroleo,
      body: Stack(
        children: [
          // Formas geométricas sutis da marca no rodapé (Página 11 do protótipo)
          Positioned(
            left: -10,
            right: -10,
            bottom: -16,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: MfColors.azulRio.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(88),
                      ),
                    ),
                  ),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: MfColors.azulRioClaro.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  Container(
                    width: 92,
                    height: 54,
                    decoration: BoxDecoration(
                      color: MfColors.nevoaClaro.withValues(alpha: 0.14),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(92),
                      ),
                    ),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: MfColors.azulRio.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: const MetaFeitaLogo(
                        variant: MetaFeitaLogoVariant.principalPetroleo,
                        size: 62,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Meta Feita',
                      style: MfText.titulo.copyWith(
                        color: Colors.white,
                        fontSize: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Contas claras para planejar o seu dinheiro.',
                      textAlign: TextAlign.center,
                      style: MfText.corpo.copyWith(
                        color: MfColors.nevoaClaro,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 44),
                    Text(
                      'UM APP FEITO LABS',
                      style: MfText.legenda.copyWith(
                        color: MfColors.azulRioClaro,
                        letterSpacing: 2.2,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

