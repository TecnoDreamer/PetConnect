import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_connect/core/network/api_client.dart';
import 'package:pet_connect/core/network/api_exception.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/data/api_atividade_do_qr_repository.dart';
import 'package:pet_connect/features/pet/domain/atividade_do_qr.dart';
import 'package:pet_connect/features/pet/domain/localizacao.dart';
import 'package:pet_connect/features/pet/presentation/providers/abrir_link_provider.dart';
import 'package:pet_connect/features/pet/presentation/providers/localizacao_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/localizacao_list_screen.dart';

/// Relatos e acessos da página pública do QR na aba Localização (issue #37).
const _resposta = {
  'sightings': [
    {
      'id': 's-texto',
      'reportedAt': '2026-11-01T12:00:00Z',
      'description': 'Vi perto da escola',
      'positionSource': 'NONE',
    },
    {
      'id': 's-gps',
      'reportedAt': '2026-11-03T13:30:00Z',
      'latitude': -22.17,
      'longitude': -47.39,
      'accuracyMeters': 35.4,
      'positionSource': 'BROWSER_GEOLOCATION',
      'description': 'Perto da praça',
      'reporterContact': 'Carlos',
    },
    {'id': 'sem-data', 'description': 'ignorado'},
  ],
  'recentAccesses': [
    {'occurredAt': '2026-11-02T10:00:00Z'},
    {'occurredAt': '2026-11-03T13:00:00Z'},
  ],
  'accessesLast30Days': 7,
};

void main() {
  group('AtividadeDoQr.daApi', () {
    final atividade = AtividadeDoQr.daApi(_resposta);

    test('ordena os relatos do mais recente e ignora os sem data', () {
      expect(atividade.avistamentos.map((a) => a.id), ['s-gps', 's-texto']);
    });

    test('separa acessos de avistamentos', () {
      expect(atividade.acessosNosUltimos30Dias, 7);
      expect(atividade.ultimoAcesso,
          DateTime.parse('2026-11-03T13:00:00Z').toLocal());
    });

    test('só relato com coordenada tem link de mapa', () {
      final gps = atividade.avistamentos.first;
      expect(gps.temLocalizacao, isTrue);
      expect(gps.precisaoMetros, 35.4);
      expect(gps.linkDoMapa.toString(),
          'https://www.google.com/maps/search/?api=1&query=-22.17%2C-47.39');
      expect(atividade.avistamentos.last.linkDoMapa, isNull);
    });

    test('resposta vazia não quebra', () {
      final vazia = AtividadeDoQr.daApi(const {});
      expect(vazia.avistamentos, isEmpty);
      expect(vazia.acessosNosUltimos30Dias, 0);
      expect(vazia.ultimoAcesso, isNull);
    });

    test('precisão em metros ou quilômetros', () {
      expect(descreverPrecisao(0.4), 'cerca de 1 m');
      expect(descreverPrecisao(35.4), 'cerca de 35 m');
      expect(descreverPrecisao(1240), 'cerca de 1,2 km');
    });
  });

  group('ApiAtividadeDoQrRepository', () {
    late List<http.Request> chamadas;

    ApiAtividadeDoQrRepository repo(int status,
        {bool porIdDoFirestore = true}) {
      chamadas = [];
      final api = ApiClient(
        baseUrl: 'https://api.exemplo',
        getToken: () async => 'tok',
        httpClient: MockClient((req) async {
          chamadas.add(req);
          return http.Response(
              jsonEncode(status == 200
                  ? _resposta
                  : {
                      'code': 'RESOURCE_NOT_FOUND',
                      'message': 'Pet não encontrado.'
                    }),
              status,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );
      return ApiAtividadeDoQrRepository(
          api: api, porIdDoFirestore: porIdDoFirestore);
    }

    test('pet do Firestore usa a rota legacy-pets com o token', () async {
      final atividade = await repo(200).buscar('fs-1');
      expect(chamadas.single.url.path, '/api/v1/legacy-pets/fs-1/qr-activity');
      expect(chamadas.single.headers['Authorization'], 'Bearer tok');
      expect(atividade.avistamentos, hasLength(2));
    });

    test('pet da API usa a rota pets', () async {
      await repo(200, porIdDoFirestore: false).buscar('api-1');
      expect(chamadas.single.url.path, '/api/v1/pets/api-1/qr-activity');
    });

    test('erro da API sobe como ApiException', () async {
      expect(() => repo(404).buscar('fs-1'), throwsA(isA<ApiException>()));
    });
  });

  group('aba Localização', () {
    final abertos = <Uri>[];

    Future<void> montar(
      WidgetTester tester, {
      List<Localizacao> doTutor = const [],
      Future<AtividadeDoQr?> Function()? atividade,
      bool abrirFunciona = true,
    }) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      abertos.clear();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          localizacoesProvider
              .overrideWith((ref, petId) => Stream.value(doTutor)),
          if (atividade != null)
            atividadeDoQrProvider.overrideWith((ref, petId) => atividade()),
          abrirLinkProvider.overrideWithValue((link) async {
            abertos.add(link);
            return abrirFunciona;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LocalizacaoListScreen(petId: 'pet-1'),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra relatos do QR junto com os do tutor, por data',
        (tester) async {
      await montar(
        tester,
        doTutor: const [
          Localizacao(
              id: 't-1', data: '02/11/2026', descricao: 'Registro do tutor'),
        ],
        atividade: () async => AtividadeDoQr.daApi(_resposta),
      );

      final gps = tester.getTopLeft(find.text('Perto da praça')).dy;
      final tutor = tester.getTopLeft(find.text('Registro do tutor')).dy;
      final texto = tester.getTopLeft(find.text('Vi perto da escola')).dy;
      expect(gps, lessThan(tutor));
      expect(tutor, lessThan(texto));

      expect(find.text('Avistamento pelo QR Code'), findsNWidgets(2));
      expect(
          find.text(
              'Localização do celular de quem escaneou, com precisão de cerca de 35 m'),
          findsOneWidget);
      expect(find.text('Sem localização: relato em texto, não verificado'),
          findsOneWidget);
      expect(find.text('Contato: Carlos'), findsOneWidget);
    });

    testWidgets('localização sem texto aparece como o local do escaneamento',
        (tester) async {
      await montar(
        tester,
        atividade: () async => AtividadeDoQr.daApi(const {
          'sightings': [
            {
              'id': 's-auto',
              'reportedAt': '2026-11-04T09:00:00Z',
              'latitude': -22.17,
              'longitude': -47.39,
              'accuracyMeters': 12,
              'positionSource': 'BROWSER_GEOLOCATION',
            },
          ],
          'recentAccesses': [],
          'accessesLast30Days': 1,
        }),
      );

      expect(find.text('Local onde o QR Code foi escaneado'), findsOneWidget);
      expect(find.text('Avistamento pelo QR Code'), findsNothing);
      expect(find.byKey(const ValueKey('mapa-s-auto')), findsOneWidget);
    });

    testWidgets('resume os acessos sem chamar de avistamento', (tester) async {
      await montar(tester,
          atividade: () async => AtividadeDoQr.daApi(_resposta));

      expect(
          find.textContaining('Página do QR aberta 7 vezes'), findsOneWidget);
      expect(find.textContaining('não confirma que alguém viu o pet'),
          findsOneWidget);
    });

    testWidgets('abrir no mapa usa o ponto do relato', (tester) async {
      await montar(tester,
          atividade: () async => AtividadeDoQr.daApi(_resposta));

      expect(find.text('Abrir no mapa'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mapa-s-gps')));
      await tester.pumpAndSettle();

      expect(abertos.single.queryParameters['query'], '-22.17,-47.39');
    });

    testWidgets('sem app de mapas, avisa', (tester) async {
      await montar(tester,
          atividade: () async => AtividadeDoQr.daApi(_resposta),
          abrirFunciona: false);

      await tester.tap(find.byKey(const ValueKey('mapa-s-gps')));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível abrir o mapa neste aparelho.'),
          findsOneWidget);
    });

    testWidgets('falha da API não esconde os registros do tutor',
        (tester) async {
      await montar(
        tester,
        doTutor: const [
          Localizacao(
              id: 't-1', data: '02/11/2026', descricao: 'Registro do tutor'),
        ],
        atividade: () async => throw const ApiException(
            status: 0, code: 'NETWORK', message: 'sem rede'),
      );

      expect(find.text('Registro do tutor'), findsOneWidget);
      expect(find.text('Não foi possível carregar os avisos do QR Code.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('acessos-do-qr')), findsNothing);
    });

    testWidgets('sem a API configurada, só os registros do tutor',
        (tester) async {
      await montar(tester, doTutor: const [
        Localizacao(
            id: 't-1', data: '02/11/2026', descricao: 'Registro do tutor'),
      ]);

      expect(find.text('Registro do tutor'), findsOneWidget);
      expect(find.byKey(const ValueKey('acessos-do-qr')), findsNothing);
      expect(find.text('Avistamento pelo QR Code'), findsNothing);
    });

    testWidgets('mesmo id na lista do tutor não aparece duas vezes',
        (tester) async {
      await montar(
        tester,
        doTutor: const [
          Localizacao(
              id: 's-gps', data: '03/11/2026', descricao: 'Perto da praça'),
        ],
        atividade: () async => AtividadeDoQr.daApi(_resposta),
      );

      expect(find.text('Perto da praça'), findsOneWidget);
    });
  });
}
