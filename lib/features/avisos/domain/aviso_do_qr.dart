/// Aviso do QR Code que chega por push (issue #36). O servidor manda só o
/// tipo e os ids do pet; o título e o texto já vêm prontos na notificação.
enum TipoDeAvisoDoQr {
  /// A página do QR foi aberta. Não é avistamento.
  acesso,

  /// Alguém enviou um relato, com ou sem localização.
  avistamento,
}

class AvisoDoQr {
  const AvisoDoQr({required this.tipo, required this.petId});

  final TipoDeAvisoDoQr tipo;

  /// Id do pet no modo em que o app está: do Firestore ou da API.
  final String petId;

  /// Tela que o toque na notificação abre.
  String get rota => '/pet/$petId/localizacao';

  /// `null` quando o payload não é de um aviso do QR ou não traz o id do pet
  /// no modo do app.
  ///
  /// [petsNaApi]: com `USE_API_PETS`, o app usa o id da API; senão, o do
  /// Firestore.
  static AvisoDoQr? doPayload(Map<String, dynamic> data,
      {required bool petsNaApi}) {
    final tipo = switch (data['type']) {
      'qr_access' => TipoDeAvisoDoQr.acesso,
      'sighting' => TipoDeAvisoDoQr.avistamento,
      _ => null,
    };
    final id = data[petsNaApi ? 'apiPetId' : 'firestorePetId'];
    if (tipo == null || id is! String || !_idValido.hasMatch(id)) return null;
    return AvisoDoQr(tipo: tipo, petId: id);
  }

  /// O id vira parte de uma rota: só letras, números, hífen e sublinhado.
  static final _idValido = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
}

/// O que o tutor quer receber sobre o QR de um pet.
class PreferenciasDeAviso {
  const PreferenciasDeAviso({
    required this.avisarAcesso,
    required this.avisarAvistamento,
  });

  final bool avisarAcesso;
  final bool avisarAvistamento;

  factory PreferenciasDeAviso.daApi(Map<String, dynamic> json) =>
      PreferenciasDeAviso(
        avisarAcesso: json['notifyOnAccess'] as bool? ?? true,
        avisarAvistamento: json['notifyOnSighting'] as bool? ?? true,
      );

  Map<String, dynamic> paraApi() => {
        'notifyOnAccess': avisarAcesso,
        'notifyOnSighting': avisarAvistamento,
      };

  PreferenciasDeAviso copyWith({bool? avisarAcesso, bool? avisarAvistamento}) =>
      PreferenciasDeAviso(
        avisarAcesso: avisarAcesso ?? this.avisarAcesso,
        avisarAvistamento: avisarAvistamento ?? this.avisarAvistamento,
      );
}

/// Push recebido com o app aberto: o título que o servidor mandou e os dados.
class MensagemDePush {
  const MensagemDePush({this.titulo, required this.dados});

  final String? titulo;
  final Map<String, dynamic> dados;
}

/// Situação da permissão de notificação do sistema.
enum PermissaoDeAviso { concedida, negada, naoPerguntada }

/// O lado do aparelho: permissão, token e mensagens do FCM. Interface para
/// os testes não dependerem do Firebase.
abstract class PushDoAparelho {
  Future<PermissaoDeAviso> pedirPermissao();

  Future<PermissaoDeAviso> permissao();

  Future<String?> token();

  Stream<String> get tokensNovos;

  /// Aviso que chegou com o app aberto (o sistema não mostra a notificação).
  Stream<MensagemDePush> get avisosComOAppAberto;

  /// Notificação tocada com o app em segundo plano.
  Stream<Map<String, dynamic>> get avisosTocados;

  /// Notificação que abriu o app fechado, se foi o caso.
  Future<Map<String, dynamic>?> avisoQueAbriuOApp();

  Future<void> apagarToken();
}

/// Registro do aparelho e preferências na API.
abstract class AvisosRepository {
  Future<void> registrarAparelho(String token);

  Future<void> removerAparelho(String token);

  Future<PreferenciasDeAviso> preferencias(String petId);

  Future<PreferenciasDeAviso> salvarPreferencias(
      String petId, PreferenciasDeAviso preferencias);
}
