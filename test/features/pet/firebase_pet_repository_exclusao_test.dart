// Exclusão de um pet no modo Firestore (LGPD, RF09/RNF13): cascata nas
// subcoleções do pet. Ver docs/security/firestore-isolamento-por-dono.md.
//
// O fake_cloud_firestore apaga as subcoleções junto com o documento pai; o
// Firestore real não. Por isso a cascata é verificada com o `delete` do pet
// falhando: o que sumiu antes dele foi apagado pelo app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:pet_connect/features/pet/data/exclusao_de_pet.dart';
import 'package:pet_connect/features/pet/data/firebase_pet_repository.dart';

Future<int> _contar(FakeFirebaseFirestore db, String caminho) async =>
    (await db.collection(caminho).get()).docs.length;

void main() {
  late FakeFirebaseFirestore db;
  late FirebasePetRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FirebasePetRepository(firestore: db);

    await db.collection('Pets').doc('rex').set({'userId': 'ana'});
    await db
        .collection('Pets')
        .doc('mel')
        .set({'userId': 'ana', 'situacao': 'FALECIDO'});
    for (final petId in ['rex', 'mel']) {
      for (final sub in subcolecoesApagadasComOPet) {
        await db.collection('Pets/$petId/$sub').add({'nota': 'x'});
        await db.collection('Pets/$petId/$sub').add({'nota': 'y'});
      }
      await db.collection('Pets/$petId/eventosSituacao').add({'atorId': 'ana'});
    }
  });

  test('apaga as subcoleções e o pet, inclusive falecido', () async {
    await repo.deletePet('mel');

    for (final sub in subcolecoesApagadasComOPet) {
      expect(await _contar(db, 'Pets/mel/$sub'), 0,
          reason: 'Pets/mel/$sub ficou órfã');
    }
    expect((await db.doc('Pets/mel').get()).exists, isFalse);
  });

  test('apaga cada subcoleção antes do pet e não toca em eventosSituacao',
      () async {
    final erro = FirebaseException(plugin: 'cloud_firestore', code: 'teste');
    whenCalling(Invocation.method(#delete, null))
        .on(db.doc('Pets/rex'))
        .thenThrow(erro);

    await expectLater(repo.deletePet('rex'), throwsA(erro));

    expect((await db.doc('Pets/rex').get()).exists, isTrue);
    for (final sub in subcolecoesApagadasComOPet) {
      expect(await _contar(db, 'Pets/rex/$sub'), 0,
          reason: 'Pets/rex/$sub não foi apagada antes do pet');
    }
    // Retidos: a regra nega delete (decisão pendente do proprietário).
    expect(await _contar(db, 'Pets/rex/eventosSituacao'), 1);
  });

  test('não toca em outro pet', () async {
    await repo.deletePet('rex');

    expect((await db.doc('Pets/mel').get()).exists, isTrue);
    for (final sub in subcolecoesApagadasComOPet) {
      expect(await _contar(db, 'Pets/mel/$sub'), 2);
    }
    expect(await _contar(db, 'Pets/mel/eventosSituacao'), 1);
  });
}
