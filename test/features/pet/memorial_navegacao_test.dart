// Memorial do Pet — pilha de navegação ao registrar falecimento, ao corrigir
// a marcação e ao abrir o Memorial sem histórico (link direto, app reaberto).
// O "Voltar" nunca pode deixar a pilha vazia: no Android isso fecha o app
// (docs/features/memorial-retorno-navegacao.md).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:pet_connect/features/pet/presentation/screens/memorial_list_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/memorial_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/pet_detail_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/pet_settings_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/registrar_falecimento_screen.dart';
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

Pet _pet(String nome) => Pet(
      id: '',
      userId: _tutor.id,
      nome: nome,
      especie: 'Gato',
      raca: 'SRD',
      cor: '',
      genero: 'Fêmea',
      porte: '',
      peso: '',
      dataNascimento: '10/02/2015',
      vacinado: true,
    );

class _App {
  _App(this.router, this.fechamentos);

  final GoRouter router;

  /// Quantas vezes o app pediu ao Android para fechar (`SystemNavigator.pop`).
  final List<String> fechamentos;

  /// Telas na pilha atual do go_router, da base para o topo.
  List<String> get pilha => [
        for (final match in router.routerDelegate.currentConfiguration.matches)
          match.matchedLocation,
      ];
}

Future<_App> _abrir(
  WidgetTester tester,
  FakePetRepository repo, {
  String rotaInicial = '/home',
  AppThemeMode tema = AppThemeMode.padrao,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fechamentos = <String>[];
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
    if (chamada.method == 'SystemNavigator.pop') fechamentos.add('fechou');
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));

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
      petRepositoryProvider.overrideWithValue(repo),
      vacinasProvider.overrideWith((ref, _) => Stream.value(const <Vacina>[])),
      consultasProvider
          .overrideWith((ref, _) => Stream.value(const <Consulta>[])),
      historicoMedicoProvider
          .overrideWith((ref, _) => Stream.value(const <HistoricoMedico>[])),
      localizacoesProvider
          .overrideWith((ref, _) => Stream.value(const <Localizacao>[])),
    ],
    child:
        MaterialApp.router(theme: AppTheme.build(tema), routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return _App(router, fechamentos);
}

/// Botão físico ou gesto de voltar do Android.
Future<void> _voltarPeloSistema(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Seta de voltar da AppBar.
Future<void> _voltarPelaAppBar(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

/// Caminho real do usuário: Home → perfil → Configurações do Pet.
Future<void> _irAteConfiguracoes(
    _App app, WidgetTester tester, String id) async {
  app.router.push('/pet/$id');
  await tester.pumpAndSettle();
  app.router.push('/pet/$id/configuracoes');
  await tester.pumpAndSettle();
}

Future<void> _registrarFalecimento(WidgetTester tester) async {
  if (find.byType(RegistrarFalecimentoScreen).evaluate().isEmpty) {
    await tester.scrollUntilVisible(find.text('Registrar falecimento'), 200);
    await tester.tap(find.text('Registrar falecimento'));
    await tester.pumpAndSettle();
  }
  await tester
      .tap(find.widgetWithText(ElevatedButton, 'Registrar falecimento'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Registrar'));
  await tester.pumpAndSettle();
}

void main() {
  group('Registrar falecimento → Voltar', () {
    for (final tema in AppThemeMode.values) {
      testWidgets(
          'tema ${tema.name}: Memorial do pet → Voltar → lista do Memorial → '
          'Voltar → Home, sem fechar o app', (tester) async {
        final repo = FakePetRepository();
        final rex = await repo.createPet(_pet('Rex'));
        await repo.createPet(_pet('Bidu'));
        final app = await _abrir(tester, repo, tema: tema);

        await _irAteConfiguracoes(app, tester, rex);
        await _registrarFalecimento(tester);

        expect(find.byType(MemorialScreen), findsOneWidget);
        expect(app.pilha, ['/memorial', '/memorial/$rex'],
            reason: 'conclusão leva ao memorial com a lista por baixo; nada '
                'do perfil ativo fica na pilha');

        await _voltarPeloSistema(tester);
        expect(find.byType(MemorialListScreen), findsOneWidget);
        expect(find.text('Rex'), findsOneWidget,
            reason: 'o pet recém-arquivado aparece na lista');

        await _voltarPeloSistema(tester);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(app.pilha, ['/home']);
        expect(find.text('Bidu'), findsOneWidget);
        expect(find.text('Rex'), findsNothing,
            reason: 'falecido sai da lista de vivos');
        expect(app.fechamentos, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('seta da AppBar faz o mesmo caminho do botão do sistema',
        (tester) async {
      final repo = FakePetRepository();
      final rex = await repo.createPet(_pet('Rex'));
      final app = await _abrir(tester, repo);

      await _irAteConfiguracoes(app, tester, rex);
      await _registrarFalecimento(tester);

      await _voltarPelaAppBar(tester);
      expect(find.byType(MemorialListScreen), findsOneWidget);
      await _voltarPelaAppBar(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(app.pilha, ['/home']);
      expect(app.fechamentos, isEmpty);
    });

    testWidgets(
        'último pet vivo: Home volta vazia, com a entrada do Memorial, sem '
        'erro', (tester) async {
      final repo = FakePetRepository();
      final rex = await repo.createPet(_pet('Rex'));
      final app = await _abrir(tester, repo);

      await _irAteConfiguracoes(app, tester, rex);
      await _registrarFalecimento(tester);
      await _voltarPeloSistema(tester);
      await _voltarPeloSistema(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Rex'), findsNothing);
      expect(find.text('Memorial'), findsOneWidget);
      expect(app.fechamentos, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('vários pets no Memorial: a lista mostra todos, sem repetir',
        (tester) async {
      final repo = FakePetRepository();
      final mel = await repo.createPet(_pet('Mel'));
      await repo.alterarSituacao(
          mel, AlteracaoDeSituacao.registrarFalecimento(),
          atorId: _tutor.id);
      final rex = await repo.createPet(_pet('Rex'));
      final app = await _abrir(tester, repo);

      await _irAteConfiguracoes(app, tester, rex);
      await _registrarFalecimento(tester);
      await _voltarPeloSistema(tester);

      expect(find.byType(MemorialListScreen), findsOneWidget);
      expect(find.text('Mel'), findsOneWidget);
      expect(find.text('Rex'), findsOneWidget);
    });

    testWidgets(
        'aberto por link direto (sem histórico): Voltar ainda passa pela '
        'lista e chega à Home', (tester) async {
      final repo = FakePetRepository();
      final rex = await repo.createPet(_pet('Rex'));
      final app =
          await _abrir(tester, repo, rotaInicial: '/pet/$rex/falecimento');

      await _registrarFalecimento(tester);
      expect(app.pilha, ['/memorial', '/memorial/$rex']);

      await _voltarPeloSistema(tester);
      expect(find.byType(MemorialListScreen), findsOneWidget);
      await _voltarPeloSistema(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(app.fechamentos, isEmpty);
    });

    testWidgets(
        'falha ao gravar: fica na tela, e Voltar volta às Configurações',
        (tester) async {
      final repo = FakePetRepository();
      final rex = await repo.createPet(_pet('Rex'));
      repo.erroAoAlterarSituacao = Exception('offline');
      final app = await _abrir(tester, repo);

      await _irAteConfiguracoes(app, tester, rex);
      await _registrarFalecimento(tester);

      expect(find.textContaining('Nada foi alterado'), findsOneWidget);
      expect(find.byType(RegistrarFalecimentoScreen), findsOneWidget);
      expect(repo.eventosSituacao, isEmpty);

      await _voltarPeloSistema(tester);
      expect(find.byType(PetSettingsScreen), findsOneWidget);
      expect(app.fechamentos, isEmpty);
    });

    testWidgets('toque duplo em Registrar: um só registro e uma só tela',
        (tester) async {
      final repo = FakePetRepository();
      final rex = await repo.createPet(_pet('Rex'));
      final app =
          await _abrir(tester, repo, rotaInicial: '/pet/$rex/falecimento');

      final botao =
          find.widgetWithText(ElevatedButton, 'Registrar falecimento');
      await tester.tap(botao);
      await tester.tap(botao, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Confirmar registro'), findsOneWidget);
      await tester.tap(find.text('Registrar'));
      await tester.tap(find.text('Registrar'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repo.eventosSituacao, hasLength(1));
      expect(app.pilha, ['/memorial', '/memorial/$rex']);
    });
  });

  group('Memorial sem histórico de navegação', () {
    testWidgets('lista aberta direto: seta e botão do sistema levam à Home',
        (tester) async {
      final repo = FakePetRepository();
      final app = await _abrir(tester, repo, rotaInicial: '/memorial');

      expect(find.byType(BackButton), findsOneWidget,
          reason: 'a AppBar oferece o voltar mesmo sem histórico');
      await _voltarPeloSistema(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(app.fechamentos, isEmpty);

      app.router.go('/memorial');
      await tester.pumpAndSettle();
      await _voltarPelaAppBar(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('memorial de um pet aberto direto: lista e depois Home',
        (tester) async {
      final repo = FakePetRepository();
      final mel = await repo.createPet(_pet('Mel'));
      await repo.alterarSituacao(
          mel, AlteracaoDeSituacao.registrarFalecimento(),
          atorId: _tutor.id);
      final app = await _abrir(tester, repo, rotaInicial: '/memorial/$mel');

      expect(app.pilha, ['/memorial', '/memorial/$mel']);
      await _voltarPeloSistema(tester);
      expect(find.byType(MemorialListScreen), findsOneWidget);
      await _voltarPeloSistema(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(app.fechamentos, isEmpty);
    });

    testWidgets(
        'pet já falecido aberto pelo perfil antigo: "Abrir memorial" e Voltar '
        'chegam à Home', (tester) async {
      final repo = FakePetRepository();
      final mel = await repo.createPet(_pet('Mel'));
      await repo.alterarSituacao(
          mel, AlteracaoDeSituacao.registrarFalecimento(),
          atorId: _tutor.id);
      final app =
          await _abrir(tester, repo, rotaInicial: '/pet/$mel/falecimento');

      await tester.tap(find.text('Abrir memorial'));
      await tester.pumpAndSettle();
      expect(find.byType(MemorialScreen), findsOneWidget);

      await _voltarPeloSistema(tester);
      await _voltarPeloSistema(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(app.fechamentos, isEmpty);
    });

    testWidgets('app reaberto depois do registro: Home sem o pet, Memorial com',
        (tester) async {
      final repo = FakePetRepository();
      final rex = await repo.createPet(_pet('Rex'));
      await repo.alterarSituacao(
          rex, AlteracaoDeSituacao.registrarFalecimento(),
          atorId: _tutor.id);
      final app = await _abrir(tester, repo);

      expect(find.text('Rex'), findsNothing);
      await tester.tap(find.text('Memorial'));
      await tester.pumpAndSettle();
      expect(find.text('Rex'), findsOneWidget);
      expect(app.pilha, ['/home', '/memorial']);
    });
  });

  group('Corrigir marcação → Voltar', () {
    testWidgets('perfil restaurado: Voltar leva à Home, sem fechar o app',
        (tester) async {
      final repo = FakePetRepository();
      final mel = await repo.createPet(_pet('Mel'));
      await repo.alterarSituacao(
          mel, AlteracaoDeSituacao.registrarFalecimento(),
          atorId: _tutor.id);
      final app = await _abrir(tester, repo);

      await tester.tap(find.text('Memorial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Configurações do memorial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Corrigir informação de falecimento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar perfil'));
      await tester.pumpAndSettle();

      expect(find.byType(PetDetailScreen), findsOneWidget);
      await _voltarPeloSistema(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Mel'), findsOneWidget);
      expect(app.fechamentos, isEmpty);
    });
  });
}
