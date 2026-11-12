import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_feita/application/app_controller.dart';
import 'package:meta_feita/domain/models/credit_models.dart';
import 'package:meta_feita/infrastructure/ads/ad_gateway.dart';
import 'package:meta_feita/infrastructure/billing/billing_gateway.dart';
import 'package:meta_feita/infrastructure/monetization/monetization_api_client.dart';
import 'package:meta_feita/ui/screens/configuracoes_screen.dart';
import 'package:meta_feita/ui/screens/creditos_screen.dart';
import 'package:meta_feita/ui/widgets/ad_banner_slot.dart';

import 'support/fakes.dart';

const String wallet = 'wlt_test_ref_1234';

BillingPurchase purchase({
  String token = 'token_1',
  BillingPurchaseStatus status = BillingPurchaseStatus.purchased,
  String? accountId,
}) {
  return BillingPurchase(
    productId: 'meta_feita_credits_30',
    purchaseToken: token,
    orderId: 'GPA.1',
    status: status,
    accountId: accountId,
  );
}

CreditPackage packageOf(AppController controller) => controller.catalog.packages
    .firstWhere((p) => p.playProductId == 'meta_feita_credits_30');

Future<void> settleEvents() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Widget hostScreen(Widget child) {
  return MaterialApp(
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

void main() {
  group('Anúncio premiado', () {
    test(
      'com blocos de teste, credita pelo endpoint de desenvolvimento',
      () async {
        final api = FakeMonetizationClient(serverBalance: 12);
        final ads = FakeAdGateway();
        final controller = await onlineController(api: api, ads: ads);

        final claim = await controller.watchRewardedAd();

        expect(claim.outcome, RewardOutcome.credited);
        expect(claim.balance, 13);
        expect(api.claimCalls, 1);
        expect(ads.rewardUsers, [wallet]);
        expect(controller.creditBalance, 13);
      },
    );

    test(
      'com blocos reais, credita só quando o servidor registra o callback',
      () async {
        final api = FakeMonetizationClient(serverBalance: 12);
        final ads = FakeAdGateway();
        final controller = await onlineController(
          api: api,
          ads: ads,
          serverVerifiesRewards: true,
        );
        ads.onRewardedShown = () {
          api.serverBalance = 13;
          api.entries.add(
            LedgerEntry(
              transactionId: 'tx_ssv',
              walletReference: wallet,
              source: 'rewarded_ad',
              productId: 'admob',
              creditDelta: 1,
              providerTransactionId: 'ssv_1',
              status: 'granted',
              createdAt: DateTime.now(),
              idempotencyKey: ads.rewardCustomData.single,
            ),
          );
        };

        final claim = await controller.watchRewardedAd();

        expect(claim.outcome, RewardOutcome.credited);
        expect(controller.creditBalance, 13);
        expect(
          api.claimCalls,
          0,
          reason: 'o app não pode conceder o próprio crédito',
        );
      },
    );

    test(
      'sem callback a tempo, informa pendência e não altera o saldo',
      () async {
        final api = FakeMonetizationClient(serverBalance: 12);
        final controller = await onlineController(
          api: api,
          ads: FakeAdGateway(),
          serverVerifiesRewards: true,
        );

        final claim = await controller.watchRewardedAd();

        expect(claim.outcome, RewardOutcome.pendingConfirmation);
        expect(controller.creditBalance, 12);
      },
    );

    test('fechar o anúncio antes do fim não credita', () async {
      final api = FakeMonetizationClient(serverBalance: 12);
      final controller = await onlineController(
        api: api,
        ads: FakeAdGateway(
          rewardedStatus: RewardedAdStatus.dismissedWithoutReward,
        ),
      );

      final claim = await controller.watchRewardedAd();

      expect(claim.outcome, RewardOutcome.notEarned);
      expect(api.claimCalls, 0);
      expect(controller.creditBalance, 12);
    });

    test('sem anúncio disponível, não credita', () async {
      final api = FakeMonetizationClient(serverBalance: 12);
      final controller = await onlineController(
        api: api,
        ads: FakeAdGateway(rewardedStatus: RewardedAdStatus.unavailable),
      );

      final claim = await controller.watchRewardedAd();

      expect(claim.outcome, RewardOutcome.unavailable);
      expect(api.claimCalls, 0);
    });
  });

  group('Google Play Billing', () {
    late FakeMonetizationClient api;
    late FakeBillingGateway billing;
    late AppController controller;

    setUp(() async {
      api = FakeMonetizationClient(serverBalance: 12);
      billing = FakeBillingGateway();
      controller = await onlineController(api: api, billing: billing);
      await controller.startBilling();
    });

    tearDown(() => billing.dispose());

    test('usa o preço da loja no lugar do preço do catálogo', () {
      expect(controller.displayPriceFor(packageOf(controller)), r'R$ 12,99');
    });

    test(
      'compra paga: valida no servidor, credita e só então consome',
      () async {
        await controller.buyCreditPackage(packageOf(controller));
        expect(controller.isPurchasing, isTrue);
        expect(billing.boughtWallets, [wallet]);

        billing.emit(purchase());
        await settleEvents();

        expect(api.playValidations, ['token_1']);
        expect(billing.finishedTokens, ['token_1']);
        expect(controller.creditBalance, 42);
        expect(controller.isPurchasing, isFalse);
        expect(controller.billingNotice, contains('Compra confirmada'));
      },
    );

    test('falha na validação: não consome e não credita', () async {
      api.playValidationError = const MonetizationApiException(
        'HTTP_503',
        'indisponível',
        503,
      );

      billing.emit(purchase());
      await settleEvents();

      expect(billing.finishedTokens, isEmpty);
      expect(controller.creditBalance, 12);
      expect(controller.isPurchasing, isFalse);
      expect(controller.billingNotice, contains('ainda não confirmado'));
    });

    test('servidor sem confirmação de pagamento: não consome', () async {
      api.playAcknowledged = false;

      billing.emit(purchase());
      await settleEvents();

      expect(billing.finishedTokens, isEmpty);
      expect(controller.creditBalance, 12);
      expect(controller.billingNotice, contains('pendente'));
    });

    test('pagamento pendente não chama o servidor', () async {
      billing.emit(purchase(status: BillingPurchaseStatus.pending));
      await settleEvents();

      expect(api.playValidations, isEmpty);
      expect(controller.billingNotice, contains('pendente'));
    });

    test('cancelar libera o botão sem aviso', () async {
      await controller.buyCreditPackage(packageOf(controller));
      billing.emit(purchase(status: BillingPurchaseStatus.canceled));
      await settleEvents();

      expect(controller.isPurchasing, isFalse);
      expect(controller.billingNotice, isNull);
      expect(api.playValidations, isEmpty);
    });

    test('evento repetido durante a validação é processado uma vez', () async {
      billing.emit(purchase());
      billing.emit(purchase());
      await settleEvents();

      expect(api.playValidations, ['token_1']);
      expect(billing.finishedTokens, ['token_1']);
    });

    test('falha ao consumir mantém o crédito já concedido', () async {
      billing.finishFails = true;

      billing.emit(purchase());
      await settleEvents();

      expect(controller.creditBalance, 42);
      expect(controller.billingNotice, contains('Compra confirmada'));
    });

    test('compra restaurada usa a carteira gravada na compra', () async {
      billing.emit(
        purchase(
          status: BillingPurchaseStatus.restored,
          accountId: 'mf_w_carteira_original',
        ),
      );
      await settleEvents();

      expect(api.playWallets, ['mf_w_carteira_original']);
      expect(billing.finishedTokens, ['token_1']);
      expect(controller.billingNotice, isNull);
    });

    test('pacote que não existe na loja não abre o pagamento', () async {
      billing.products = const {};
      final fresh = await onlineController(api: api, billing: billing);

      await expectLater(
        fresh.buyCreditPackage(packageOf(fresh)),
        throwsA(
          isA<MonetizationApiException>().having(
            (e) => e.code,
            'code',
            'BILLING_UNAVAILABLE',
          ),
        ),
      );
      expect(billing.boughtProducts, isEmpty);
    });

    test(
      'loja que não responde encerra a tentativa em vez de travar',
      () async {
        billing.products = const {};
        final hanging = FakeBillingGateway()..storeHangs = true;
        final fresh = await onlineController(
          api: api,
          billing: hanging,
          storeTimeout: const Duration(milliseconds: 10),
        );

        await expectLater(
          fresh.buyCreditPackage(packageOf(fresh)),
          throwsA(
            isA<MonetizationApiException>().having(
              (e) => e.code,
              'code',
              'BILLING_UNAVAILABLE',
            ),
          ),
        );
        expect(fresh.isPurchasing, isFalse);
        await hanging.dispose();
      },
    );

    test('loja recusando abrir o pagamento libera o botão', () async {
      billing.opensCheckout = false;

      await controller.buyCreditPackage(packageOf(controller));

      expect(controller.isPurchasing, isFalse);
      expect(controller.billingNotice, contains('não foi concluída'));
    });

    test('ao iniciar, retoma compras pagas não concluídas', () async {
      final otherBilling = FakeBillingGateway()
        ..unfinished = [purchase(status: BillingPurchaseStatus.restored)];
      final other = await onlineController(api: api, billing: otherBilling);

      await other.startBilling();
      await settleEvents();

      expect(otherBilling.restoreCalls, 1);
      expect(otherBilling.finishedTokens, ['token_1']);
      await otherBilling.dispose();
    });
  });

  group('Tela de créditos', () {
    testWidgets('no Android compra pela Google Play, sem checkout web', (
      tester,
    ) async {
      final api = FakeMonetizationClient(serverBalance: 12);
      final billing = FakeBillingGateway();
      final controller = await tester.runAsync(
        () => onlineController(api: api, billing: billing),
      );
      await tester.runAsync(controller!.startBilling);

      await tester.pumpWidget(
        hostScreen(CreditosScreen(controller: controller)),
      );
      await tester.pump();

      expect(find.text(r'R$ 12,99'), findsOneWidget);

      await tester.tap(find.text('Comprar 30 créditos'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(billing.boughtProducts, ['meta_feita_credits_30']);
      expect(api.webCheckoutCalls, 0);
      await tester.runAsync(billing.dispose);
    });

    testWidgets('sem suporte a anúncios, esconde o botão premiado', (
      tester,
    ) async {
      final api = FakeMonetizationClient(serverBalance: 12);
      final controller = await tester.runAsync(
        () => onlineController(api: api),
      );

      await tester.pumpWidget(
        hostScreen(CreditosScreen(controller: controller!)),
      );
      await tester.pump();

      expect(find.textContaining('Assistir anúncio'), findsNothing);
    });

    testWidgets('não mostra ID técnico do bloco no aviso do anúncio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = FakeMonetizationClient(serverBalance: 12);
      final controller = await tester.runAsync(
        () => onlineController(api: api, ads: FakeAdGateway()),
      );

      await tester.pumpWidget(
        hostScreen(CreditosScreen(controller: controller!)),
      );
      await tester.pump();
      await tester.ensureVisible(find.textContaining('Assistir anúncio'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Assistir anúncio'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ca-app-pub'), findsNothing);
      expect(find.text('Anúncio premiado'), findsOneWidget);
    });
  });

  group('Publicidade e privacidade', () {
    testWidgets('banner só aparece depois do consentimento', (tester) async {
      await tester.pumpWidget(
        hostScreen(SafeAdBannerSlot(ads: FakeAdGateway(canShow: false))),
      );
      expect(find.text('ANÚNCIO'), findsNothing);

      await tester.pumpWidget(
        hostScreen(SafeAdBannerSlot(ads: FakeAdGateway())),
      );
      await tester.pump();
      expect(find.text('ANÚNCIO'), findsOneWidget);
      expect(find.byKey(const ValueKey('fake-banner')), findsOneWidget);
    });

    testWidgets('sem provedor de anúncios, o slot não ocupa espaço', (
      tester,
    ) async {
      await tester.pumpWidget(
        hostScreen(const SafeAdBannerSlot(ads: NoAdGateway())),
      );
      expect(find.text('ANÚNCIO'), findsNothing);
      expect(tester.getSize(find.byType(SafeAdBannerSlot)).height, 0);
    });

    Future<void> pumpSettings(WidgetTester tester, AdGateway ads) async {
      tester.view.physicalSize = const Size(412, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final controller = await tester.runAsync(
        () => onlineController(api: FakeMonetizationClient(), ads: ads),
      );
      await tester.pumpWidget(
        hostScreen(
          ConfiguracoesScreen(controller: controller!, onNavigate: (_) {}),
        ),
      );
      await tester.pump();
    }

    testWidgets('Configurações oferece preferências quando a região exige', (
      tester,
    ) async {
      await pumpSettings(tester, FakeAdGateway(privacyRequired: true));
      expect(find.text('Preferências de anúncios'), findsOneWidget);
    });

    testWidgets('Configurações omite preferências quando não exigidas', (
      tester,
    ) async {
      await pumpSettings(tester, FakeAdGateway());
      expect(find.text('Preferências de anúncios'), findsNothing);
    });
  });
}
