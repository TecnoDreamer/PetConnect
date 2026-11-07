import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_connect/core/network/api_client.dart';
import 'package:pet_connect/features/pet/data/api_compartilhamento_repository.dart';
import 'package:pet_connect/features/pet/domain/compartilhamento_publico.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';

const _pet = Pet(
  id: 'pet-1',
  userId: 'uid-1',
  nome: 'Rex',
  especie: 'Cachorro',
  raca: '',
  cor: '',
  genero: '',
  porte: '',
  peso: '',
  dataNascimento: '',
  vacinado: false,
);

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

const _ativo = {
  'enabled': true,
  'active': true,
  'fields': ['PET_NAME', 'CONTACT_PHONE', 'CAMPO_FUTURO'],
  'contactPhone': '+5519999990000',
  'consentAcceptedAt': '2026-11-02T21:00:00Z',
  'consentVersion': '2026-11-02',
  'currentConsentVersion': '2026-11-02',
};

void main() {
  late List<http.Request> chamadas;

  ApiCompartilhamentoRepository repo(
    http.Response Function(http.Request) responder, {
    bool porIdDoFirestore = true,
  }) {
    chamadas = [];
    return ApiCompartilhamentoRepository(
      porIdDoFirestore: porIdDoFirestore,
      api: ApiClient(
        baseUrl: 'https://api.test',
        getToken: () async => 'tok',
        httpClient: MockClient((req) async {
          chamadas.add(req);
          return responder(req);
        }),
      ),
    );
  }

  test('busca pela rota do Firestore e lê os campos conhecidos', () async {
    final r = repo((_) => _json(200, _ativo));
    final c = await r.buscar(_pet);

    expect(chamadas.single.method, 'GET');
    expect(
        chamadas.single.url.path, '/api/v1/legacy-pets/pet-1/public-sharing');
    expect(chamadas.single.headers['Authorization'], 'Bearer tok');
    expect(c.ativo, isTrue);
    // Campo que esta versão do app não conhece é ignorado.
    expect(c.campos, {CampoPublico.nomePet, CampoPublico.telefone});
    expect(c.telefone, '+5519999990000');
    expect(c.consentidoEm, DateTime.utc(2026, 11, 2, 21).toLocal());
  });

  test('com pets na API usa /pets/{id}', () async {
    final r = repo((_) => _json(200, _ativo), porIdDoFirestore: false);
    await r.buscar(_pet);
    expect(chamadas.single.url.path, '/api/v1/pets/pet-1/public-sharing');
  });

  test('publicar manda o consentimento, a versão e só os dados marcados',
      () async {
    final r = repo((_) => _json(200, _ativo));
    await r.publicar(
      _pet,
      const PedidoDeCompartilhamento(
        campos: {CampoPublico.telefone, CampoPublico.nomePet},
        nomeTutor: 'Ana',
        telefone: '+5519999990000',
      ),
    );

    expect(chamadas.single.method, 'PUT');
    expect(jsonDecode(chamadas.single.body), {
      'enabled': true,
      'consentAccepted': true,
      'consentVersion': versaoDoConsentimento,
      'fields': ['PET_NAME', 'CONTACT_PHONE'],
      // Nome do tutor não marcado: não vai para a API.
      'contactPhone': '+5519999990000',
    });
  });

  test('revogar manda só enabled: false', () async {
    final r = repo((_) => _json(200, {'enabled': false, 'active': false}));
    final c = await r.revogar(_pet);
    expect(jsonDecode(chamadas.single.body), {'enabled': false});
    expect(c.ativado, isFalse);
    expect(c.campos, isEmpty);
  });

  group('erros da API viram falhas que a tela explica', () {
    final casos = {
      _json(400, {'code': 'BAD_REQUEST', 'message': 'Telefone inválido.'}):
          FalhaDoCompartilhamento.dadosInvalidos,
      _json(404, {'code': 'RESOURCE_NOT_FOUND'}):
          FalhaDoCompartilhamento.petNaoEncontrado,
      _json(409, {'code': 'PET_IN_MEMORIAL'}): FalhaDoCompartilhamento.memorial,
      _json(409, {'code': 'CONSENT_VERSION_OUTDATED'}):
          FalhaDoCompartilhamento.textoDesatualizado,
      _json(503, {'code': 'SERVICE_UNAVAILABLE'}):
          FalhaDoCompartilhamento.servidorIndisponivel,
      _json(500, {'code': 'INTERNAL_ERROR'}):
          FalhaDoCompartilhamento.desconhecida,
    };
    casos.forEach((resposta, falha) {
      test('${resposta.statusCode} → $falha', () async {
        final r = repo((_) => resposta);
        await expectLater(
          r.buscar(_pet),
          throwsA(isA<CompartilhamentoException>()
              .having((e) => e.falha, 'falha', falha)),
        );
      });
    });

    test('400 mostra a mensagem da API', () async {
      final r = repo((_) =>
          _json(400, {'code': 'BAD_REQUEST', 'message': 'Telefone inválido.'}));
      await expectLater(
        r.buscar(_pet),
        throwsA(isA<CompartilhamentoException>()
            .having((e) => e.mensagem, 'mensagem', 'Telefone inválido.')),
      );
    });

    test('sem rede → semConexao', () async {
      final r = repo((_) => throw http.ClientException('offline'));
      await expectLater(
        r.buscar(_pet),
        throwsA(isA<CompartilhamentoException>().having(
            (e) => e.falha, 'falha', FalhaDoCompartilhamento.semConexao)),
      );
    });
  });
}
