import 'login_social.dart';
import 'usuario.dart';

/// Interface do repositório de usuário — a UI e os providers dependem
/// desta abstração, não do Firebase diretamente (ver docs/arquitetura.md).
///
/// Login: e-mail/senha e social (Google/Facebook, RF04-A/RF04-B,
/// docs/features/login-social.md).
abstract class UsuarioRepository {
  /// Observa o documento do usuário em `Usuarios/{uid}`, emitindo `null`
  /// se o documento não existir.
  Stream<Usuario?> watchUsuario(String uid);

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String nome,
    required String email,
    required String password,
    required String telefone,
    required String dataNascimento,
  });

  Future<void> sendPasswordReset({required String email});

  /// Entra (ou cria a conta, na primeira vez) com Google ou Facebook. O
  /// perfil do tutor é criado só se ainda não existir.
  ///
  /// Lança [LoginSocialCancelado], [LoginSocialIndisponivel],
  /// [LoginSocialFalhou] ou [ContaExisteComOutroMetodo].
  Future<void> entrarComProvedor(ProvedorSocial provedor);

  /// Resolve [ContaExisteComOutroMetodo] entrando na conta existente com
  /// e-mail e senha; depois vincula o provedor pendente a ela.
  Future<void> entrarComSenhaEVincular({
    required String email,
    required String senha,
    required ContaExisteComOutroMetodo pendente,
  });

  /// Resolve [ContaExisteComOutroMetodo] entrando na conta existente por
  /// outro provedor (ex.: Google); depois vincula o provedor pendente.
  Future<void> entrarComProvedorEVincular(
    ProvedorSocial provedor,
    ContaExisteComOutroMetodo pendente,
  );

  Future<void> signOut();

  /// Edita os dados do tutor autenticado (RF08).
  Future<void> updateUsuario({
    required String nome,
    required String sobrenome,
    required String telefone,
    required String dataNascimento,
    required String genero,
    String? foto,
  });

  /// Exclui a conta do tutor autenticado (RF09): remove os pets (e as
  /// subcoleções de vacinas/histórico médico de cada um), o documento do
  /// tutor e o usuário no Firebase Auth.
  Future<void> deleteAccount();
}
