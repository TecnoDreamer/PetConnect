// Memorial do Pet — telas, Home e proteção de rotas (docs/features/memorial-pet.md).
// Usa as rotas reais de pet (buildPetRoutes), com os guards de situação.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';
import 'package:pet_connect/features/pet/domain/alteracao_situacao.dart';
import 'package:pet_connect/features/pet/domain/consulta.dart';
import 'package:pet_connect/features/pet/domain/historico_medico.dart';
import 'package:pet_connect/features/pet/domain/localizacao.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/domain/vacina.dart';
import 'package:pet_connect/features/pet/presentation/providers/consulta_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/historico_medico_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/localizacao_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/vacina_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/memorial_screen.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';
import 'package:pet_connect/features/usuario/presentation/screens/home_screen.dart';
import 'package:pet_connect/routing/pet_routes.dart';

import 'fake_pet_repository.dart';

const _tutor = Usuario(
  id: 'uid-1',
  usuarioID: 'uid-1',
  nome: 'Ana Souza',
  email: 'ana@teste.com',
  telefone: '',
  dataNascimento: '',
  genero: '',
);

Pet _pet(
  String nome, {
  String userId = 'uid-1',
  String especie = 'Gato',
  String raca = 'SRD',
  String? foto,
  String? capa,
}) =>
    Pet(
      id: '',
      userId: userId,
      nome: nome,
      especie: especie,
      raca: raca,
      cor: '',
      genero: 'Fêmea',
      porte: '',
      peso: '',
      dataNascimento: '10/02/2015',
      vacinado: true,
      foto: foto,
      capa: capa,
    );

class _Cenario {
  _Cenario(this.repo, this.router, this.leiturasClinicas);

  final FakePetRepository repo;
  final GoRouter router;

  /// Toda vez que alguma tela pede vacinas/consultas/histórico/localização
  /// de um pet, o id aparece aqui.
  final List<String> leiturasClinicas;
}

Future<_Cenario> _abrir(
  WidgetTester tester, {
  FakePetRepository? repo,
  String rotaInicial = '/home',
  AppThemeMode tema = AppThemeMode.padrao,
  Size tamanho = const Size(412, 915),
  double escala = 1.0,
  bool aguardarAnimacoes = true,
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final repositorio = repo ?? FakePetRepository();
  final leituras = <String>[];
  final router = GoRouter(
    initialLocation: rotaInicial,
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      ...buildPetRoutes(),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUsuarioProvider.overrideWith((ref) => Stream.value(_tutor)),
      petRepositoryProvider.overrideWithValue(repositorio),
      vacinasProvider.overrideWith((ref, petId) {
        leituras.add(petId);
        return Stream.value(const <Vacina>[]);
      }),
      consultasProvider.overrideWith((ref, petId) {
        leituras.add(petId);
        return Stream.value(const <Consulta>[]);
      }),
      historicoMedicoProvider.overrideWith((ref, petId) {
        leituras.add(petId);
        return Stream.value(const <HistoricoMedico>[]);
      }),
      localizacoesProvider.overrideWith((ref, petId) {
        leituras.add(petId);
        return Stream.value(const <Localizacao>[]);
      }),
    ],
    child:
        MaterialApp.router(theme: AppTheme.build(tema), routerConfig: router),
  ));
  if (aguardarAnimacoes) {
    await tester.pumpAndSettle();
  } else {
    // Imagens de rede nunca terminam de carregar em teste (o placeholder
    // fica animando), então pumpAndSettle não estabiliza.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  return _Cenario(repositorio, router, leituras);
}

Future<String> _criarFalecido(FakePetRepository repo, Pet pet,
    {String? homenagem, String? data}) async {
  final id = await repo.createPet(pet);
  await repo.alterarSituacao(
    id,
    AlteracaoDeSituacao.registrarFalecimento(
        dataFalecimento: data, homenagem: homenagem),
    atorId: pet.userId,
  );
  return id;
}

void main() {
  group('Home', () {
    testWidgets('lista só os pets ativos e mostra a entrada do Memorial',
        (tester) async {
      final repo = FakePetRepository();
      await repo.createPet(_pet('Rex', especie: 'Cachorro'));
      await _criarFalecido(repo, _pet('Mel'));

      await _abrir(tester, repo: repo);

      expect(find.text('Rex'), findsOneWidget);
      expect(find.text('Mel'), findsNothing,
          reason: 'pet falecido não fica na lista de ativos');
      expect(find.text('Memorial'), findsOneWidget);
      expect(find.bySemanticsLabel('Memorial, 1 pet'), findsOneWidget);
    });

    testWidgets('sem pets falecidos, não há entrada do Memorial',
        (tester) async {
      final repo = FakePetRepository();
      await repo.createPet(_pet('Rex'));

      await _abrir(tester, repo: repo);

      expect(find.text('Memorial'), findsNothing);
    });

    testWidgets('entrada leva à lista do Memorial, sem duplicar pets',
        (tester) async {
      final repo = FakePetRepository();
      await _criarFalecido(repo, _pet('Mel'));
      await _criarFalecido(repo, _pet('Thor', especie: 'Cachorro'));
      await repo.createPet(_pet('Rex'));

      await _abrir(tester, repo: repo);
      await tester.tap(find.text('Memorial'));
      await tester.pumpAndSettle();

      expect(find.text('Mel'), findsOneWidget);
      expect(find.text('Thor'), findsOneWidget);
      expect(find.text('Rex'), findsNothing);
    });
  });

  group('Registrar falecimento', () {
    testWidgets(
        'Configurações do Pet → explicação → confirmação → Memorial; '
        'cancelar não altera nada', (tester) async {
      final repo = FakePetRepository();
      final id = await repo.createPet(_pet('Rex', especie: 'Cachorro'));

      await _abrir(tester, repo: repo, rotaInicial: '/pet/$id/configuracoes');
      await tester.scrollUntilVisible(find.text('Registrar falecimento'), 200);
      await tester.tap(find.text('Registrar falecimento'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhum dado é apagado'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, 'Homenagem (opcional)'),
          'O melhor companheiro.');

      // Primeiro desiste na confirmação.
      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Registrar falecimento'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar registro'), findsOneWidget);
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(repo.eventosSituacao, isEmpty);

      // Agora confirma.
      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Registrar falecimento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();

      expect(find.byType(MemorialScreen), findsOneWidget);
      expect(find.text('Em memória de'), findsOneWidget);
      expect(find.text('O melhor companheiro.'), findsOneWidget);
      expect(repo.eventosSituacao, hasLength(1));
      expect(repo.eventosSituacao.single.atorId, _tutor.id);
    });

    testWidgets('falha ao gravar: avisa e não sai da tela', (tester) async {
      final repo = FakePetRepository();
      final id = await repo.createPet(_pet('Rex'));
      repo.erroAoAlterarSituacao = Exception('offline');

      await _abrir(tester, repo: repo, rotaInicial: '/pet/$id/falecimento');
      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Registrar falecimento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nada foi alterado'), findsOneWidget);
      expect(find.byType(MemorialScreen), findsNothing);
    });

    testWidgets('fonte sem suporte ao Memorial (API): a opção não aparece',
        (tester) async {
      final repo = FakePetRepository()..suportaMemorialFake = false;
      final id = await repo.createPet(_pet('Rex'));

      await _abrir(tester, repo: repo, rotaInicial: '/pet/$id/configuracoes');

      expect(find.text('Registrar falecimento'), findsNothing);
    });
  });

  group('Tela do memorial', () {
    testWidgets('mostra identidade, dados básicos e homenagem', (tester) async {
      final repo = FakePetRepository();
      final id = await _criarFalecido(repo, _pet('Mel', raca: 'Siamês'),
          homenagem: 'Saudades', data: '01/10/2026');

      await _abrir(tester, repo: repo, rotaInicial: '/memorial/$id');

      expect(find.text('Mel'), findsOneWidget);
      expect(find.text('10/02/2015 – 01/10/2026'), findsOneWidget);
      expect(find.text('Gato'), findsOneWidget);
      expect(find.text('Siamês'), findsOneWidget);
      expect(find.text('Saudades'), findsOneWidget);
    });

    testWidgets('campos ausentes não quebram a tela e galeria vazia avisa',
        (tester) async {
      final repo = FakePetRepository();
      final id = await _criarFalecido(
          repo,
          const Pet(
            id: '',
            userId: 'uid-1',
            nome: 'Bidu',
            especie: '',
            raca: '',
            cor: '',
            genero: '',
            porte: '',
            peso: '',
            dataNascimento: '',
            vacinado: false,
          ));

      await _abrir(tester, repo: repo, rotaInicial: '/memorial/$id');

      expect(tester.takeException(), isNull);
      expect(find.text('Bidu'), findsOneWidget);
      expect(find.text('Ainda não há fotos de Bidu.'), findsOneWidget);
    });

    testWidgets('galeria mostra só as fotos do próprio pet', (tester) async {
      final repo = FakePetRepository();
      final mel = await _criarFalecido(
          repo,
          _pet('Mel',
              foto: 'https://img.test/mel-perfil.jpg',
              capa: 'https://img.test/mel-capa.jpg'));
      await _criarFalecido(
          repo, _pet('Thor', foto: 'https://img.test/thor-perfil.jpg'));

      await _abrir(tester,
          repo: repo, rotaInicial: '/memorial/$mel', aguardarAnimacoes: false);

      final urls = tester
          .widgetList<CachedNetworkImage>(find.descendant(
              of: find.byType(MemorialGaleria),
              matching: find.byType(CachedNetworkImage)))
          .map((imagem) => imagem.imageUrl)
          .toSet();
      expect(urls, {
        'https://img.test/mel-perfil.jpg',
        'https://img.test/mel-capa.jpg',
      });
    });

    testWidgets('não mostra nem carrega vacinas, consultas ou histórico',
        (tester) async {
      final repo = FakePetRepository();
      final id = await _criarFalecido(repo, _pet('Mel'));

      final cenario =
          await _abrir(tester, repo: repo, rotaInicial: '/memorial/$id');

      for (final recurso in const [
        'Carteira de Vacinas',
        'Agenda de Consultas',
        'Histórico Médico',
        'QR Code do Pet',
        'Vacinado',
      ]) {
        expect(find.text(recurso), findsNothing, reason: recurso);
      }
      expect(cenario.leiturasClinicas, isEmpty,
          reason: 'o memorial não deveria buscar registros clínicos');
    });
  });

  group('Proteção de rotas', () {
    for (final rota in const [
      '',
      '/vacinas',
      '/vacinas/nova',
      '/consultas',
      '/consultas/nova',
      '/historico',
      '/historico/novo',
      '/localizacao',
      '/localizacao/nova',
      '/editar',
      '/configuracoes',
      '/falecimento',
    ]) {
      testWidgets('pet falecido: /pet/:id$rota fica bloqueada', (tester) async {
        final repo = FakePetRepository();
        final id = await _criarFalecido(repo, _pet('Mel'));

        final cenario =
            await _abrir(tester, repo: repo, rotaInicial: '/pet/$id$rota');

        expect(find.textContaining('Mel está no Memorial'), findsOneWidget);
        expect(cenario.leiturasClinicas, isEmpty);

        await tester.tap(find.text('Abrir memorial'));
        await tester.pumpAndSettle();
        expect(find.byType(MemorialScreen), findsOneWidget);
      });
    }

    testWidgets('memorial de um pet ativo fica bloqueado', (tester) async {
      final repo = FakePetRepository();
      final id = await repo.createPet(_pet('Rex'));

      await _abrir(tester, repo: repo, rotaInicial: '/memorial/$id');

      expect(find.text('Rex não está no Memorial.'), findsOneWidget);
      expect(find.byType(MemorialScreen), findsNothing);
    });

    testWidgets('pet de outro tutor: nem perfil nem memorial', (tester) async {
      final repo = FakePetRepository();
      final id = await _criarFalecido(repo, _pet('Luna', userId: 'uid-2'));

      for (final rota in ['/memorial/$id', '/pet/$id']) {
        await _abrir(tester, repo: repo, rotaInicial: rota);
        expect(find.text('Pet não encontrado.'), findsOneWidget, reason: rota);
        expect(find.byType(MemorialScreen), findsNothing);
      }
    });
  });

  group('Corrigir marcação', () {
    testWidgets('restaura o perfil ativo e o pet volta para a Home',
        (tester) async {
      final repo = FakePetRepository();
      final id = await _criarFalecido(repo, _pet('Mel'));

      final cenario =
          await _abrir(tester, repo: repo, rotaInicial: '/memorial/$id');
      await tester.tap(find.byTooltip('Configurações do memorial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Corrigir informação de falecimento'));
      await tester.pumpAndSettle();
      expect(find.textContaining('exatamente como estavam'), findsOneWidget);
      await tester.tap(find.text('Restaurar perfil'));
      await tester.pumpAndSettle();

      expect(find.byType(MemorialScreen), findsNothing);
      expect(find.text('Carteira de Vacinas'), findsOneWidget,
          reason: 'recursos do perfil ativo voltam a aparecer');
      expect(repo.eventosSituacao.map((e) => e.nova),
          [SituacaoPet.falecido, SituacaoPet.ativo]);

      cenario.router.go('/home');
      await tester.pumpAndSettle();
      expect(find.text('Mel'), findsOneWidget);
      expect(find.text('Memorial'), findsNothing);
    });
  });

  group('Temas, fonte ampliada e telas pequenas', () {
    for (final tema in AppThemeMode.values) {
      testWidgets(
          'memorial, lista e registro em 320x568, fonte 1.3, '
          'tema ${tema.name}', (tester) async {
        final repo = FakePetRepository();
        final mel = await _criarFalecido(repo, _pet('Mel'),
            homenagem: 'Uma homenagem um pouco mais longa para quebrar linha.',
            data: '01/10/2026');
        final rex = await repo.createPet(_pet('Rex'));

        final cenario = await _abrir(tester,
            repo: repo,
            rotaInicial: '/memorial/$mel',
            tema: tema,
            tamanho: const Size(320, 568),
            escala: 1.3);
        expect(tester.takeException(), isNull);

        for (final rota in [
          '/memorial',
          '/memorial/$mel/configuracoes',
          '/pet/$rex/falecimento',
          // /home fica de fora: o cabeçalho da Home já estoura 11px na
          // horizontal em 320px com fonte 1.3, mesmo sem nenhum pet no
          // Memorial — defeito anterior a esta entrega, registrado à parte.
        ]) {
          cenario.router.go(rota);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: rota);
        }
      });
    }
  });
}
