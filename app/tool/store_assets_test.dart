// Gera as imagens da ficha da Play Store a partir do app real.
// Uso (na pasta app/):
//   flutter test --update-goldens tool/store_assets_test.dart
// Saída: docs/play-store/imagens/
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_feita/application/app_controller.dart';
import 'package:meta_feita/domain/models/civil_date.dart';
import 'package:meta_feita/domain/models/goal_models.dart';
import 'package:meta_feita/domain/models/rate_input.dart';
import 'package:meta_feita/domain/models/simulation_models.dart';
import 'package:meta_feita/infrastructure/billing/billing_gateway.dart';
import 'package:meta_feita/main.dart';
import 'package:meta_feita/ui/theme/meta_feita_theme.dart';
import 'package:meta_feita/ui/widgets/meta_feita_icon.dart';

import '../test/support/fakes.dart';

const String outputDir = '../../docs/play-store/imagens';

// 432 x 768 lógicos a 2,5x = 1080 x 1920 pixels (proporção 16:9).
const Size phoneLogicalSize = Size(432, 768);
const double phonePixelRatio = 2.5;

SavedGoal goal(
  String id,
  String title, {
  required int target,
  required int current,
  required int monthly,
  required int months,
  required CivilDate date,
  bool focus = false,
}) {
  final now = DateTime(2026, 11, 1);
  return SavedGoal(
    id: id,
    title: title,
    input: GoalInput(
      targetValue: Decimal.fromInt(target),
      currentCapital: Decimal.fromInt(current),
      periodicContribution: Decimal.fromInt(monthly),
      contributionFrequency: ContributionFrequency.monthly,
      contributionTiming: ContributionTiming.end,
      rate: RateInput.fromPercent(
        percent: Decimal.parse('0.8'),
        kind: RateKind.effective,
        period: RatePeriod.monthly,
      ),
      termMonths: months,
    ),
    targetDate: date,
    isFocus: focus,
    createdAt: now,
    updatedAt: now,
  );
}

Future<AppController> sampleController(WidgetTester tester) async {
  // Loja e anúncios simulados: botões ativos e preços do catálogo, sem banners de teste.
  final billing = FakeBillingGateway()
    ..products = const {
      'meta_feita_credits_10': BillingProduct(
        productId: 'meta_feita_credits_10',
        displayPrice: r'R$ 4,90',
      ),
      'meta_feita_credits_30': BillingProduct(
        productId: 'meta_feita_credits_30',
        displayPrice: r'R$ 11,90',
      ),
      'meta_feita_credits_80': BillingProduct(
        productId: 'meta_feita_credits_80',
        displayPrice: r'R$ 24,90',
      ),
    };
  final controller = await tester.runAsync(
    () => onlineController(
      api: FakeMonetizationClient(serverBalance: 30),
      ads: FakeAdGateway(canShow: false),
      billing: billing,
    ),
  );
  await tester.runAsync(controller!.startBilling);
  controller.dismissPendingRecoveryCode();

  controller.saveGoal(
    goal(
      'g2',
      'Viagem em família',
      target: 18000,
      current: 4500,
      monthly: 600,
      months: 20,
      date: const CivilDate(2028, 7, 1),
    ),
  );
  controller.saveGoal(
    goal(
      'g1',
      'Reserva de emergência',
      target: 30000,
      current: 12000,
      monthly: 800,
      months: 18,
      date: const CivilDate(2028, 5, 1),
      focus: true,
    ),
  );

  const simulations = [
    ('Aposentadoria tranquila', SimulationType.retirement, r'R$ 4.850,00/mês'),
    (
      'Carteira de dividendos',
      SimulationType.dividends,
      r'R$ 212,50 por pagamento',
    ),
    ('Tesouro x CDB', SimulationType.comparator, r'R$ 61.240,18'),
    ('Reserva em 5 anos', SimulationType.compoundInterest, r'R$ 56.666,82'),
  ];
  for (final (title, type, summary) in simulations) {
    controller.saveSimulation(
      title: title,
      type: type,
      summaryLabel: summary,
      inputData: const {},
      resultData: const {},
    );
  }
  return controller;
}

Future<void> settle(WidgetTester tester) async {
  // Ícones SVG carregam de forma assíncrona.
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> openApp(WidgetTester tester) async {
  tester.view.physicalSize = phoneLogicalSize * phonePixelRatio;
  tester.view.devicePixelRatio = phonePixelRatio;
  addTearDown(tester.view.reset);

  final controller = await sampleController(tester);
  await tester.pumpWidget(
    MetaFeitaApp(
      controller: controller,
      showSplash: false,
      autoSyncCredits: false,
    ),
  );
  await settle(tester);
}

Future<void> openCalculator(WidgetTester tester, String label) async {
  final card = find.text(label).first;
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await settle(tester);
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await settle(tester);
}

Future<void> capture(String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$outputDir/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    // Ícones do Material usados em alguns botões (no app real vêm do próprio Flutter).
    final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
    final iconFont = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes().then((bytes) => ByteData.sublistView(bytes));
    await (FontLoader('MaterialIcons')..addFont(iconFont)).load();
  });

  testWidgets('01 painel', (tester) async {
    await openApp(tester);
    await capture('01-painel');
  });

  testWidgets('02 juros compostos', (tester) async {
    await openApp(tester);
    await openCalculator(tester, 'Juros compostos');
    await tester.tap(find.text('Calcular'));
    await settle(tester);
    await capture('02-juros-compostos');
  });

  testWidgets('03 dividendos', (tester) async {
    await openApp(tester);
    await openCalculator(tester, 'Dividendos');
    await capture('03-dividendos');
  });

  testWidgets('04 metas', (tester) async {
    await openApp(tester);
    await openTab(tester, 'Metas');
    await capture('04-metas');
  });

  testWidgets('05 comparador', (tester) async {
    await openApp(tester);
    await openCalculator(tester, 'Comparador');
    await capture('05-comparador');
  });

  testWidgets('06 aposentadoria', (tester) async {
    await openApp(tester);
    await openCalculator(tester, 'Aposentadoria');
    await capture('06-aposentadoria');
  });

  testWidgets('07 historico', (tester) async {
    await openApp(tester);
    await openTab(tester, 'Histórico');
    await capture('07-historico');
  });

  testWidgets('08 creditos', (tester) async {
    await openApp(tester);
    await openTab(tester, 'Créditos');
    await capture('08-creditos');
  });

  testWidgets('imagem de destaque 1024x500', (tester) async {
    tester.view.physicalSize = const Size(1024, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MetaFeitaTheme.build(),
        home: const _FeatureGraphic(),
      ),
    );
    await settle(tester);
    await capture('imagem-de-destaque');
  });
}

class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MfColors.petroleo,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            bottom: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: MfColors.azulRio.withValues(alpha: 0.40),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(260),
                ),
              ),
            ),
          ),
          Positioned(
            right: 190,
            bottom: 40,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: MfColors.azulRioClaro.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            right: 70,
            top: 50,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: MfColors.brasa.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 72),
              child: Row(
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    alignment: Alignment.center,
                    child: const MetaFeitaLogo(size: 108),
                  ),
                  const SizedBox(width: 44),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meta Feita',
                          style: MfText.titulo.copyWith(
                            color: Colors.white,
                            fontSize: 64,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Contas claras para planejar\no seu dinheiro.',
                          style: MfText.corpo.copyWith(
                            color: MfColors.nevoaClaro,
                            fontSize: 28,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
