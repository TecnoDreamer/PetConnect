import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_connect/core/network/api_client.dart';
import 'package:pet_connect/features/pet/data/api_pet_qr_repository.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/domain/pet_qr_code.dart';
import 'package:pet_connect/features/pet/domain/pet_qr_repository.dart';

const _deterministico = 'b5ab5677-27c9-3f7c-98f8-370d7fcd526c'; // de 'pet-1'

Pet _pet({String? qrPublicId}) => Pet(
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
      qrPublicId: qrPublicId,
    );

/// Registra as chamadas e responde conforme [responder].
class _Api {
  _Api(this.responder);

  final http.Response Function(http.Request) responder;
  final chamadas = <http.Request>[];

  ApiClient get client => ApiClient(
        baseUrl: 'https://api.test',
        getToken: () async => 'tok',
        httpClient: MockClient((req) async {
          chamadas.add(req);
          return responder(req);
        }),
      );
}

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.collection('Pets').doc('pet-1').set({
      'userId': 'uid-1',
      'nome': 'Rex',
    });
  });

  Future<String?> qrSalvo() async =>
      (await firestore.collection('Pets').doc('pet-1').get())
          .data()?['qrPublicId'] as String?;

  group('modo Firestore (USE_API_QR)', () {
    test('regenera pela rota legada com o QR atual e salva o novo no pet',
        () async {
      final api = _Api((_) => _json(200, {'publicId': 'qr-novo'}));
      final repo = ApiPetQrRepository(api: api.client, firestore: firestore);

      expect(await repo.regenerar(_pet()), 'qr-novo');

      final req = api.chamadas.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/legacy-pets/pet-1/qr/rotation');
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(req.body), {'expectedPublicId': _deterministico});
      expect(await qrSalvo(), 'qr-novo');

      // O pet relido do Firestore já mostra o QR novo.
      final relido = Pet.fromMap('pet-1',
          (await firestore.collection('Pets').doc('pet-1').get()).data()!);
      expect(publicIdDoQr(relido), 'qr-novo');
    });

    test('depois de uma regeneração, manda o qrPublicId salvo como esperado',
        () async {
      final api = _Api((_) => _json(200, {'publicId': 'qr-3'}));
      final repo = ApiPetQrRepository(api: api.client, firestore: firestore);

      await repo.regenerar(_pet(qrPublicId: 'qr-2'));

      expect(
          jsonDecode(api.chamadas.single.body), {'expectedPublicId': 'qr-2'});
    });

    test('409: QR já trocado em outro aparelho — sincroniza com o atual',
        () async {
      final api = _Api((req) => req.method == 'POST'
          ? _json(409, {'code': 'CONFLICT', 'message': 'já trocado'})
          : _json(200, {'publicId': 'qr-de-outro-aparelho'}));
      final repo = ApiPetQrRepository(api: api.client, firestore: firestore);

      await expectLater(
        repo.regenerar(_pet()),
        throwsA(isA<QrRegeneracaoException>()
            .having((e) => e.falha, 'falha', QrFalha.conflito)),
      );
      expect(api.chamadas.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/v1/legacy-pets/pet-1/qr/rotation',
        'GET /api/v1/legacy-pets/pet-1/qr',
      ]);
      expect(await qrSalvo(), 'qr-de-outro-aparelho');
    });

    for (final (status, falha) in [
      (404, QrFalha.naoSincronizado),
      (429, QrFalha.limite),
      (500, QrFalha.desconhecida),
    ]) {
      test('HTTP $status vira $falha e não mexe no pet', () async {
        final api = _Api((_) => _json(status, {'code': 'X', 'message': 'x'}));
        final repo = ApiPetQrRepository(api: api.client, firestore: firestore);

        await expectLater(
          repo.regenerar(_pet()),
          throwsA(isA<QrRegeneracaoException>()
              .having((e) => e.falha, 'falha', falha)),
        );
        expect(await qrSalvo(), isNull);
      });
    }

    test('sem resposta do servidor vira semConexao', () async {
      final api = _Api((_) => throw http.ClientException('offline'));
      final repo = ApiPetQrRepository(api: api.client, firestore: firestore);

      await expectLater(
        repo.regenerar(_pet()),
        throwsA(isA<QrRegeneracaoException>()
            .having((e) => e.falha, 'falha', QrFalha.semConexao)),
      );
      expect(await qrSalvo(), isNull);
    });

    test('API trocou mas o Firestore falhou: naoSalvo, e sincronizar corrige',
        () async {
      await firestore.collection('Pets').doc('pet-1').delete();
      final api = _Api((req) => _json(200, {'publicId': 'qr-novo'}));
      final repo = ApiPetQrRepository(api: api.client, firestore: firestore);

      await expectLater(
        repo.regenerar(_pet()),
        throwsA(isA<QrRegeneracaoException>()
            .having((e) => e.falha, 'falha', QrFalha.naoSalvo)),
      );

      // O documento volta (ex.: rede do Firestore normalizou).
      await firestore.collection('Pets').doc('pet-1').set({'nome': 'Rex'});
      await repo.sincronizar(_pet());
      expect(await qrSalvo(), 'qr-novo');
    });

    test('sincronizar não grava quando o QR já é o atual', () async {
      final api = _Api((_) => _json(200, {'publicId': _deterministico}));
      final repo = ApiPetQrRepository(api: api.client, firestore: firestore);

      await repo.sincronizar(_pet());

      expect(await qrSalvo(), isNull);
    });
  });

  group('modo API (USE_API_PETS)', () {
    test('regenera pela rota do id da API e não toca no Firestore', () async {
      final api = _Api((_) => _json(200, {'publicId': 'qr-novo'}));
      final repo = ApiPetQrRepository(api: api.client);

      expect(await repo.regenerar(_pet(qrPublicId: 'qr-api')), 'qr-novo');

      final req = api.chamadas.single;
      expect(req.url.path, '/api/v1/pets/pet-1/qr/rotation');
      expect(jsonDecode(req.body), {'expectedPublicId': 'qr-api'});
      expect(await qrSalvo(), isNull);
    });
  });

  test('sem API configurada, regeneração indisponível', () async {
    const repo = QrRegeneracaoIndisponivel();
    expect(repo.suportaRegeneracao, isFalse);
    await expectLater(
      repo.regenerar(_pet()),
      throwsA(isA<QrRegeneracaoException>()
          .having((e) => e.falha, 'falha', QrFalha.indisponivel)),
    );
  });
}
