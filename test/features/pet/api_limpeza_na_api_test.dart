import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_connect/core/network/api_client.dart';
import 'package:pet_connect/features/pet/data/api_limpeza_na_api.dart';
import 'package:pet_connect/features/pet/domain/limpeza_na_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Limpeza na API do que ela guarda de um pet do Firestore excluído (LGPD).
void main() {
  late SharedPreferences prefs;
  late List<String> pedidos;
  late http.Response Function(http.Request req) responder;
  String? uid = 'uid-a';

  ApiLimpezaNaApi limpeza({Duration limite = const Duration(seconds: 8)}) {
    final api = ApiClient(
      baseUrl: 'http://api.test',
      getToken: () async => 'tok',
      httpClient: MockClient((req) async {
        pedidos.add('${req.method} ${req.url.path}');
        return responder(req);
      }),
    );
    return ApiLimpezaNaApi(
        api: api, prefs: prefs, uidAtual: () => uid, limite: limite);
  }

  List<String>? pendentes(String dono) =>
      prefs.getStringList(ApiLimpezaNaApi.chave(dono));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    pedidos = [];
    responder = (_) => http.Response('', 204);
    uid = 'uid-a';
  });

  group('antes de excluir o pet', () {
    test('pede a exclusão dos dados do QR pelo id do Firestore', () async {
      final r = await limpeza().antesDeExcluirPet('pet-1');

      expect(r, ResultadoDaLimpeza.apagado);
      expect(pedidos, ['DELETE /api/v1/legacy-pets/pet-1/qr-data']);
      expect(pendentes('uid-a'), isNull);
    });

    test('API fora: guarda o pedido para repetir, sem travar', () async {
      responder = (_) => throw const SocketExceptionFake();

      final r = await limpeza().antesDeExcluirPet('pet-1');

      expect(r, ResultadoDaLimpeza.apiInacessivel);
      expect(pendentes('uid-a'), ['pet-1']);
    });

    test('servidor com erro 503 também fica para depois', () async {
      responder = (_) => http.Response('{"code":"SERVICE_UNAVAILABLE"}', 503);

      await limpeza().antesDeExcluirPet('pet-1');
      await limpeza().antesDeExcluirPet('pet-1');

      expect(pendentes('uid-a'), ['pet-1']);
    });

    test('API acordando além do prazo conta como fora', () async {
      final demora = Completer<void>();
      final api = ApiClient(
        baseUrl: 'http://api.test',
        getToken: () async => 'tok',
        httpClient: MockClient((req) async {
          await demora.future;
          return http.Response('', 204);
        }),
      );
      final l = ApiLimpezaNaApi(
          api: api,
          prefs: prefs,
          uidAtual: () => uid,
          limite: const Duration(milliseconds: 20));

      final r = await l.antesDeExcluirPet('pet-1');
      demora.complete();

      expect(r, ResultadoDaLimpeza.apiInacessivel);
      expect(pendentes('uid-a'), ['pet-1']);
    });

    test('API sem a rota (versão anterior): desliga a página pública',
        () async {
      responder = (req) => req.method == 'DELETE'
          ? http.Response('{"code":"RESOURCE_NOT_FOUND"}', 404)
          : http.Response('{"enabled":false}', 200);

      final r = await limpeza().antesDeExcluirPet('pet-1');

      expect(r, ResultadoDaLimpeza.recusado);
      expect(pedidos, [
        'DELETE /api/v1/legacy-pets/pet-1/qr-data',
        'PUT /api/v1/legacy-pets/pet-1/public-sharing',
      ]);
      // Recusa não se resolve repetindo.
      expect(pendentes('uid-a'), isNull);
    });

    test('sem guardar quando pedido (exclusão de conta)', () async {
      responder = (_) => throw const SocketExceptionFake();

      await limpeza().antesDeExcluirPet('pet-1', guardarSeFalhar: false);

      expect(pendentes('uid-a'), isNull);
    });
  });

  group('pedidos guardados', () {
    test('a próxima abertura repete e tira da lista o que a API aceitou',
        () async {
      await prefs.setStringList(ApiLimpezaNaApi.chave('uid-a'), ['p1', 'p2']);
      responder = (req) => req.url.path.contains('p2')
          ? http.Response('', 503)
          : http.Response('', 204);

      await limpeza().retomarPendentes();

      expect(pedidos, [
        'DELETE /api/v1/legacy-pets/p1/qr-data',
        'DELETE /api/v1/legacy-pets/p2/qr-data',
      ]);
      expect(pendentes('uid-a'), ['p2']);

      responder = (_) => http.Response('', 204);
      await limpeza().retomarPendentes();
      expect(pendentes('uid-a'), isNull);
    });

    test('só repete os pedidos da conta logada', () async {
      await prefs.setStringList(ApiLimpezaNaApi.chave('uid-b'), ['p-b']);

      await limpeza().retomarPendentes();

      expect(pedidos, isEmpty);
      expect(pendentes('uid-b'), ['p-b']);
    });

    test('sem sessão não faz nada', () async {
      await prefs.setStringList(ApiLimpezaNaApi.chave('uid-a'), ['p1']);
      uid = null;

      await limpeza().retomarPendentes();

      expect(pedidos, isEmpty);
    });
  });

  group('exclusão da conta', () {
    test('DELETE /me confirmado limpa os pedidos guardados', () async {
      await prefs.setStringList(ApiLimpezaNaApi.chave('uid-a'), ['p1']);

      expect(await limpeza().excluirConta(), isTrue);
      expect(pedidos, ['DELETE /api/v1/me']);
      expect(pendentes('uid-a'), isNull);
    });

    test('API fora devolve falso sem lançar', () async {
      responder = (_) => throw const SocketExceptionFake();

      expect(await limpeza().excluirConta(), isFalse);
    });
  });
}

/// Falha de transporte, como sem rede: o cliente da API vira `NETWORK`.
class SocketExceptionFake implements Exception {
  const SocketExceptionFake();
}
