// Login com Google e Facebook no repositório (docs/features/login-social.md):
// criação do perfil sem duplicar tutor, cancelamento, provedor indisponível,
// conflito de conta sem união automática pelo e-mail e vinculação segura.
import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_connect/core/network/api_client.dart';
import 'package:pet_connect/features/usuario/data/api_usuario_repository.dart';
import 'package:pet_connect/features/usuario/data/entrada_social.dart';
import 'package:pet_connect/features/usuario/data/firebase_usuario_repository.dart';
import 'package:pet_connect/features/usuario/data/provedores_sociais.dart';
import 'package:pet_connect/features/usuario/domain/login_social.dart';

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid, {this.displayName, this.email});

  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? email;

  final vinculadas = <AuthCredential>[];
  Object? erroAoVincular;

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    if (erroAoVincular != null) throw erroAoVincular!;
    vinculadas.add(credential);
    return _FakeUserCredential(this);
  }
}

class _FakeUserCredential extends Fake implements UserCredential {
  _FakeUserCredential(this.user);

  @override
  final User? user;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  /// Conta que o Firebase devolve para qualquer credencial social.
  _FakeUser? contaSocial;
  Object? erroSocial;
  final credenciaisRecebidas = <AuthCredential>[];

  /// Conta de e-mail e senha existente (senha "certa").
  _FakeUser? contaComSenha;
  int saidas = 0;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    credenciaisRecebidas.add(credential);
    if (erroSocial != null) throw erroSocial!;
    return _FakeUserCredential(contaSocial);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (password != 'certa') {
      throw FirebaseAuthException(code: 'wrong-password');
    }
    return _FakeUserCredential(contaComSenha);
  }

  @override
  Future<void> signOut() async => saidas++;
}

class _FakeProvedor implements ProvedorDeCredencial {
  _FakeProvedor(this.provedor);

  @override
  final ProvedorSocial provedor;
  Object? erro;
  int pedidos = 0;
  int saidas = 0;

  @override
  Future<AuthCredential> obterCredencial() async {
    pedidos++;
    if (erro != null) throw erro!;
    return switch (provedor) {
      ProvedorSocial.google =>
        GoogleAuthProvider.credential(idToken: 'id-token-teste'),
      ProvedorSocial.facebook => FacebookAuthProvider.credential('token-teste'),
    };
  }

  @override
  Future<void> sair() async => saidas++;
}

void main() {
  late _FakeAuth auth;
  late FakeFirebaseFirestore firestore;
  late _FakeProvedor google;
  late _FakeProvedor facebook;
  late FirebaseUsuarioRepository repo;

  setUp(() {
    auth = _FakeAuth();
    firestore = FakeFirebaseFirestore();
    google = _FakeProvedor(ProvedorSocial.google);
    facebook = _FakeProvedor(ProvedorSocial.facebook);
    repo = FirebaseUsuarioRepository(
      auth: auth,
      firestore: firestore,
      provedores: {
        ProvedorSocial.google: google,
        ProvedorSocial.facebook: facebook,
      },
    );
  });

  Future<Map<String, dynamic>?> perfil(String uid) async =>
      (await firestore.collection('Usuarios').doc(uid).get()).data();

  group('primeiro login', () {
    test('Google cria o perfil com nome, sobrenome e e-mail do provedor',
        () async {
      auth.contaSocial = _FakeUser('uid-g',
          displayName: 'Ana Maria Souza', email: 'ana@teste.com');

      await repo.entrarComProvedor(ProvedorSocial.google);

      expect(auth.credenciaisRecebidas.single.providerId, 'google.com');
      expect(await perfil('uid-g'), {
        'usuarioID': 'uid-g',
        'nome': 'Ana',
        'sobrenome': 'Maria Souza',
        'email': 'ana@teste.com',
        'telefone': '',
        'dataNascimento': '',
        'genero': '',
        'foto': null,
      });
    });

    test('Facebook sem e-mail e sem nome: perfil com campos vazios', () async {
      auth.contaSocial = _FakeUser('uid-f');

      await repo.entrarComProvedor(ProvedorSocial.facebook);

      expect(auth.credenciaisRecebidas.single.providerId, 'facebook.com');
      final dados = await perfil('uid-f');
      expect(dados?['nome'], '');
      expect(dados?['email'], '');
    });
  });

  test('login repetido não altera nem duplica o perfil existente', () async {
    await firestore.collection('Usuarios').doc('uid-g').set({
      'usuarioID': 'uid-g',
      'nome': 'Ana',
      'sobrenome': 'Souza',
      'email': 'ana@teste.com',
      'telefone': '(11) 99999-0000',
      'dataNascimento': '01/01/1990',
      'genero': 'Mulher',
      'foto': 'https://res.cloudinary.com/x/image/upload/v1/a.jpg',
    });
    auth.contaSocial = _FakeUser('uid-g', displayName: 'Outro Nome');

    await repo.entrarComProvedor(ProvedorSocial.google);
    await repo.entrarComProvedor(ProvedorSocial.google);

    final dados = await perfil('uid-g');
    expect(dados?['nome'], 'Ana');
    expect(dados?['telefone'], '(11) 99999-0000');
    expect((await firestore.collection('Usuarios').get()).docs, hasLength(1));
  });

  group('falhas do provedor', () {
    test('cancelado: nada chega ao Firebase', () async {
      google.erro = const LoginSocialCancelado(ProvedorSocial.google);

      await expectLater(repo.entrarComProvedor(ProvedorSocial.google),
          throwsA(isA<LoginSocialCancelado>()));
      expect(auth.credenciaisRecebidas, isEmpty);
    });

    test('provedor sem configuração no app: indisponível', () async {
      final semProvedores =
          FirebaseUsuarioRepository(auth: auth, firestore: firestore);

      await expectLater(semProvedores.entrarComProvedor(ProvedorSocial.google),
          throwsA(isA<LoginSocialIndisponivel>()));
    });

    test('provedor desligado no Firebase Console: indisponível', () async {
      auth.erroSocial = FirebaseAuthException(code: 'operation-not-allowed');

      await expectLater(repo.entrarComProvedor(ProvedorSocial.facebook),
          throwsA(isA<LoginSocialIndisponivel>()));
    });

    test('token expirado ou revogado: o erro do Firebase sobe', () async {
      auth.erroSocial = FirebaseAuthException(code: 'invalid-credential');

      await expectLater(
          repo.entrarComProvedor(ProvedorSocial.google),
          throwsA(isA<FirebaseAuthException>()
              .having((e) => e.code, 'code', 'invalid-credential')));
    });
  });

  group('conta existente com outro método', () {
    final pendenteFacebook = FacebookAuthProvider.credential('token-pendente');

    setUp(() {
      auth.erroSocial = FirebaseAuthException(
        code: 'account-exists-with-different-credential',
        email: 'ana@teste.com',
        credential: pendenteFacebook,
      );
    });

    test('não une as contas: avisa com o e-mail e não cria perfil', () async {
      final erro = await repo
          .entrarComProvedor(ProvedorSocial.facebook)
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(
          erro,
          isA<ContaExisteComOutroMetodo>()
              .having((e) => e.email, 'email', 'ana@teste.com')
              .having((e) => e.provedor, 'provedor', ProvedorSocial.facebook)
              .having((e) => e.credencialPendente, 'credencial',
                  same(pendenteFacebook)));
      expect((await firestore.collection('Usuarios').get()).docs, isEmpty);
    });

    test('senha certa: entra na conta existente e vincula o Facebook',
        () async {
      final existente = _FakeUser('uid-senha', email: 'ana@teste.com');
      auth.contaComSenha = existente;
      await firestore.collection('Usuarios').doc('uid-senha').set(
          {'usuarioID': 'uid-senha', 'nome': 'Ana', 'email': 'ana@teste.com'});
      final pendente = ContaExisteComOutroMetodo(
          provedor: ProvedorSocial.facebook,
          email: 'ana@teste.com',
          credencialPendente: pendenteFacebook);

      await repo.entrarComSenhaEVincular(
          email: 'ana@teste.com', senha: 'certa', pendente: pendente);

      expect(existente.vinculadas.single, same(pendenteFacebook));
      expect((await firestore.collection('Usuarios').get()).docs, hasLength(1),
          reason: 'mesmo tutor, mesmo UID: nenhum perfil novo');
      expect((await perfil('uid-senha'))?['nome'], 'Ana');
    });

    test('senha errada: nada é vinculado', () async {
      final existente = _FakeUser('uid-senha');
      auth.contaComSenha = existente;

      await expectLater(
          repo.entrarComSenhaEVincular(
              email: 'ana@teste.com',
              senha: 'errada',
              pendente: ContaExisteComOutroMetodo(
                  provedor: ProvedorSocial.facebook,
                  email: 'ana@teste.com',
                  credencialPendente: pendenteFacebook)),
          throwsA(isA<FirebaseAuthException>()));
      expect(existente.vinculadas, isEmpty);
    });

    test('entra com o Google da conta existente e vincula o Facebook',
        () async {
      final existente = _FakeUser('uid-g', email: 'ana@teste.com');
      auth
        ..erroSocial = null
        ..contaSocial = existente;

      await repo.entrarComProvedorEVincular(
          ProvedorSocial.google,
          ContaExisteComOutroMetodo(
              provedor: ProvedorSocial.facebook,
              email: 'ana@teste.com',
              credencialPendente: pendenteFacebook));

      expect(auth.credenciaisRecebidas.single.providerId, 'google.com');
      expect(existente.vinculadas.single, same(pendenteFacebook));
    });

    test('provedor já vinculado (tentativa repetida) não é erro', () async {
      final existente = _FakeUser('uid-senha')
        ..erroAoVincular =
            FirebaseAuthException(code: 'provider-already-linked');
      auth.contaComSenha = existente;

      await repo.entrarComSenhaEVincular(
          email: 'ana@teste.com',
          senha: 'certa',
          pendente: ContaExisteComOutroMetodo(
              provedor: ProvedorSocial.facebook,
              email: 'ana@teste.com',
              credencialPendente: pendenteFacebook));
    });
  });

  test('sair encerra o Firebase e a sessão dos dois provedores', () async {
    await repo.signOut();

    expect(auth.saidas, 1);
    expect(google.saidas, 1);
    expect(facebook.saidas, 1);
  });

  test('falha ao criar o perfil: sai da conta em vez de entrar pela metade',
      () async {
    auth.contaSocial = _FakeUser('uid-g');
    final social = EntradaSocial(
      auth: auth,
      provedores: {ProvedorSocial.google: google},
      aposEntrar: (_) async => throw Exception('offline'),
    );

    await expectLater(
        social.entrar(ProvedorSocial.google), throwsA(isA<Exception>()));
    expect(auth.saidas, 1);
  });

  test('modo API: o primeiro login provisiona o tutor com GET /me', () async {
    auth.contaSocial = _FakeUser('uid-g', displayName: 'Ana');
    final chamadas = <String>[];
    final api = ApiClient(
      baseUrl: 'https://api.teste',
      getToken: () async => 'token',
      httpClient: MockClient((pedido) async {
        chamadas.add('${pedido.method} ${pedido.url.path}');
        return http.Response(
            jsonEncode({'id': 'u1', 'firebaseUid': 'uid-g'}), 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    final apiRepo = ApiUsuarioRepository(
        auth: auth, api: api, provedores: {ProvedorSocial.google: google});

    await apiRepo.entrarComProvedor(ProvedorSocial.google);

    expect(chamadas, ['GET /api/v1/me']);
  });
}
