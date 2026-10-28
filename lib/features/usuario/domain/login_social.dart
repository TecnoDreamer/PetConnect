/// Login com Google e Facebook (RF04-A, RF04-B; docs/features/login-social.md).
///
/// A identidade continua sendo o UID do Firebase Auth: entrar por outro
/// provedor nunca cria um segundo tutor para uma conta que já existe.
enum ProvedorSocial {
  google('Google'),
  facebook('Facebook');

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

/// O provedor não está configurado nesta build (Firebase, Google Cloud ou
/// Meta) ou não existe neste aparelho.
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
/// primeiro pelo método que já usa e só então o novo provedor é vinculado
/// (UsuarioRepository.entrarComSenhaEVincular / entrarComProvedorEVincular).
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
