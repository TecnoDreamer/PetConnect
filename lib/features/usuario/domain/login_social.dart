/// Login com Google (RF04-A; docs/features/login-social.md). O Facebook
/// (RF04-B) saiu do escopo por decisão do proprietário em 2026-10-27.
///
/// A identidade continua sendo o UID do Firebase Auth: entrar por outro
/// provedor nunca cria um segundo tutor para uma conta que já existe.
enum ProvedorSocial {
  google('Google');

  const ProvedorSocial(this.nome);

  final String nome;
}

/// O tutor desistiu no seletor de conta ou na tela do provedor. Não é erro:
/// a tela de login só volta ao normal.
class LoginSocialCancelado implements Exception {
  const LoginSocialCancelado(this.provedor);

  final ProvedorSocial provedor;

  @override
  String toString() => 'LoginSocialCancelado(${provedor.name})';
}

/// O provedor não está configurado nesta build (Firebase ou Google Cloud)
/// ou não existe neste aparelho.
class LoginSocialIndisponivel implements Exception {
  const LoginSocialIndisponivel(this.provedor, [this.causa]);

  final ProvedorSocial provedor;
  final Object? causa;

  @override
  String toString() => 'LoginSocialIndisponivel(${provedor.name}, $causa)';
}

/// O provedor recusou ou falhou por outro motivo (rede, sessão expirada,
/// acesso revogado). Dá para tentar de novo.
class LoginSocialFalhou implements Exception {
  const LoginSocialFalhou(this.provedor, [this.causa]);

  final ProvedorSocial provedor;
  final Object? causa;

  @override
  String toString() => 'LoginSocialFalhou(${provedor.name}, $causa)';
}

/// Já existe uma conta PetConnect com este e-mail, criada por outro método.
/// As contas **nunca** são unidas automaticamente pelo e-mail: o tutor entra
/// primeiro com a senha que já usa e só então o provedor é vinculado
/// (UsuarioRepository.entrarComSenhaEVincular).
class ContaExisteComOutroMetodo implements Exception {
  const ContaExisteComOutroMetodo({
    required this.provedor,
    required this.email,
    required this.credencialPendente,
  });

  /// Provedor que o tutor tentou usar e que será vinculado.
  final ProvedorSocial provedor;
  final String? email;

  /// Credencial do provedor, guardada só em memória até a vinculação. O
  /// tipo concreto é da implementação (AuthCredential no Firebase).
  final Object credencialPendente;

  @override
  String toString() => 'ContaExisteComOutroMetodo(${provedor.name})';
}
