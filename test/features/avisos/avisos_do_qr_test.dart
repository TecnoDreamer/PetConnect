import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_connect/core/network/api_client.dart';
import 'package:pet_connect/features/avisos/application/avisos_do_qr.dart';
import 'package:pet_connect/features/avisos/data/api_avisos_repository.dart';
import 'package:pet_connect/features/avisos/domain/aviso_do_qr.dart';

/// Avisos do QR por push no app (issue #36).
class _Push implements PushDoAparelho {
  PermissaoDeAviso resposta = PermissaoDeAviso.concedida;
  String? tokenAtual = 'token-1';
  int pedidos = 0;
  bool apagou = false;
  Map<String, dynamic>? inicial;

  final tokens = StreamController<String>.broadcast();
  final abertos = StreamController<MensagemDePush>.broadcast();
  final tocados = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Future<PermissaoDeAviso> pedirPermissao() async {
    pedidos++;
    return resposta;
  }

  @override
  Future<PermissaoDeAviso> permissao() async => resposta;

  @override
  Future<String?> token() async => tokenAtual;

  @override
  Stream<String> get tokensNovos => tokens.stream;

  @override
  Stream<MensagemDePush> get avisosComOAppAberto => abertos.stream;

  @override
  Stream<Map<String, dynamic>> get avisosTocados => tocados.stream;

  @override
  Future<Map<String, dynamic>?> avisoQueAbriuOApp() async => inicial;

  @override
  Future<void> apagarToken() async => apagou = true;
}

class _Repo implements AvisosRepository {
  final registrados = <String>[];
  final removidos = <String>[];
  bool falhar = false;

  /// Falhas antes de responder, como a API acordando no Render.
  int falhasAteAcordar = 0;
  int tentativas = 0;

  @override
  Future<void> registrarAparelho(String token) async {
    tentativas++;
    if (falhar) throw Exception('sem rede');
    if (falhasAteAcordar > 0) {
      falhasAteAcordar--;
      throw TimeoutException('API acordando');
    }
    registrados.add(token);
  }

  @override
  Future<void> removerAparelho(String token) async {
    if (falhar) throw Exception('sem rede');
    removidos.add(token);
  }

  @override
  Future<PreferenciasDeAviso> preferencias(String petId) =>
      throw UnimplementedError();

  @override
  Future<PreferenciasDeAviso> salvarPreferencias(
          String petId, PreferenciasDeAviso p) =>
      throw UnimplementedError();
}

/// Espera as novas tentativas do registro, sem depender de quão ocupada a
/// máquina está (com uma espera fixa, o teste falhava na suíte completa).
Future<void> _ate(bool Function() condicao) async {
  final limite = DateTime.now().add(const Duration(seconds: 5));
  while (!condicao() && DateTime.now().isBefore(limite)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

const _acesso = {
  'type': 'qr_access',
  'firestorePetId': 'fs-rex',
  'apiPetId': 'api-rex',
};

void main() {
  group('AvisoDoQr.doPayload', () {
    test('usa o id do modo do app', () {
      expect(AvisoDoQr.doPayload(_acesso, petsNaApi: false)!.rota,
          '/pet/fs-rex/localizacao');
      expect(AvisoDoQr.doPayload(_acesso, petsNaApi: true)!.petId, 'api-rex');
      expect(
          AvisoDoQr.doPayload({'type': 'sighting', 'firestorePetId': 'fs-1'},
                  petsNaApi: false)!
              .tipo,
          TipoDeAvisoDoQr.avistamento);
    });

    test('ignora payload que não é do QR ou com id estranho', () {
      expect(
          AvisoDoQr.doPayload({'type': 'outro', 'firestorePetId': 'x'},
              petsNaApi: false),
          isNull);
      expect(
          AvisoDoQr.doPayload({'type': 'qr_access'}, petsNaApi: false), isNull);
      expect(
          AvisoDoQr.doPayload(
              {'type': 'qr_access', 'firestorePetId': '../configuracoes'},
              petsNaApi: false),
          isNull);
    });
  });

  group('AvisosDoQr', () {
    late _Push push;
    late _Repo repo;
    late StreamController<bool> sessao;
    late AvisosDoQr avisos;
    late List<String> abertas;
    late List<String> atualizados;
    late List<String?> mostrados;

    late bool naSplash;

    Future<void> iniciar() async {
      await avisos.iniciar(
        logado: sessao.stream,
        abrir: abertas.add,
        mostrar: (aviso, titulo) => mostrados.add(titulo),
        atualizar: atualizados.add,
        podeAbrirAgora: () => !naSplash,
      );
    }

    setUp(() {
      push = _Push();
      repo = _Repo();
      sessao = StreamController<bool>.broadcast();
      avisos = AvisosDoQr(
        push: push,
        repository: repo,
        petsNaApi: false,
        esperasDoRegistro: const [
          Duration(milliseconds: 1),
          Duration(milliseconds: 1),
          Duration(milliseconds: 1),
        ],
      );
      abertas = [];
      atualizados = [];
      mostrados = [];
      naSplash = false;
    });

    tearDown(() => avisos.encerrar());

    test('registra o aparelho depois do login, com permissão', () async {
      await iniciar();
      expect(repo.registrados, isEmpty);

      sessao.add(true);
      await pumpEventQueue();

      expect(push.pedidos, 1);
      expect(repo.registrados, ['token-1']);
    });

    test('sem permissão, não registra', () async {
      push.resposta = PermissaoDeAviso.negada;
      await iniciar();

      sessao.add(true);
      await pumpEventQueue();

      expect(repo.registrados, isEmpty);
    });

    test('token novo é registrado só com login', () async {
      await iniciar();
      push.tokens.add('token-antes-do-login');
      await pumpEventQueue();
      expect(repo.registrados, isEmpty);

      sessao.add(true);
      await pumpEventQueue();
      push.tokens.add('token-2');
      await pumpEventQueue();

      expect(repo.registrados, ['token-1', 'token-2']);
    });

    test('falha da API no registro não derruba nada', () async {
      repo.falhar = true;
      await iniciar();

      sessao.add(true);
      await _ate(() => repo.tentativas >= 4);
      // Folga para uma tentativa a mais aparecer, se houvesse.
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(repo.registrados, isEmpty);
      expect(repo.tentativas, 4, reason: 'a primeira e mais 3 tentativas');
    });

    test('com a API acordando, tenta de novo e registra o aparelho', () async {
      repo.falhasAteAcordar = 2;
      await iniciar();

      sessao.add(true);
      await _ate(() => repo.registrados.isNotEmpty);

      expect(repo.registrados, ['token-1']);
      expect(repo.tentativas, 3);
    });

    test('para de tentar depois de sair da conta', () async {
      repo.falhar = true;
      avisos = AvisosDoQr(
        push: push,
        repository: repo,
        petsNaApi: false,
        esperasDoRegistro: const [Duration(milliseconds: 30)],
      );
      await iniciar();

      sessao.add(true);
      await pumpEventQueue();
      sessao.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(repo.tentativas, 1);
    });

    test('nas esperas padrão, cobre o tempo da API acordar', () {
      final total = AvisosDoQr.esperasPadraoDoRegistro
          .fold(Duration.zero, (soma, espera) => soma + espera);
      expect(total, greaterThanOrEqualTo(const Duration(seconds: 60)));
    });

    test('toque com login abre a aba Localização do pet', () async {
      await iniciar();
      sessao.add(true);
      await pumpEventQueue();

      push.tocados.add(_acesso);
      await pumpEventQueue();

      expect(abertas, ['/pet/fs-rex/localizacao']);
      expect(atualizados, ['fs-rex']);
    });

    test('notificação que abriu o app espera o login e a Home', () async {
      push.inicial = {'type': 'sighting', 'firestorePetId': 'fs-rex'};
      await iniciar();
      expect(abertas, isEmpty);

      avisos.abrirQuandoPossivel();
      expect(abertas, isEmpty, reason: 'ainda sem login');

      sessao.add(true);
      await pumpEventQueue();
      avisos.abrirQuandoPossivel();
      avisos.abrirQuandoPossivel();

      expect(abertas, ['/pet/fs-rex/localizacao']);
    });

    test('com a sessão guardada, o toque que abriu o app espera sair da splash',
        () async {
      naSplash = true;
      await iniciar();
      sessao.add(true);
      await pumpEventQueue();

      push.tocados.add(_acesso);
      await pumpEventQueue();
      expect(abertas, isEmpty, reason: 'a splash ainda vai navegar');

      naSplash = false;
      avisos.abrirQuandoPossivel();
      expect(abertas, ['/pet/fs-rex/localizacao']);
    });

    test('com o app aberto, mostra o aviso e atualiza o pet', () async {
      await iniciar();
      sessao.add(true);
      await pumpEventQueue();

      push.abertos.add(const MensagemDePush(
          titulo: 'O QR Code de Rex foi acessado', dados: _acesso));
      push.abertos.add(const MensagemDePush(dados: {'type': 'outro'}));
      await pumpEventQueue();

      expect(mostrados, ['O QR Code de Rex foi acessado']);
      expect(atualizados, ['fs-rex']);
      expect(abertas, isEmpty);
    });

    test('sair da conta remove o token na API e no aparelho', () async {
      await iniciar();

      await avisos.esquecerAparelho();

      expect(repo.removidos, ['token-1']);
      expect(push.apagou, isTrue);
    });

    test('sair sem rede ainda apaga o token do aparelho', () async {
      repo.falhar = true;
      await iniciar();

      await avisos.esquecerAparelho();

      expect(push.apagou, isTrue);
    });
  });

  group('ApiAvisosRepository', () {
    late List<http.Request> chamadas;

    ApiAvisosRepository repo({bool porIdDoFirestore = true}) {
      chamadas = [];
      return ApiAvisosRepository(
        porIdDoFirestore: porIdDoFirestore,
        api: ApiClient(
          baseUrl: 'https://api.exemplo',
          getToken: () async => 'tok',
          httpClient: MockClient((req) async {
            chamadas.add(req);
            if (req.url.path.endsWith('notification-preferences')) {
              return http.Response(
                  jsonEncode(
                      {'notifyOnAccess': false, 'notifyOnSighting': true}),
                  200,
                  headers: {'content-type': 'application/json'});
            }
            return http.Response('', 204);
          }),
        ),
      );
    }

    test('token vai no corpo, nunca na URL', () async {
      final r = repo();
      await r.registrarAparelho('segredo-do-aparelho');
      await r.removerAparelho('segredo-do-aparelho');

      expect(chamadas.map((c) => c.method), ['PUT', 'DELETE']);
      for (final c in chamadas) {
        expect(c.url.path, '/api/v1/me/push-devices');
        expect(c.url.toString(), isNot(contains('segredo')));
        expect(jsonDecode(c.body)['token'], 'segredo-do-aparelho');
      }
    });

    test('preferências pela rota do modo do app', () async {
      final p = await repo().preferencias('fs-1');
      expect(chamadas.single.url.path,
          '/api/v1/legacy-pets/fs-1/notification-preferences');
      expect(p.avisarAcesso, isFalse);
      expect(p.avisarAvistamento, isTrue);

      await repo(porIdDoFirestore: false).salvarPreferencias(
          'api-1',
          const PreferenciasDeAviso(
              avisarAcesso: true, avisarAvistamento: false));
      expect(chamadas.single.url.path,
          '/api/v1/pets/api-1/notification-preferences');
      expect(jsonDecode(chamadas.single.body),
          {'notifyOnAccess': true, 'notifyOnSighting': false});
    });
  });
}
