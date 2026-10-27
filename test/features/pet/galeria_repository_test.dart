// Galeria de fotos por pet: FirebaseGaleriaRepository e exclusão em cascata
// (docs/features/galeria-fotos-pet.md).
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/network/api_exception.dart';
import 'package:pet_connect/features/pet/data/firebase_galeria_repository.dart';
import 'package:pet_connect/features/pet/data/firebase_pet_repository.dart';
import 'package:pet_connect/features/pet/domain/foto_pet.dart';
import 'package:pet_connect/features/pet/domain/galeria_repository.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';

import 'fake_anexo_repository.dart';

const _dono = 'uid-ana';
final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

Pet _pet(String id) => Pet(
      id: id,
      userId: _dono,
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

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeAnexoRepository arquivos;
  late FirebaseGaleriaRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    arquivos = FakeAnexoRepository();
    repo = FirebaseGaleriaRepository(firestore: firestore, arquivos: arquivos);
  });

  CollectionReference<Map<String, dynamic>> fotosDe(String petId) =>
      firestore.collection('Pets').doc(petId).collection('fotos');

  /// Grava direto, com horário controlado, para testar ordem e páginas.
  Future<void> semear(String petId, int quantas,
      {String? petIdNoRegistro}) async {
    for (var i = 0; i < quantas; i++) {
      await fotosDe(petId).doc('f${i.toString().padLeft(3, '0')}').set({
        'petId': petIdNoRegistro ?? petId,
        'userId': _dono,
        'url': 'https://res.cloudinary.com/demo/image/upload/v1/f$i.jpg',
        'publicId': 'f$i',
        'criadoEm': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 0, i)),
      });
    }
  }

  group('publicar', () {
    test('envia o arquivo e grava o registro com o vínculo ao pet', () async {
      final progresso = <double>[];
      final foto = await repo.publicar(
        pet: _pet('pet-1'),
        userId: _dono,
        bytes: _jpeg,
        legenda: '  Na praia  ',
        aoProgredir: progresso.add,
      );

      expect(arquivos.enviadas, hasLength(1));
      expect(progresso.last, 1);
      final doc = await fotosDe('pet-1').doc(foto.id).get();
      final dados = doc.data()!;
      expect(dados['petId'], 'pet-1');
      expect(dados['userId'], _dono);
      expect(dados['url'], arquivos.enviadas.single);
      expect(dados['publicId'], 'users/u/foto1');
      expect(dados['legenda'], 'Na praia');
      expect(dados['largura'], 800);
      expect(dados['criadoEm'], isA<Timestamp>());
      expect(foto.legenda, 'Na praia');
    });

    test('legenda vazia não é gravada', () async {
      final foto = await repo.publicar(
          pet: _pet('pet-1'), userId: _dono, bytes: _jpeg, legenda: '   ');
      final dados = (await fotosDe('pet-1').doc(foto.id).get()).data()!;
      expect(dados.containsKey('legenda'), isFalse);
    });

    test('falha no envio: nada é gravado', () async {
      arquivos.falharEnvio = Exception('sem rede');
      await expectLater(
        repo.publicar(pet: _pet('pet-1'), userId: _dono, bytes: _jpeg),
        throwsException,
      );
      expect((await fotosDe('pet-1').get()).docs, isEmpty);
    });

    test('registro recusado: o arquivo enviado é removido e o erro sobe',
        () async {
      firestore = FakeFirebaseFirestore(securityRules: '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read;
    }
  }
}''');
      repo =
          FirebaseGaleriaRepository(firestore: firestore, arquivos: arquivos);

      await expectLater(
        repo.publicar(pet: _pet('pet-1'), userId: _dono, bytes: _jpeg),
        throwsA(anything),
      );
      expect(arquivos.excluidas, arquivos.enviadas);
      expect((await fotosDe('pet-1').get()).docs, isEmpty);
    });
  });

  group('listar', () {
    test('mais recentes primeiro, em páginas, sem repetir nem pular', () async {
      await semear('pet-1', 7);

      final primeira = await repo.listar('pet-1', limite: 3);
      expect(primeira.fotos.map((f) => f.id), ['f006', 'f005', 'f004']);
      expect(primeira.temMais, isTrue);

      final segunda =
          await repo.listar('pet-1', limite: 3, depoisDe: primeira.fotos.last);
      expect(segunda.fotos.map((f) => f.id), ['f003', 'f002', 'f001']);
      expect(segunda.temMais, isTrue);

      final terceira =
          await repo.listar('pet-1', limite: 3, depoisDe: segunda.fotos.last);
      expect(terceira.fotos.map((f) => f.id), ['f000']);
      expect(terceira.temMais, isFalse);
    });

    // A ordem exata no empate (pelo id) vem do Firestore real; o fake
    // mantém a ordem de inserção. O que se testa aqui é o cursor por
    // documento: nenhuma foto repete nem some entre as páginas.
    test('empate de horário: nenhuma foto repete nem some entre páginas',
        () async {
      for (final id in ['a', 'c', 'b']) {
        await fotosDe('pet-1').doc(id).set({
          'petId': 'pet-1',
          'userId': _dono,
          'url': 'https://res.cloudinary.com/demo/image/upload/v1/$id.jpg',
          'publicId': id,
          'criadoEm': Timestamp.fromDate(DateTime.utc(2026)),
        });
      }
      final pagina = await repo.listar('pet-1', limite: 2);
      final resto =
          await repo.listar('pet-1', limite: 2, depoisDe: pagina.fotos.last);
      final ids = [...pagina.fotos, ...resto.fotos].map((f) => f.id).toList();
      expect(ids, unorderedEquals(['a', 'b', 'c']));
      expect(resto.temMais, isFalse);
    });

    test('pet sem fotos: lista vazia', () async {
      final pagina = await repo.listar('pet-sem-fotos');
      expect(pagina.fotos, isEmpty);
      expect(pagina.temMais, isFalse);
    });

    test('cada pet só vê as próprias fotos', () async {
      await semear('pet-1', 2);
      await semear('pet-2', 3);
      // Registro gravado no pet errado (ferramenta externa, versão antiga).
      await fotosDe('pet-1').doc('intrusa').set({
        'petId': 'pet-2',
        'userId': _dono,
        'url': 'https://res.cloudinary.com/demo/image/upload/v1/x.jpg',
        'publicId': 'x',
        'criadoEm': Timestamp.fromDate(DateTime.utc(2027)),
      });

      final doPet1 = await repo.listar('pet-1');
      final doPet2 = await repo.listar('pet-2');
      expect(doPet1.fotos.map((f) => f.petId).toSet(), {'pet-1'});
      expect(doPet1.fotos, hasLength(2));
      expect(doPet2.fotos, hasLength(3));
    });
  });

  group('excluir', () {
    late FotoPet foto;

    setUp(() async {
      foto =
          await repo.publicar(pet: _pet('pet-1'), userId: _dono, bytes: _jpeg);
    });

    Future<bool> existe() async =>
        (await fotosDe('pet-1').doc(foto.id).get()).exists;

    test('remove o arquivo e depois o registro', () async {
      await repo.excluir(foto);
      expect(arquivos.excluidas, [foto.url]);
      expect(await existe(), isFalse);
    });

    test('falha ao remover o arquivo: o registro fica e dá para repetir',
        () async {
      arquivos.falharExclusao = Exception('sem rede');
      await expectLater(repo.excluir(foto), throwsA(isA<FalhaAoExcluirFoto>()));
      expect(await existe(), isTrue);

      arquivos.falharExclusao = null;
      await repo.excluir(foto);
      expect(await existe(), isFalse);
      // Repetir depois de excluído não quebra.
      await repo.excluir(foto);
    });

    test('arquivo fora da pasta do tutor na API (404): remove o registro',
        () async {
      arquivos.falharExclusao = const ApiException(
          status: 404, code: 'RESOURCE_NOT_FOUND', message: 'não encontrado');
      await repo.excluir(foto);
      expect(await existe(), isFalse);
    });

    test('outro erro da API: mantém o registro', () async {
      arquivos.falharExclusao = const ApiException(
          status: 503, code: 'UPLOAD_NOT_CONFIGURED', message: 'indisponível');
      await expectLater(repo.excluir(foto), throwsA(isA<FalhaAoExcluirFoto>()));
      expect(await existe(), isTrue);
    });
  });

  test('excluir o pet apaga os registros da galeria dele, não os de outro',
      () async {
    await firestore.collection('Pets').doc('pet-1').set({'userId': _dono});
    await firestore.collection('Pets').doc('pet-2').set({'userId': _dono});
    await semear('pet-1', 3);
    await semear('pet-2', 2);

    await FirebasePetRepository(firestore: firestore).deletePet('pet-1');

    expect((await fotosDe('pet-1').get()).docs, isEmpty);
    expect((await fotosDe('pet-2').get()).docs, hasLength(2));
  });
}
