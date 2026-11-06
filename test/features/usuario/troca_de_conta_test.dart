// Sair de uma conta e entrar em outra não pode deixar a Home em "Não foi
// possível carregar seus dados" (relato do proprietário de 2026-11-05).
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/domain/usuario_repository.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

class _Conta extends Fake implements User {
  _Conta(this.uid);

  @override
  final String uid;
}

/// Um perfil por uid, cada um com o próprio stream, como no Firestore.
class _Perfis extends Fake implements UsuarioRepository {
  final streams = <String, StreamController<Usuario?>>{};

  StreamController<Usuario?> de(String uid) =>
      streams.putIfAbsent(uid, StreamController<Usuario?>.broadcast);

  @override
  Stream<Usuario?> watchUsuario(String uid) => de(uid).stream;
}

Usuario _usuario(String uid) => Usuario(
      id: uid,
      usuarioID: uid,
      nome: 'Tutor $uid',
      email: '$uid@exemplo.test',
      telefone: '',
      dataNascimento: '',
      genero: '',
    );

void main() {
  test(
      'depois de sair (com o perfil antigo negado pelo Firestore), a próxima '
      'conta carrega o próprio perfil', () async {
    final sessao = StreamController<User?>.broadcast();
    final perfis = _Perfis();
    final container = ProviderContainer(overrides: [
      authStateChangesProvider.overrideWith((ref) => sessao.stream),
      usuarioRepositoryProvider.overrideWithValue(perfis),
    ]);
    addTearDown(() async {
      container.dispose();
      await sessao.close();
    });
    final estados = <AsyncValue<Usuario?>>[];
    container.listen(currentUsuarioProvider, (_, s) => estados.add(s),
        fireImmediately: true);

    sessao.add(_Conta('a'));
    await pumpEventQueue();
    perfis.de('a').add(_usuario('a'));
    await pumpEventQueue();
    expect(container.read(currentUsuarioProvider).valueOrNull?.id, 'a');

    // Ao sair, o Firestore nega a leitura do perfil da conta anterior.
    perfis.de('a').addError(FirebaseException(
        plugin: 'cloud_firestore', code: 'permission-denied'));
    sessao.add(null);
    await pumpEventQueue();
    expect(container.read(currentUsuarioProvider).valueOrNull, isNull);

    sessao.add(_Conta('b'));
    await pumpEventQueue();
    perfis.de('b').add(_usuario('b'));
    await pumpEventQueue();

    final atual = container.read(currentUsuarioProvider);
    expect(atual.hasError, isFalse);
    expect(atual.valueOrNull?.id, 'b');
  });

  test('sem sessão, o perfil é nulo', () async {
    final container = ProviderContainer(overrides: [
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      usuarioRepositoryProvider.overrideWithValue(_Perfis()),
    ]);
    addTearDown(container.dispose);
    // Como na Home, que observa o perfil.
    container.listen(currentUsuarioProvider, (_, __) {});
    await pumpEventQueue();

    final atual = container.read(currentUsuarioProvider);
    expect(atual.hasValue, isTrue);
    expect(atual.value, isNull);
  });
}
