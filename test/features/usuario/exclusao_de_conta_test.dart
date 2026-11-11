// Exclusão de conta com pets no Firestore e a API do QR ligada (LGPD):
// a API apaga o que guarda de cada pet e da conta, sem travar a exclusão
// quando está fora (docs/privacy/data-flow-and-lgpd-readiness.md).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/domain/limpeza_na_api.dart';
import 'package:pet_connect/features/usuario/data/firebase_usuario_repository.dart';

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  /// Erro do SDK ao excluir (ex.: a API já removeu o usuário do Auth).
  FirebaseAuthException? erroAoExcluir;
  bool excluido = false;

  @override
  Future<void> delete() async {
    if (erroAoExcluir != null) throw erroAoExcluir!;
    excluido = true;
  }
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this.currentUser);

  @override
  final User? currentUser;
  int saidas = 0;

  @override
  Future<void> signOut() async => saidas++;
}

/// Registra a ordem das chamadas e se o pet ainda existia em cada uma.
class _LimpezaFake implements LimpezaNaApi {
  _LimpezaFake(this.firestore, {this.noAr = true, this.contaExcluida = true});

  final FakeFirebaseFirestore firestore;
  final bool noAr;
  final bool contaExcluida;
  final chamadas = <String>[];
  final guardar = <bool>[];

  @override
  Future<ResultadoDaLimpeza> antesDeExcluirPet(String petId,
      {bool guardarSeFalhar = true}) async {
    final existe = (await firestore.collection('Pets').doc(petId).get()).exists;
    chamadas.add('pet $petId ${existe ? 'existia' : 'já apagado'}');
    guardar.add(guardarSeFalhar);
    return noAr
        ? ResultadoDaLimpeza.apagado
        : ResultadoDaLimpeza.apiInacessivel;
  }

  @override
  Future<void> retomarPendentes() async {}

  @override
  Future<bool> excluirConta() async {
    chamadas.add('conta');
    return contaExcluida;
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late _FakeUser user;
  late _FakeAuth auth;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    user = _FakeUser('uid-a');
    auth = _FakeAuth(user);
    await firestore.collection('Usuarios').doc('uid-a').set({'nome': 'Ana'});
    await firestore.collection('Pets').doc('p1').set({'userId': 'uid-a'});
    await firestore.collection('Pets').doc('p2').set({'userId': 'uid-a'});
    await firestore.collection('Pets').doc('p3').set({'userId': 'uid-b'});
  });

  FirebaseUsuarioRepository repo(LimpezaNaApi? limpeza) =>
      FirebaseUsuarioRepository(
          auth: auth, firestore: firestore, limpezaNaApi: limpeza);

  test('limpa cada pet na API antes de apagá-lo e depois a conta', () async {
    final limpeza = _LimpezaFake(firestore);

    await repo(limpeza).deleteAccount();

    expect(limpeza.chamadas, ['pet p1 existia', 'pet p2 existia', 'conta']);
    // A conta vai deixar de existir: não há como repetir depois.
    expect(limpeza.guardar, [false, false]);
    expect((await firestore.collection('Pets').get()).docs.map((d) => d.id),
        ['p3']);
    expect(user.excluido, isTrue);
  });

  test('API fora: desiste dela no primeiro pet e exclui no Firebase', () async {
    final limpeza = _LimpezaFake(firestore, noAr: false);

    await repo(limpeza).deleteAccount();

    expect(limpeza.chamadas, ['pet p1 existia']);
    expect((await firestore.collection('Pets').get()).docs.map((d) => d.id),
        ['p3']);
    expect(user.excluido, isTrue);
  });

  test('a API já removeu o usuário do Auth: o erro do SDK só encerra a sessão',
      () async {
    user.erroAoExcluir = FirebaseAuthException(code: 'user-not-found');

    await repo(_LimpezaFake(firestore)).deleteAccount();

    expect(auth.saidas, 1);
  });

  test('sem confirmação da API, o erro do SDK continua chegando à tela',
      () async {
    user.erroAoExcluir = FirebaseAuthException(code: 'requires-recent-login');

    await expectLater(
        repo(_LimpezaFake(firestore, contaExcluida: false)).deleteAccount(),
        throwsA(isA<FirebaseAuthException>()));
  });

  test('sem API configurada, exclui só no Firebase como antes', () async {
    await repo(null).deleteAccount();

    expect(user.excluido, isTrue);
    expect((await firestore.collection('Usuarios').doc('uid-a').get()).exists,
        isFalse);
  });
}
