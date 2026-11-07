import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_connect/core/network/api_client.dart';
import 'package:pet_connect/core/network/api_exception.dart';

void main() {
  ApiClient clientReturning(http.Response Function(http.Request req) handler,
      {Future<String?> Function()? getToken}) {
    return ApiClient(
      baseUrl: 'http://api.test',
      getToken: getToken ?? () async => 'fake-token',
      httpClient: MockClient((req) async => handler(req)),
    );
  }

  test('GET prefixa /api/v1 e envia o Bearer token', () async {
    late http.Request captured;
    final api = clientReturning((req) {
      captured = req;
      return http.Response(jsonEncode({'ok': true}), 200,
          headers: {'content-type': 'application/json'});
    });

    final body = await api.get('/me');

    expect(captured.url.toString(), 'http://api.test/api/v1/me');
    expect(captured.headers['Authorization'], 'Bearer fake-token');
    expect(body['ok'], true);
  });

  test('sem token não manda header Authorization', () async {
    late http.Request captured;
    final api = clientReturning(
      (req) {
        captured = req;
        return http.Response('{}', 200);
      },
      getToken: () async => null,
    );

    await api.get('/me');

    expect(captured.headers.containsKey('Authorization'), false);
  });

  test('resposta de erro com envelope vira ApiException com code/message',
      () async {
    final api = clientReturning((req) => http.Response(
          jsonEncode({
            'timestamp': '2026-09-10T00:00:00Z',
            'status': 404,
            'code': 'RESOURCE_NOT_FOUND',
            'message': 'Usuário não encontrado.',
          }),
          404,
          headers: {'content-type': 'application/json'},
        ));

    final e = await api
        .get('/me')
        .then<ApiException?>((_) => null)
        .catchError((err) => err as ApiException);

    expect(e, isA<ApiException>());
    expect(e!.status, 404);
    expect(e.code, 'RESOURCE_NOT_FOUND');
    expect(e.isNotFound, true);
    expect(e.message, 'Usuário não encontrado.');
  });

  test('401 é detectado por isUnauthorized', () async {
    final api = clientReturning((req) => http.Response(
        jsonEncode({'code': 'UNAUTHENTICATED', 'message': 'x'}), 401,
        headers: {'content-type': 'application/json'}));

    try {
      await api.patch('/me', {'firstName': 'x'});
      fail('deveria ter lançado');
    } on ApiException catch (e) {
      expect(e.isUnauthorized, true);
    }
  });

  test('falha de transporte vira ApiException NETWORK', () async {
    final api = ApiClient(
      baseUrl: 'http://api.test',
      getToken: () async => null,
      httpClient:
          MockClient((req) => Future.error(const SocketExceptionLike())),
    );

    try {
      await api.get('/me');
      fail('deveria ter lançado');
    } on ApiException catch (e) {
      expect(e.code, 'NETWORK');
      expect(e.isNetwork, true);
      expect(e.status, 0);
    }
  });

  test('204/corpo vazio retorna mapa vazio', () async {
    final api = clientReturning((req) => http.Response('', 204));
    final body = await api.get('/me');
    expect(body, isEmpty);
  });

  // Nova tentativa e conexões novas: no Android, a rede do app é cortada em
  // segundo plano e a primeira chamada na volta dava "Sem conexão".
  group('falha de rede', () {
    ApiClient comFalhas(List<Object> respostas,
        {Duration timeout = const Duration(seconds: 5)}) {
      return ApiClient(
        baseUrl: 'http://api.test',
        getToken: () async => 'fake-token',
        httpClient: _Cliente(respostas),
        timeout: timeout,
        pausaEntreTentativas: Duration.zero,
      );
    }

    test('GET repete uma vez e funciona na segunda', () async {
      final cliente = _Cliente([const SocketExceptionLike(), _ok]);
      final api = ApiClient(
        baseUrl: 'http://api.test',
        getToken: () async => null,
        httpClient: cliente,
        pausaEntreTentativas: Duration.zero,
      );

      expect(await api.get('/me'), {'ok': true});
      expect(cliente.chamadas, 2);
    });

    test('duas falhas viram NETWORK, com duas chamadas só', () async {
      final cliente = _Cliente(
          [const SocketExceptionLike(), const SocketExceptionLike(), _ok]);
      final api = ApiClient(
        baseUrl: 'http://api.test',
        getToken: () async => null,
        httpClient: cliente,
        pausaEntreTentativas: Duration.zero,
      );

      await expectLater(
          api.get('/me'),
          throwsA(isA<ApiException>()
              .having((e) => e.isNetwork, 'isNetwork', true)));
      expect(cliente.chamadas, 2);
    });

    test('PUT e DELETE repetem; POST e PATCH não', () async {
      for (final (metodo, repete) in [
        ('PUT', true),
        ('DELETE', true),
        ('POST', false),
        ('PATCH', false),
      ]) {
        final cliente = _Cliente([const SocketExceptionLike(), _ok]);
        final api = ApiClient(
          baseUrl: 'http://api.test',
          getToken: () async => null,
          httpClient: cliente,
          pausaEntreTentativas: Duration.zero,
        );
        final chamada = switch (metodo) {
          'PUT' => api.put('/x', {}),
          'DELETE' => api.delete('/x'),
          'POST' => api.post('/x', {}),
          _ => api.patch('/x', {}),
        };

        if (repete) {
          await chamada;
        } else {
          await expectLater(chamada, throwsA(isA<ApiException>()));
        }
        expect(cliente.chamadas, repete ? 2 : 1, reason: metodo);
      }
    });

    test('erro HTTP da API não repete', () async {
      for (final status in [404, 409, 500]) {
        final cliente = _Cliente([
          http.Response('{"code":"X","message":"m"}', status),
          _ok,
        ]);
        final api = ApiClient(
          baseUrl: 'http://api.test',
          getToken: () async => null,
          httpClient: cliente,
          pausaEntreTentativas: Duration.zero,
        );

        await expectLater(
            api.get('/me'),
            throwsA(
                isA<ApiException>().having((e) => e.status, 'status', status)));
        expect(cliente.chamadas, 1, reason: 'HTTP $status');
      }
    });

    test('tempo esgotado também ganha a segunda tentativa', () async {
      final cliente = _Cliente([_nuncaResponde, _ok]);
      final api = ApiClient(
        baseUrl: 'http://api.test',
        getToken: () async => null,
        httpClient: cliente,
        timeout: const Duration(milliseconds: 40),
        pausaEntreTentativas: Duration.zero,
      );

      expect(await api.get('/me'), {'ok': true});
      expect(cliente.chamadas, 2);
    });

    test('tempo esgotado nas duas vira NETWORK com a mensagem do tempo',
        () async {
      final api = ApiClient(
        baseUrl: 'http://api.test',
        getToken: () async => null,
        httpClient: _Cliente([_nuncaResponde, _nuncaResponde]),
        timeout: const Duration(milliseconds: 40),
        pausaEntreTentativas: Duration.zero,
      );

      await expectLater(
          api.get('/me'),
          throwsA(isA<ApiException>()
              .having((e) => e.isNetwork, 'isNetwork', true)
              .having((e) => e.message, 'message', contains('Tempo'))));
    });

    test('a nova tentativa usa uma conexão nova e fecha a antiga', () async {
      final criados = <_Cliente>[];
      final roteiros = [
        [const SocketExceptionLike()],
        [_ok],
      ];
      final api = ApiClient(
        baseUrl: 'http://api.test',
        getToken: () async => null,
        criarCliente: () {
          final c = _Cliente(roteiros[criados.length]);
          criados.add(c);
          return c;
        },
        pausaEntreTentativas: Duration.zero,
      );

      expect(await api.get('/me'), {'ok': true});

      expect(criados, hasLength(2));
      expect(criados[0].fechado, isTrue, reason: 'a conexão que falhou fecha');
      expect(criados[1].fechado, isFalse);
    });

    test('descartarConexoesAntigas troca a conexão e fecha a antiga', () async {
      final criados = <_Cliente>[];
      final api = ApiClient(
        baseUrl: 'http://api.test',
        getToken: () async => null,
        criarCliente: () {
          final c = _Cliente([_ok]);
          criados.add(c);
          return c;
        },
      );
      expect(criados, hasLength(1));

      api.descartarConexoesAntigas();
      await api.get('/me');

      expect(criados, hasLength(2));
      expect(criados[0].fechado, isTrue);
      expect(criados[0].chamadas, 0, reason: 'a chamada foi na conexão nova');
      expect(criados[1].chamadas, 1);
    });

    test('com chamada em andamento, a conexão antiga só fecha depois dela',
        () async {
      final solta = Completer<void>();
      final criados = <_Cliente>[];
      final api = ApiClient(
        baseUrl: 'http://api.test',
        getToken: () async => null,
        criarCliente: () {
          final c = _Cliente(criados.isEmpty ? [_ok] : [_ok])
            ..seguraAte = criados.isEmpty ? solta.future : null;
          criados.add(c);
          return c;
        },
      );

      final emAndamento = api.get('/me');
      await Future<void>.delayed(Duration.zero);
      api.descartarConexoesAntigas();
      expect(criados[0].fechado, isFalse,
          reason: 'a chamada em andamento ainda usa esta conexão');

      solta.complete();
      expect(await emAndamento, {'ok': true});
      expect(criados[0].fechado, isTrue);
    });

    test('close fecha o cliente', () async {
      final cliente = _Cliente([_ok]);
      ApiClient(
        baseUrl: 'http://api.test',
        getToken: () async => null,
        httpClient: cliente,
      ).close();
      expect(cliente.fechado, isTrue);
    });

    test('o log leva o tipo do erro e a rota sem ids, nunca token nem query',
        () async {
      final linhas = <String>[];
      final original = debugPrint;
      debugPrint = (mensagem, {wrapWidth}) => linhas.add(mensagem ?? '');
      addTearDown(() => debugPrint = original);

      final api =
          comFalhas([const SocketExceptionLike(), const SocketExceptionLike()]);
      await expectLater(
          api.get('/legacy-pets/G58iMXlRw7jbach4qZMX/public-sharing?x=1'),
          throwsA(isA<ApiException>()));

      expect(linhas, hasLength(2));
      expect(
          linhas.first,
          'API: falha de rede em GET /legacy-pets/:id/public-sharing '
          '(SocketExceptionLike), tentativa 1 de 2.');
      final tudo = linhas.join('\n');
      expect(tudo, isNot(contains('G58i')));
      expect(tudo, isNot(contains('fake-token')));
      expect(tudo, isNot(contains('x=1')));
    });

    test('rotaParaLog troca os identificadores por :id', () {
      expect(ApiClient.rotaParaLog('/me/push-devices'), '/me/push-devices');
      expect(
          ApiClient.rotaParaLog('/pets/66f0a1b2c3d4e5f607182930/qr/rotation'),
          '/pets/:id/qr/rotation');
      expect(ApiClient.rotaParaLog('/legacy-pets/G58iMXlRw7jbach4qZMX/qr'),
          '/legacy-pets/:id/qr');
      expect(ApiClient.rotaParaLog('/me?token=abc'), '/me');
    });
  });
}

final _ok = http.Response('{"ok":true}', 200,
    headers: {'content-type': 'application/json'});

/// Marca uma chamada que nunca responde (para o tempo esgotar).
final _nuncaResponde = Completer<http.Response>();

/// Cliente de teste com um roteiro: cada chamada consome o próximo item, que
/// é uma exceção (falha), uma resposta ou um [Completer] que nunca termina.
class _Cliente extends http.BaseClient {
  _Cliente(List<Object> roteiro) : _roteiro = List.of(roteiro);

  final List<Object> _roteiro;
  int chamadas = 0;
  bool fechado = false;

  /// Segura as respostas até este futuro terminar.
  Future<void>? seguraAte;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    chamadas++;
    final item = _roteiro.removeAt(0);
    if (seguraAte != null) await seguraAte;
    if (item is Completer) await item.future;
    if (item is Exception) throw item;
    final resposta = item as http.Response;
    return http.StreamedResponse(
        Stream.value(resposta.bodyBytes), resposta.statusCode,
        headers: resposta.headers);
  }

  @override
  void close() => fechado = true;
}

/// Exceção qualquer para simular falha de rede no MockClient.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
