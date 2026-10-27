// Exclusão de conta no modo Firestore (LGPD, RF09/RNF13): cascata nas
// subcoleções de cada pet. Ver docs/security/firestore-isolamento-por-dono.md.
//
// O fake_cloud_firestore apaga as subcoleções junto com o documento pai; o
// Firestore real não. Por isso a cascata é verificada com um `delete`
// falhando no meio: o que sumiu antes dele foi apagado pelo app. (O lote do
// fake é aplicado em ordem e não é atômico; o do Firestore real é.)

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:pet_connect/features/usuario/data/firebase_usuario_repository.dart';

const _dono = 'tutor-dono';
const _outro = 'outro-tutor';
final _erro = FirebaseException(plugin: 'cloud_firestore', code: 'teste');

class _UsuarioFake implements User {
  _UsuarioFake(this.uid);

  @override
  final String uid;

  var excluido = false;

  @override
  Future<void> delete() async => excluido = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthFake implements FirebaseAuth {
  _AuthFake(this.currentUser);

  @override
  final User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<int> _contar(FakeFirebaseFirestore db, String caminho) async =>
    (await db.collection(caminho).get()).docs.length;

void main() {
  late FakeFirebaseFirestore db;
  late _UsuarioFake usuario;
  late FirebaseUsuarioRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    usuario = _UsuarioFake(_dono);
    repo = FirebaseUsuarioRepository(
      auth: _AuthFake(usuario),
      firestore: db,
    );

    await db.collection('Usuarios').doc(_dono).set({'nome': 'Ana'});
    await db.collection('Usuarios').doc(_outro).set({'nome': 'Beto'});
    await db.collection('Pets').doc('rex').set({'userId': _dono});
    await db
        .collection('Pets')
        .doc('mel')
        .set({'userId': _dono, 'situacao': 'FALECIDO'});
    await db.collection('Pets').doc('thor').set({'userId': _outro});
    for (final petId in ['rex', 'mel', 'thor']) {
      for (final sub in subcolecoesApagadasNaExclusaoDeConta) {
        await db.collection('Pets/$petId/$sub').add({'nota': 'x'});
        await db.collection('Pets/$petId/$sub').add({'nota': 'y'});
      }
      await db.collection('Pets/$petId/eventosSituacao').add({'atorId': 'x'});
    }
  });

  test('cobre as quatro subcoleções clínicas', () {
    expect(subcolecoesApagadasNaExclusaoDeConta, [
      'vacinas',
      'consultas',
      'historicoMedico',
      'localizacoes',
    ]);
  });

  test('apaga subcoleções, eventos, pets (inclusive falecido), perfil e Auth',
      () async {
    await repo.deleteAccount();

    for (final petId in ['rex', 'mel']) {
      for (final sub in [
        ...subcolecoesApagadasNaExclusaoDeConta,
        'eventosSituacao',
      ]) {
        expect(await _contar(db, 'Pets/$petId/$sub'), 0,
            reason: 'Pets/$petId/$sub ficou órfã');
      }
      expect((await db.doc('Pets/$petId').get()).exists, isFalse);
    }
    expect((await db.doc('Usuarios/$_dono').get()).exists, isFalse);
    expect(usuario.excluido, isTrue);
  });

  test('apaga as subcoleções clínicas antes do lote final', () async {
    // O lote final começa pelos eventos; falhando ali, nada dele é aplicado.
    for (final petId in ['rex', 'mel']) {
      final eventos = await db.collection('Pets/$petId/eventosSituacao').get();
      for (final evento in eventos.docs) {
        whenCalling(Invocation.method(#delete, null))
            .on(evento.reference)
            .thenThrow(_erro);
      }
    }

    await expectLater(repo.deleteAccount(), throwsA(_erro));

    for (final petId in ['rex', 'mel']) {
      expect((await db.doc('Pets/$petId').get()).exists, isTrue);
      for (final sub in subcolecoesApagadasNaExclusaoDeConta) {
        expect(await _contar(db, 'Pets/$petId/$sub'), 0,
            reason: 'Pets/$petId/$sub não foi apagada');
      }
      expect(await _contar(db, 'Pets/$petId/eventosSituacao'), 1);
    }
    expect((await db.doc('Usuarios/$_dono').get()).exists, isTrue);
    expect(usuario.excluido, isFalse);
  });

  test('o lote final apaga os eventos de cada pet antes do pet', () async {
    for (final petId in ['rex', 'mel']) {
      whenCalling(Invocation.method(#delete, null))
          .on(db.doc('Pets/$petId'))
          .thenThrow(_erro);
    }

    await expectLater(repo.deleteAccount(), throwsA(_erro));

    // Parou no primeiro pet: ele continua, já sem eventos.
    final semEventos = <String>[];
    for (final petId in ['rex', 'mel']) {
      expect((await db.doc('Pets/$petId').get()).exists, isTrue);
      if (await _contar(db, 'Pets/$petId/eventosSituacao') == 0) {
        semEventos.add(petId);
      }
    }
    expect(semEventos, hasLength(1));
    expect((await db.doc('Usuarios/$_dono').get()).exists, isTrue);
    expect(usuario.excluido, isFalse);
  });

  test('não toca nos dados de outro tutor', () async {
    await repo.deleteAccount();

    expect((await db.doc('Pets/thor').get()).exists, isTrue);
    for (final sub in subcolecoesApagadasNaExclusaoDeConta) {
      expect(await _contar(db, 'Pets/thor/$sub'), 2);
    }
    expect(await _contar(db, 'Pets/thor/eventosSituacao'), 1);
    expect((await db.doc('Usuarios/$_outro').get()).exists, isTrue);
  });
}
