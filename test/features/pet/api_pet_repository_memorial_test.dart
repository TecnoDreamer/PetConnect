// Memorial do Pet no modo API (USE_API_PETS): desligado de propósito, porque
// a página pública do QR exibiria o status DECEASED (ver
// docs/features/memorial-pet.md, "Fonte de dados").
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_connect/core/network/api_client.dart';
import 'package:pet_connect/features/pet/data/api_pet_repository.dart';
import 'package:pet_connect/features/pet/domain/alteracao_situacao.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';

class _AuthSemUsuario implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<http.BaseRequest> requisicoes;
  late ApiPetRepository repo;

  setUp(() {
    requisicoes = [];
    final api = ApiClient(
      baseUrl: 'http://api.test',
      getToken: () async => 'token',
      httpClient: MockClient((req) async {
        requisicoes.add(req);
        return http.Response(
          jsonEncode([
            {'id': 'p1', 'name': 'Rex', 'species': 'DOG', 'status': 'ACTIVE'},
            {'id': 'p2', 'name': 'Mel', 'species': 'CAT', 'status': 'DECEASED'},
            {'id': 'p3', 'name': 'Bolt', 'species': 'DOG', 'status': 'LOST'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    repo = ApiPetRepository(auth: _AuthSemUsuario(), api: api);
  });

  test('lê DECEASED como falecido; os demais status continuam ativos',
      () async {
    final pets = await repo.watchPets('uid').first;
    final porNome = {for (final p in pets) p.nome: p.situacao};

    expect(porNome['Mel'], SituacaoPet.falecido);
    expect(porNome['Rex'], SituacaoPet.ativo);
    expect(porNome['Bolt'], SituacaoPet.ativo);
  });

  test('não registra falecimento nem chama a API', () async {
    expect(repo.suportaMemorial, isFalse);
    await expectLater(
      repo.alterarSituacao('p1', AlteracaoDeSituacao.registrarFalecimento(),
          atorId: 'uid'),
      throwsA(isA<MemorialNaoSuportadoException>()),
    );
    expect(requisicoes, isEmpty);
  });
}
