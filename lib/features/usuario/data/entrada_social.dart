import 'package:firebase_auth/firebase_auth.dart';

import '../domain/login_social.dart';
import 'provedores_sociais.dart';

/// Fluxo de login social sobre o Firebase Auth, comum aos repositórios de
/// usuário (Firestore e API). Quem usa decide o que fazer com o perfil
/// depois de entrar ([aposEntrar]): criar o documento em `Usuarios` ou
/// provisionar o tutor na API.
class EntradaSocial {
  EntradaSocial({
    required FirebaseAuth auth,
    required Map<ProvedorSocial, ProvedorDeCredencial> provedores,
    required Future<void> Function(User usuario) aposEntrar,
  })  : _auth = auth,
        _provedores = provedores,
        _aposEntrar = aposEntrar;

  final FirebaseAuth _auth;
  final Map<ProvedorSocial, ProvedorDeCredencial> _provedores;
  final Future<void> Function(User usuario) _aposEntrar;

  ProvedorDeCredencial _provedor(ProvedorSocial provedor) =>
      _provedores[provedor] ?? (throw LoginSocialIndisponivel(provedor));

  Future<void> entrar(ProvedorSocial provedor) async {
    final credencial = await _provedor(provedor).obterCredencial();
    final usuario = await _entrarComCredencial(provedor, credencial);
    try {
      await _aposEntrar(usuario);
    } catch (_) {
      // Sem perfil o app não funciona: melhor sair e deixar tentar de novo
      // do que entrar pela metade.
      await _auth.signOut();
      rethrow;
    }
  }

  Future<void> entrarComSenhaEVincular({
    required String email,
    required String senha,
    required ContaExisteComOutroMetodo pendente,
  }) async {
    final resultado =
        await _auth.signInWithEmailAndPassword(email: email, password: senha);
    await _vincular(resultado.user!, pendente);
  }

  Future<void> entrarComProvedorEVincular(
    ProvedorSocial provedor,
    ContaExisteComOutroMetodo pendente,
  ) async {
    final credencial = await _provedor(provedor).obterCredencial();
    final usuario = await _entrarComCredencial(provedor, credencial);
    await _vincular(usuario, pendente);
  }

  /// Sai dos SDKs dos provedores (a sessão do Firebase é encerrada por quem
  /// chama). Sem isso, o próximo login poderia reaproveitar a conta anterior
  /// sem perguntar.
  Future<void> sairDosProvedores() async {
    await Future.wait([for (final p in _provedores.values) p.sair()]);
  }

  Future<User> _entrarComCredencial(
      ProvedorSocial provedor, AuthCredential credencial) async {
    try {
      final resultado = await _auth.signInWithCredential(credencial);
      return resultado.user!;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw ContaExisteComOutroMetodo(
          provedor: provedor,
          email: e.email,
          credencialPendente: e.credential ?? credencial,
        );
      }
      if (e.code == 'operation-not-allowed') {
        // Provedor desligado no Firebase Console.
        throw LoginSocialIndisponivel(provedor, e.code);
      }
      rethrow;
    }
  }

  Future<void> _vincular(
      User usuario, ContaExisteComOutroMetodo pendente) async {
    final credencial = pendente.credencialPendente;
    if (credencial is! AuthCredential) {
      throw ArgumentError.value(credencial, 'credencialPendente');
    }
    try {
      await usuario.linkWithCredential(credencial);
    } on FirebaseAuthException catch (e) {
      // Já vinculado (tentativa repetida): o tutor está na conta certa.
      if (e.code != 'provider-already-linked') rethrow;
    }
    await _aposEntrar(usuario);
  }
}
