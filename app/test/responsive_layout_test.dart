import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_feita/application/app_controller.dart';
import 'package:meta_feita/domain/models/civil_date.dart';
import 'package:meta_feita/domain/models/goal_models.dart';
import 'package:meta_feita/domain/models/rate_input.dart';
import 'package:meta_feita/domain/models/simulation_models.dart';
import 'package:meta_feita/main.dart';
import 'package:meta_feita/ui/screens/aposentadoria_screen.dart';
import 'package:meta_feita/ui/screens/comparador_screen.dart';
import 'package:meta_feita/ui/screens/configuracoes_screen.dart';
import 'package:meta_feita/ui/screens/creditos_screen.dart';
import 'package:meta_feita/ui/screens/dividendos_screen.dart';
import 'package:meta_feita/ui/screens/historico_screen.dart';
import 'package:meta_feita/ui/screens/inflacao_screen.dart';
import 'package:meta_feita/ui/screens/juros_compostos_screen.dart';
import 'package:meta_feita/ui/screens/legal_screens.dart';
import 'package:meta_feita/ui/screens/metas_screen.dart';
import 'package:meta_feita/ui/screens/painel_screen.dart';
import 'package:meta_feita/ui/screens/reinvestimento_screen.dart';
import 'package:meta_feita/ui/screens/retiradas_screen.dart';
import 'package:meta_feita/ui/theme/meta_feita_theme.dart';
import 'package:meta_feita/ui/widgets/credit_cost_dialog.dart';

import 'support/fakes.dart';

class ScreenCase {
  final String name;
  final Widget Function(AppController controller) build;
  final String? calculateLabel;
  final bool hasBanner;

  const ScreenCase(
    this.name,
    this.build, {
    this.calculateLabel,
    this.hasBanner = false,
  });
}

final List<ScreenCase> screens = [
  ScreenCase(
    'Painel',
    (c) => PainelScreen(
      controller: c,
      onNavigate: (_, {openSimulation}) {},
      isDesktop: false,
    ),
  ),
  ScreenCase(
    'Juros compostos',
    (c) => JurosCompostosScreen(controller: c, onBack: () {}),
    calculateLabel: 'Calcular',
    hasBanner: true,
  ),
  ScreenCase(
    'Dividendos',
    (c) => DividendosScreen(controller: c, onBack: () {}),
    hasBanner: true,
  ),
  ScreenCase(
    'Reinvestimento',
    (c) => ReinvestimentoScreen(controller: c, onBack: () {}),
    hasBanner: true,
  ),
  ScreenCase('Metas', (c) => MetasScreen(controller: c), hasBanner: true),
  ScreenCase(
    'Comparador',
    (c) => ComparadorScreen(controller: c, onBack: () {}),
    hasBanner: true,
  ),
  ScreenCase(
    'Inflação',
    (c) => InflacaoScreen(controller: c, onBack: () {}),
    hasBanner: true,
  ),
  ScreenCase(
    'Retiradas',
    (c) => RetiradasScreen(controller: c, onBack: () {}),
    hasBanner: true,
  ),
  ScreenCase(
    'Aposentadoria',
    (c) => AposentadoriaScreen(controller: c, onBack: () {}),
    hasBanner: true,
  ),
  ScreenCase(
    'Histórico',
    (c) => HistoricoScreen(
      controller: c,
      onNavigate: (_, {openSimulation}) {},
      onBack: null,
    ),
  ),
  ScreenCase('Créditos', (c) => CreditosScreen(controller: c, onBack: null)),
  ScreenCase(
    'Configurações',
    (c) =>
        ConfiguracoesScreen(controller: c, onNavigate: (_) {}, onBack: () {}),
  ),
  ScreenCase('Privacidade', (c) => PrivacidadeScreen(onBack: () {})),
  ScreenCase('Termos', (c) => TermosScreen(onBack: () {})),
];

const Map<String, double> widths = {
  'celular pequeno 320': 320,
  'celular 360': 360,
  'celular grande 412': 412,
  'tablet 768': 768,
};

const List<double> textScales = [1.0, 1.3, 2.0];

// Altura grande para o ListView construir e medir todo o conteúdo de uma vez.
const double tallHeight = 9000;

SavedGoal sampleGoal(String id, {required bool focus}) {
  return SavedGoal(
    id: id,
    title: 'Reserva de emergência da família com nome bem comprido',
    input: GoalInput(
      targetValue: Decimal.fromInt(1250000),
      currentCapital: Decimal.fromInt(12000),
      periodicContribution: Decimal.fromInt(800),
      contributionFrequency: ContributionFrequency.monthly,
      contributionTiming: ContributionTiming.end,
      rate: RateInput.fromPercent(
        percent: Decimal.parse('0.8'),
        kind: RateKind.effective,
        period: RatePeriod.monthly,
      ),
      termMonths: 18,
    ),
    targetDate: const CivilDate(2027, 10, 1),
    isFocus: focus,
    createdAt: DateTime(2026, 4, 1),
    updatedAt: DateTime(2026, 4, 1),
  );
}

void seedContent(AppController controller) {
  controller.saveGoal(sampleGoal('g1', focus: true));
  controller.saveGoal(sampleGoal('g2', focus: false));
  controller.saveSimulation(
    title: 'Simulação com um título realmente muito longo para testar a quebra',
    type: SimulationType.compoundInterest,
    summaryLabel: r'R$ 1.234.567,89',
    inputData: const {},
    resultData: const {},
  );
}

Widget hostScreen(Widget child) {
  return MaterialApp(
    theme: MetaFeitaTheme.build(),
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void useViewport(WidgetTester tester, Size size, double textScale) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<AppController> seededController(
  WidgetTester tester, {
  FakeAdGateway? ads,
}) async {
  final billing = FakeBillingGateway();
  final controller = await tester.runAsync(
    () => onlineController(
      api: FakeMonetizationClient(serverBalance: 1234),
      ads: ads ?? FakeAdGateway(),
      billing: billing,
    ),
  );
  seedContent(controller!);
  return controller;
}

void main() {
  setUpAll(loadAppFonts);

  for (final screen in screens) {
    group(screen.name, () {
      for (final width in widths.entries) {
        for (final scale in textScales) {
          testWidgets('${width.key} com fonte ${scale}x', (tester) async {
            useViewport(tester, Size(width.value, tallHeight), scale);
            final controller = await seededController(tester);

            await tester.pumpWidget(hostScreen(screen.build(controller)));
            await tester.pumpAndSettle();

            final label = screen.calculateLabel;
            if (label != null) {
              await tester.tap(find.text(label));
              await tester.pumpAndSettle();
            }
          });
        }
      }

      if (screen.hasBanner) {
        testWidgets('exibe o banner depois do resultado', (tester) async {
          useViewport(tester, const Size(412, tallHeight), 1.0);
          final controller = await seededController(tester);

          await tester.pumpWidget(hostScreen(screen.build(controller)));
          await tester.pumpAndSettle();

          final label = screen.calculateLabel;
          if (label != null) {
            expect(
              find.text('ANÚNCIO'),
              findsNothing,
              reason: 'nenhum anúncio antes do resultado',
            );
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
          }

          expect(find.text('ANÚNCIO'), findsOneWidget);
        });
      }
    });
  }

  group('Tela real com altura de aparelho', () {
    const sizes = {
      'celular pequeno': Size(320, 568),
      'celular': Size(360, 640),
      'celular deitado': Size(640, 360),
      'tablet': Size(768, 1024),
      'desktop': Size(1280, 860),
    };

    for (final entry in sizes.entries) {
      for (final scale in textScales) {
        testWidgets('${entry.key} com fonte ${scale}x', (tester) async {
          useViewport(tester, entry.value, scale);
          final controller = await seededController(tester);

          await tester.pumpWidget(
            MetaFeitaApp(
              controller: controller,
              showSplash: false,
              autoSyncCredits: false,
            ),
          );
          await tester.pumpAndSettle();
        });
      }
    }
  });

  group('Diálogos em tela pequena', () {
    for (final scale in textScales) {
      testWidgets('confirmação de custo com fonte ${scale}x', (tester) async {
        useViewport(tester, const Size(320, 568), scale);

        await tester.pumpWidget(
          hostScreen(
            Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showCreditCostConfirmationDialog(
                    context,
                    featureTitle: 'Comparação ampliada (3 a 4 cenários)',
                    creditCost: 2,
                    currentBalance: 1,
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
      });

      testWidgets('editor de meta com fonte ${scale}x', (tester) async {
        useViewport(tester, const Size(320, 568), scale);
        final controller = await seededController(tester);

        await tester.pumpWidget(
          hostScreen(MetasScreen(controller: controller)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('+ Nova meta'));
        await tester.pumpAndSettle();
      });
    }
  });
}
