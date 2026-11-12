import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meta_feita/infrastructure/monetization/monetization_api_client.dart';

import 'support/fakes.dart';

HttpMonetizationApiClient clientReplying(int status, String body) {
  return HttpMonetizationApiClient(
    baseUrl: 'http://localhost:8000',
    client: MockClient((_) async => http.Response(body, status)),
  );
}

void main() {
  group('Cliente HTTP do serviço de créditos', () {
    test(
      'resposta HTML do proxy vira erro amigável, não FormatException',
      () async {
        final api = clientReplying(502, '<html>Bad Gateway</html>');
        await expectLater(
          api.fetchCatalog(),
          throwsA(
            isA<MonetizationApiException>()
                .having((e) => e.code, 'code', 'HTTP_502')
                .having((e) => e.message, 'message', contains('indisponível')),
          ),
        );
      },
    );

    test('sucesso com corpo que não é objeto JSON é recusado', () async {
      final api = clientReplying(200, '[1,2,3]');
      await expectLater(
        api.fetchCatalog(),
        throwsA(
          isA<MonetizationApiException>().having(
            (e) => e.code,
            'code',
            'BAD_RESPONSE',
          ),
        ),
      );
    });

    test('erro do serviço mantém código e mensagem', () async {
      final api = clientReplying(
        409,
        '{"code":"RESERVATION_ALREADY_CONFIRMED","message":"Reserva já confirmada."}',
      );
      await expectLater(
        api.fetchBalance('mf_w_teste_123'),
        throwsA(
          isA<MonetizationApiException>()
              .having((e) => e.code, 'code', 'RESERVATION_ALREADY_CONFIRMED')
              .having((e) => e.statusCode, 'status', 409),
        ),
      );
    });
  });

  group('Uso de recurso pago', () {
    test(
      'falha ao atualizar o extrato depois de confirmar não vira erro',
      () async {
        final api = FakeMonetizationClient(serverBalance: 12);
        final controller = await onlineController(api: api);
        api.failTransactions = true;

        final result = await controller.executeWithCredits<String>(
          featureId: 'detailed_report',
          action: () async => 'relatorio',
        );

        expect(result, 'relatorio');
        expect(
          api.refundCalls,
          0,
          reason: 'reserva confirmada não é estornada',
        );
        expect(controller.creditBalance, 10);
      },
    );

    test('falha na ação estorna a reserva e repassa o erro', () async {
      final api = FakeMonetizationClient(serverBalance: 12);
      final controller = await onlineController(api: api);

      await expectLater(
        controller.executeWithCredits<String>(
          featureId: 'detailed_report',
          action: () async => throw StateError('falhou'),
        ),
        throwsStateError,
      );

      expect(api.refundCalls, 1);
      expect(controller.creditBalance, 12);
    });
  });
}
