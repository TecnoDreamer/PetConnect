import 'dart:async';

import '../domain/aviso_do_qr.dart';

/// Liga o push do aparelho à conta do tutor (issue #36).
///
/// - **Login:** pede a permissão de notificação (o sistema só pergunta uma
///   vez) e registra o token na API. Token novo do FCM é registrado de novo.
/// - **Toque na notificação:** abre a aba Localização do pet. O app pede
///   login a cada abertura, então o destino espera o login terminar
///   ([abrirQuandoPossivel]).
/// - **App aberto:** o sistema não mostra a notificação; [mostrar] recebe o
///   aviso para a tela exibir, e [atualizar] recarrega a atividade do pet.
/// - **Sair da conta:** [esquecerAparelho] remove o token antes do signOut.
///
/// Falhas de rede ou da API não derrubam nada: o aviso é melhor esforço.
class AvisosDoQr {
  AvisosDoQr({
    required PushDoAparelho push,
    required AvisosRepository repository,
    required bool petsNaApi,
  })  : _push = push,
        _repo = repository,
        _petsNaApi = petsNaApi;

  final PushDoAparelho _push;
  final AvisosRepository _repo;
  final bool _petsNaApi;

  final _assinaturas = <StreamSubscription<Object?>>[];
  bool _logado = false;
  String? _destinoPendente;

  late void Function(String rota) _abrir;
  late void Function(AvisoDoQr aviso, String? titulo) _mostrar;
  late void Function(String petId) _atualizar;

  static const _limite = Duration(seconds: 10);

  /// Sair da conta não pode ficar preso esperando a rede.
  static const _limiteAoSair = Duration(seconds: 4);

  /// [logado] emite a cada mudança de sessão. [abrir] navega para uma rota
  /// com o tutor já logado.
  Future<void> iniciar({
    required Stream<bool> logado,
    required void Function(String rota) abrir,
    required void Function(AvisoDoQr aviso, String? titulo) mostrar,
    required void Function(String petId) atualizar,
  }) async {
    _abrir = abrir;
    _mostrar = mostrar;
    _atualizar = atualizar;

    _assinaturas
      ..add(logado.listen(_mudouSessao))
      ..add(_push.tokensNovos.listen((t) {
        if (_logado) unawaited(_registrar(t));
      }))
      ..add(_push.avisosTocados.listen(_tocou))
      ..add(_push.avisosComOAppAberto.listen(_chegouComOAppAberto));

    try {
      final inicial = await _push.avisoQueAbriuOApp();
      if (inicial != null) _tocou(inicial);
    } catch (_) {
      // Sem a notificação inicial, o app abre normalmente.
    }
  }

  void _mudouSessao(bool logado) {
    _logado = logado;
    if (!logado) return;
    unawaited(_registrarAparelho());
  }

  Future<void> _registrarAparelho() async {
    try {
      final permissao = await _push.pedirPermissao().timeout(_limite);
      if (permissao != PermissaoDeAviso.concedida) return;
      final token = await _push.token().timeout(_limite);
      if (token != null) await _registrar(token);
    } catch (_) {
      // Tenta de novo no próximo login ou token novo.
    }
  }

  Future<void> _registrar(String token) async {
    try {
      await _repo.registrarAparelho(token).timeout(_limite);
    } catch (_) {
      // Melhor esforço.
    }
  }

  void _tocou(Map<String, dynamic> dados) {
    final aviso = AvisoDoQr.doPayload(dados, petsNaApi: _petsNaApi);
    if (aviso == null) return;
    _atualizar(aviso.petId);
    if (_logado) {
      _abrir(aviso.rota);
    } else {
      _destinoPendente = aviso.rota;
    }
  }

  void _chegouComOAppAberto(MensagemDePush mensagem) {
    final aviso = AvisoDoQr.doPayload(mensagem.dados, petsNaApi: _petsNaApi);
    if (aviso == null || !_logado) return;
    _atualizar(aviso.petId);
    _mostrar(aviso, mensagem.titulo);
  }

  /// Chamado quando o app chega à Home depois do login: abre a tela da
  /// notificação que foi tocada antes do login, se houver.
  void abrirQuandoPossivel() {
    final destino = _destinoPendente;
    if (destino == null || !_logado) return;
    _destinoPendente = null;
    _abrir(destino);
  }

  /// Ao sair da conta: este aparelho para de receber avisos dela. Precisa
  /// rodar antes do signOut, enquanto ainda há token de login.
  Future<void> esquecerAparelho() async {
    try {
      final token = await _push.token().timeout(_limiteAoSair);
      if (token != null) {
        await _repo.removerAparelho(token).timeout(_limiteAoSair);
      }
    } catch (_) {
      // Sem rede: o servidor apaga o token quando o FCM disser que expirou.
    }
    try {
      await _push.apagarToken().timeout(_limiteAoSair);
    } catch (_) {}
  }

  Future<void> encerrar() async {
    for (final a in _assinaturas) {
      await a.cancel();
    }
    _assinaturas.clear();
  }
}
