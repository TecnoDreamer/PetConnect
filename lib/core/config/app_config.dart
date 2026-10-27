/// Configuração de ambiente e feature flags da migração para a API Spring.
///
/// Tudo vem de `--dart-define` no build/run. Sem nenhum define, o app roda
/// 100% Firebase, exatamente como antes.
///
/// Exemplo (emulador Android apontando para a API local em container):
/// ```
/// flutter run \
///   --dart-define=API_BASE_URL=http://10.0.2.2:8090 \
///   --dart-define=USE_API_USUARIO=true
/// ```
class AppConfig {
  const AppConfig._();

  /// URL base da API (`/api/v1` é acrescentado pelo cliente).
  /// `10.0.2.2` é o host visto de dentro do emulador Android.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8090',
  );

  /// FASE 4 — perfil do tutor (`GET`/`PATCH`/`DELETE /api/v1/me`) via API
  /// em vez do Firestore. Login/cadastro/reset continuam no Firebase Auth.
  static const bool useApiForUsuario = bool.fromEnvironment('USE_API_USUARIO');

  /// FASE 5 — pets via API.
  static const bool useApiForPets = bool.fromEnvironment('USE_API_PETS');

  /// FASE 6 — carteira de vacina via API.
  static const bool useApiForVacinas = bool.fromEnvironment('USE_API_VACINAS');

  /// FASE 7 — consultas via API.
  static const bool useApiForConsultas =
      bool.fromEnvironment('USE_API_CONSULTAS');

  /// FASE 8 — histórico médico via API.
  static const bool useApiForHistorico =
      bool.fromEnvironment('USE_API_HISTORICO');

  /// FASE 9 — avistamentos (RF31/32) via API.
  static const bool useApiForLocalizacao =
      bool.fromEnvironment('USE_API_LOCALIZACAO');

  /// FASE 10 — upload/exclusão de anexo assinados pelo backend (Cloudinary).
  static const bool useApiForUpload = bool.fromEnvironment('USE_API_UPLOAD');

  /// QR code regenerável (RF19, issue #29) com os pets ainda no Firestore:
  /// a regeneração passa pela API, que é quem resolve o QR. Exige
  /// [apiBaseUrl] apontando para a API publicada. Com [useApiForPets] a
  /// regeneração já vem ligada e esta flag não é necessária.
  static const bool useApiForQr = bool.fromEnvironment('USE_API_QR');

  /// Galeria de fotos por pet (docs/features/galeria-fotos-pet.md).
  /// Desligada por padrão até o deploy das regras de isolamento por dono:
  /// com as regras antigas, qualquer conta logada leria as fotos de outra
  /// (docs/security/firestore-isolamento-por-dono.md). Só no modo Firestore;
  /// com [useApiForPets] fica oculta, como o Memorial.
  static const bool galeriaFotos = bool.fromEnvironment('GALERIA_FOTOS');
}
