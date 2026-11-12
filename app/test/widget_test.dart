import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meta_feita/application/app_controller.dart';
import 'package:meta_feita/domain/models/civil_date.dart';
import 'package:meta_feita/domain/models/credit_models.dart';
import 'package:meta_feita/domain/models/goal_models.dart';
import 'package:meta_feita/domain/models/rate_input.dart';
import 'package:meta_feita/domain/models/simulation_models.dart';
import 'package:meta_feita/domain/rules/backup_validator.dart';
import 'package:meta_feita/infrastructure/exports/backup_service.dart';
import 'package:meta_feita/infrastructure/storage/local_storage_adapter.dart';
import 'package:meta_feita/main.dart';
import 'package:meta_feita/ui/screens/creditos_screen.dart';
import 'package:meta_feita/ui/screens/dividendos_screen.dart';
import 'package:meta_feita/ui/screens/juros_compostos_screen.dart';
import 'package:meta_feita/ui/screens/painel_screen.dart';
import 'package:meta_feita/ui/screens/splash_screen.dart';
import 'package:meta_feita/ui/widgets/credit_cost_dialog.dart';
import 'package:meta_feita/ui/widgets/meta_feita_buttons.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('SplashScreen displays Meta Feita brand copy', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('Meta Feita'), findsOneWidget);
    expect(
      find.text('Contas claras para planejar o seu dinheiro.'),
      findsOneWidget,
    );
    expect(find.text('UM APP FEITO LABS'), findsOneWidget);
  });

  testWidgets(
    'Mobile Painel -> Juros Compostos calculates 56.666,82, saves to Historico, search & delete works offline',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AppController(
        storage: InMemoryLocalStorageAdapter(),
        apiClient: FakeMonetizationClient(offline: true),
      );

      await tester.pumpWidget(
        MetaFeitaApp(
          controller: controller,
          showSplash: false,
          autoSyncCredits: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Planeje com números que você entende.'),
        findsOneWidget,
      );
      expect(find.byType(BrasaPrimaryButton), findsOneWidget);

      // Abre calculadora Juros Compostos pelo card do Painel
      final painelScroll = find.descendant(
        of: find.byType(PainelScreen),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Juros compostos'),
        200,
        scrollable: painelScroll,
      );
      await tester.ensureVisible(find.text('Juros compostos').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juros compostos').first);
      await tester.pumpAndSettle();

      // Prévia ao final do formulário
      final jurosScroll = find
          .descendant(
            of: find.byType(JurosCompostosScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.textContaining('56.666,82'),
        200,
        scrollable: jurosScroll,
      );
      expect(find.textContaining('56.666,82'), findsWidgets);

      // Toca em Calcular
      await tester.tap(find.text('Calcular'));
      await tester.pumpAndSettle();

      expect(find.text('VALOR FUTURO ESTIMADO'), findsOneWidget);
      expect(find.textContaining('56.666,82'), findsWidgets);

      // Salva simulação no histórico local
      final resultScroll = find
          .descendant(
            of: find.byType(JurosCompostosScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Salvar simulação'),
        200,
        scrollable: resultScroll,
      );
      await tester.ensureVisible(find.text('Salvar simulação'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar simulação'));
      await tester.pumpAndSettle();

      expect(find.text('Salvar no histórico local'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).last,
        'Minha Reserva Teste',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(controller.simulations.length, 1);
      expect(controller.simulations.first.title, 'Minha Reserva Teste');

      // Volta para editar e então volta para o Painel e vai para o Histórico
      await tester.scrollUntilVisible(
        find.byTooltip('Voltar para editar'),
        -300,
        scrollable: resultScroll,
      );
      await tester.tap(find.byTooltip('Voltar para editar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Histórico').last);
      await tester.pumpAndSettle();

      expect(find.text('Minha Reserva Teste'), findsOneWidget);

      // Filtra por busca inexistente
      await tester.enterText(find.byType(TextField).first, 'InexistenteXYZ');
      await tester.pumpAndSettle();
      expect(find.text('Minha Reserva Teste'), findsNothing);

      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(find.text('Minha Reserva Teste'), findsOneWidget);

      // Excluir exige confirmação
      await tester.tap(find.byTooltip('Excluir simulação'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir simulação?'), findsOneWidget);
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(controller.simulations, isEmpty);
    },
  );

  testWidgets('Dividendos calculates prototype baseline values accurately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = AppController(
      storage: InMemoryLocalStorageAdapter(),
      apiClient: FakeMonetizationClient(offline: true),
    );

    await tester.pumpWidget(
      MetaFeitaApp(
        controller: controller,
        showSplash: false,
        autoSyncCredits: false,
      ),
    );
    await tester.pumpAndSettle();

    final painelScroll = find.descendant(
      of: find.byType(PainelScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Dividendos'),
      200,
      scrollable: painelScroll,
    );
    await tester.ensureVisible(find.text('Dividendos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dividendos').first);
    await tester.pumpAndSettle();

    final divScroll = find
        .descendant(
          of: find.byType(DividendosScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(r'R$ 212,50'),
      200,
      scrollable: divScroll,
    );
    expect(find.text(r'R$ 212,50'), findsOneWidget);
    expect(find.textContaining('10,37%'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('1.177 cotas'),
      200,
      scrollable: divScroll,
    );
    expect(find.text('1.177 cotas'), findsOneWidget);
  });

  testWidgets('Metas tab saves a goal and displays focus math on Painel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = AppController(
      storage: InMemoryLocalStorageAdapter(),
      apiClient: FakeMonetizationClient(offline: true),
    );
    controller.saveGoal(
      SavedGoal(
        id: 'goal_1',
        title: 'Reserva de emergência',
        input: GoalInput(
          targetValue: Decimal.fromInt(30000),
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
        isFocus: true,
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      ),
    );

    await tester.pumpWidget(
      MetaFeitaApp(
        controller: controller,
        showSplash: false,
        autoSyncCredits: false,
      ),
    );
    await tester.pumpAndSettle();

    // Painel exibe a meta em foco
    expect(find.text('META EM FOCO'), findsOneWidget);
    expect(find.text('Reserva de emergência'), findsOneWidget);

    // Navega até a aba Metas
    await tester.tap(find.text('Metas').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('29.272,93'), findsOneWidget);
    expect(find.textContaining('837,72'), findsOneWidget);
    expect(find.text('19 meses'), findsOneWidget);
  });

  testWidgets(
    'Creditos screen syncs online, claims rewarded ad, shows ANTES DE USAR',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = FakeMonetizationClient(offline: false, serverBalance: 12);
      final controller = AppController(
        storage: InMemoryLocalStorageAdapter(),
        apiClient: api,
        ads: FakeAdGateway(),
        billing: FakeBillingGateway(),
        serverVerifiesRewards: false,
      );

      await tester.pumpWidget(
        MetaFeitaApp(
          controller: controller,
          showSplash: false,
          autoSyncCredits: true,
        ),
      );
      await tester.pumpAndSettle();

      // Dispensa dialog de recovery code exibido na criação da carteira
      expect(find.text('Código de recuperação de créditos'), findsOneWidget);
      await tester.tap(find.text('Já anotei'));
      await tester.pumpAndSettle();

      // Vai para aba Créditos
      await tester.tap(find.text('Créditos').last);
      await tester.pumpAndSettle();

      expect(find.text('12 créditos', findRichText: true), findsOneWidget);
      expect(find.text('Comprar 30 créditos'), findsOneWidget);
      expect(find.byType(BrasaPrimaryButton), findsOneWidget);

      // Ganha crédito via anúncio premiado
      await tester.ensureVisible(find.textContaining('Assistir anúncio'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Assistir anúncio'));
      await tester.pumpAndSettle();
      expect(find.text('Anúncio premiado'), findsOneWidget);
      await tester.tap(find.text('Assistir e validar'));
      await tester.pumpAndSettle();

      expect(controller.creditBalance, 13);
      await tester.scrollUntilVisible(
        find.text('13 créditos', findRichText: true),
        -200,
        scrollable: find
            .descendant(
              of: find.byType(CreditosScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('13 créditos', findRichText: true), findsOneWidget);

      // Verifica modal ANTES DE USAR
      final creditosScroll = find
          .descendant(
            of: find.byType(CreditosScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Visualizar confirmação de uso'),
        200,
        scrollable: creditosScroll,
      );
      await tester.drag(creditosScroll, const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visualizar confirmação de uso'));
      await tester.pumpAndSettle();
      expect(find.text('ANTES DE USAR'), findsWidgets);
      expect(find.text('Usar créditos'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'showCreditCostConfirmationDialog blocks confirming when balance insufficient',
    (tester) async {
      bool confirmed = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    confirmed = await showCreditCostConfirmationDialog(
                      context,
                      featureTitle: 'Relatório detalhado',
                      creditCost: 2,
                      currentBalance: 1,
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Saldo insuficiente'), findsOneWidget);

      await tester.tap(find.text('Usar créditos'));
      await tester.pumpAndSettle();
      // Como está desabilitado, dialog permanece aberto até cancelar
      expect(find.text('ANTES DE USAR'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
    },
  );

  testWidgets(
    'Desktop viewport renders top bar, sidebar and 8 calculator cards',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AppController(
        storage: InMemoryLocalStorageAdapter(),
        apiClient: FakeMonetizationClient(offline: true),
      );

      await tester.pumpWidget(
        MetaFeitaApp(
          controller: controller,
          showSplash: false,
          autoSyncCredits: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Funciona offline'), findsOneWidget);
      expect(find.text('Aposentadoria'), findsWidgets);
      expect(find.text('Configurações'), findsOneWidget);
      final painelScroll = find.descendant(
        of: find.byType(PainelScreen),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Privacidade'),
        200,
        scrollable: painelScroll,
      );
      expect(find.text('Privacidade'), findsOneWidget);
      expect(find.text('Termos de uso'), findsOneWidget);

      // Visita todas as calculadoras e configurações na barra lateral sem erros de layout
      for (final label in [
        'Reinvestimento',
        'Comparador',
        'Inflação',
        'Retiradas',
        'Aposentadoria',
        'Configurações',
      ]) {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Apagar dados deste aparelho'), findsOneWidget);
    },
  );

  test(
    'Backup export & validation strips/rejects credits and supports merge vs replace',
    () {
      final storage = InMemoryLocalStorageAdapter();
      final controller = AppController(
        storage: storage,
        apiClient: FakeMonetizationClient(offline: true),
      );

      final sim1 = SavedSimulation(
        id: 's1',
        title: 'Sim 1',
        type: SimulationType.compoundInterest,
        summaryLabel: 'R\$ 1.000,00',
        inputData: const {'a': 1},
        resultData: const {'b': 2},
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );
      final sim2 = SavedSimulation(
        id: 's2',
        title: 'Sim 2',
        type: SimulationType.dividends,
        summaryLabel: 'R\$ 200,00/mês',
        inputData: const {'c': 3},
        resultData: const {'d': 4},
        createdAt: DateTime(2026, 4, 2),
        updatedAt: DateTime(2026, 4, 2),
      );

      final jsonStr = BackupService.buildBackupJson(
        simulations: [sim2],
        goals: const [],
        preferences: const PreferenceModel(autoSaveSimulations: true),
      );
      final parsed = BackupValidator.parseAndValidate(jsonStr);
      expect(parsed.simulations.length, 1);

      controller.saveSimulation(
        title: sim1.title,
        type: sim1.type,
        summaryLabel: sim1.summaryLabel,
        inputData: sim1.inputData,
        resultData: sim1.resultData,
      );

      controller.applyBackup(parsed, replaceAll: false);
      expect(controller.simulations.length, 2);

      controller.applyBackup(parsed, replaceAll: true);
      expect(controller.simulations.length, 1);
      expect(controller.simulations.first.id, 's2');

      // JSON adulterado com créditos é rejeitado explicitamente
      expect(
        () => BackupValidator.parseAndValidate(
          '{"app":"Meta Feita","schemaVersion":1,"exportedAt":"2026-04-01T00:00:00Z","credits":999,"simulations":[],"goals":[]}',
        ),
        throwsA(isA<BackupValidationException>()),
      );
    },
  );
}
