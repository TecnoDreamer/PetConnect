import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/aviso_do_qr.dart';

/// Liga o push do aparelho à conta do tutor (issue #36).
///
/// - **Login e cada abertura com sessão:** pede a permissão de notificação
///   (o sistema só pergunta uma vez) e registra o token na API, com novas
///   tentativas enquanto a API acorda. Token novo do FCM é registrado de novo.
/// - **Toque na notificação:** abre a aba Localização do pet. Se o toque
///   abriu o app, o destino espera a sessão e a chegada à Home
///   ([abrirQuandoPossivel]): sem login, ou ainda na splash.
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
    List<Duration> esperasDoRegistro = esperasPadraoDoRegistro,
  })  : _push = push,
        _repo = repository,
        _petsNaApi = petsNaApi,
        _esperasDoRegistro = esperasDoRegistro;

  final PushDoAparelho _push;
  final AvisosRepository _repo;
  final bool _petsNaApi;
  final List<Duration> _esperasDoRegistro;

  /// Entre as tentativas de registrar o aparelho. A API no Render dorme sem
  /// uso e pode levar perto de um minuto para acordar; antes havia uma
  /// tentativa só, e o aparelho podia ficar sem receber avisos até o próximo
  /// login.
  static const esperasPadraoDoRegistro = [
    Duration(seconds: 5),
    Duration(seconds: 20),
    Duration(seconds: 60),
  ];

  final _assinaturas = <StreamSubscription<Object?>>[];
  bool _logado = false;
  bool _encerrado = false;
  String? _destinoPendente;

  late void Function(String rota) _abrir;
  late void Function(AvisoDoQr aviso, String? titulo) _mostrar;
  late void Function(String petId) _atualizar;
  late bool Function() _podeAbrirAgora;

  static const _limite = Duration(seconds: 10);

  /// Cada tentativa de registro; o próprio cliente da API desiste antes.
  static const _limiteDoRegistro = Duration(seconds: 30);

  /// Sair da conta não pode ficar preso esperando a rede.
  static const _limiteAoSair = Duration(seconds: 4);

  /// [logado] emite a cada mudança de sessão. [abrir] navega para uma rota
  /// com o tutor já logado. [podeAbrirAgora] é falso enquanto o app ainda
  /// decide para onde ir (splash): navegar ali seria desfeito pela splash.
  Future<void> iniciar({
    required Stream<bool> logado,
    required void Function(String rota) abrir,
    required void Function(AvisoDoQr aviso, String? titulo) mostrar,
    required void Function(String petId) atualizar,
    bool Function()? podeAbrirAgora,
  }) async {
    _abrir = abrir;
    _mostrar = mostrar;
    _atualizar = atualizar;
    _podeAbrirAgora = podeAbrirAgora ?? () => true;

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

  /// Tenta de novo, com as [_esperasDoRegistro], enquanto o tutor continuar
  /// logado. Sem log do token: ele identifica o aparelho.
  Future<void> _registrar(String token) async {
    for (var tentativa = 0;; tentativa++) {
      if (!_logado || _encerrado) return;
      try {
        await _repo.registrarAparelho(token).timeout(_limiteDoRegistro);
        return;
      } catch (e) {
        if (tentativa >= _esperasDoRegistro.length) {
          debugPrint('Avisos do QR: aparelho não registrado na API '
              '(${e.runtimeType}); tenta de novo na próxima abertura.');
          return;
        }
        await Future<void>.delayed(_esperasDoRegistro[tentativa]);
      }
    }
  }

  void _tocou(Map<String, dynamic> dados) {
    final aviso = AvisoDoQr.doPayload(dados, petsNaApi: _petsNaApi);
    if (aviso == null) return;
    _atualizar(aviso.petId);
    if (_logado && _podeAbrirAgora()) {
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
    _encerrado = true;
    for (final a in _assinaturas) {
      await a.cancel();
    }
    _assinaturas.clear();
  }
}
