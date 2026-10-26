// Testa o redesign da Home do tutor
// (prompt_redesign_home_tutor_petconnect.md, 2026-09-13): cabeçalho com
// avatar + saudação + menu "⋮", título "Meus Pets" com o botão "Adicionar
// pet" na mesma linha, cards de pet no novo layout uniforme, e o badge
// "Vacina pendente" (ausência total de vacinas cadastradas — não
// representa calendário vacinal atrasado, ver docs/features/tutor-home.md).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/domain/vacina.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/vacina_providers.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';
import 'package:pet_connect/features/usuario/presentation/screens/home_screen.dart';

import '../pet/fake_pet_repository.dart';

const _tutor = Usuario(
  id: 'uid-1',
  usuarioID: 'uid-1',
  nome: 'Aleksander Silva',
  email: 'tutor@teste.com',
  telefone: '',
  dataNascimento: '',
  genero: '',
);

Pet _pet({
  required String id,
  required String nome,
  String especie = 'Cachorro',
  String genero = 'Macho',
  String dataNascimento = '',
  String? foto,
}) {
  return Pet(
    id: id,
    userId: 'uid-1',
    nome: nome,
    especie: especie,
    raca: '',
    cor: '',
    genero: genero,
    porte: '',
    peso: '',
    dataNascimento: dataNascimento,
    vacinado: false,
    foto: foto,
  );
}

/// Monta a Home com go_router e telas-marcador para as rotas de destino —
/// só pra confirmar que a navegação acontece, sem montar as telas reais.
///
/// Por padrão nenhum pet tem vacina cadastrada (`vacinasProvider` retorna
/// lista vazia), já que a maioria dos testes aqui não é sobre o badge de
/// vacina — só os que precisam de outro comportamento passam
/// [overrideVacinas].
Widget _appPara(
  FakePetRepository repo, {
  Usuario? usuario = _tutor,
  Override? overrideUsuario,
  Override? overridePets,
  Override? overrideVacinas,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/pet/novo',
        builder: (context, state) =>
            const Scaffold(body: Text('Tela Cadastrar Pet')),
      ),
      GoRoute(
        path: '/pet/:id',
        builder: (context, state) => Scaffold(
          body: Text('Tela Perfil: ${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/configuracoes',
        builder: (context, state) =>
            const Scaffold(body: Text('Tela Configurações do Tutor')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      overrideUsuario ??
          currentUsuarioProvider.overrideWith((ref) => Stream.value(usuario)),
      petRepositoryProvider.overrideWithValue(repo),
      overridePets ??
          petsProvider.overrideWith((ref) => repo.watchPets(_tutor.id)),
      overrideVacinas ??
          vacinasProvider
              .overrideWith((ref, petId) => Stream.value(const <Vacina>[])),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  group('HomeScreen — cabeçalho', () {
    testWidgets(
        'mostra ícone padrão (sem foto), saudação com o nome real e o menu ⋮',
        (tester) async {
      final repo = FakePetRepository();

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      expect(find.text('Olá, Aleksander!'), findsOneWidget);
      expect(
          find.text('Selecione um pet para acessar o perfil'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      // O antigo ícone de engrenagem foi substituído pelo "⋮".
      expect(find.byIcon(Icons.settings_outlined), findsNothing);
    });

    testWidgets('sem nome de usuário disponível ainda, mostra "Olá!" genérico',
        (tester) async {
      final repo = FakePetRepository();

      await tester.pumpWidget(_appPara(repo, usuario: null));
      await tester.pumpAndSettle();

      expect(find.text('Olá!'), findsOneWidget);
    });

    testWidgets('toque no menu ⋮ abre as configurações do tutor',
        (tester) async {
      final repo = FakePetRepository();

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Tela Configurações do Tutor'), findsOneWidget);
    });
  });

  group('HomeScreen — "Adicionar pet"', () {
    testWidgets('aparece na mesma linha do título "Meus Pets"', (tester) async {
      final repo = FakePetRepository();

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      expect(find.text('Meus Pets'), findsOneWidget);
      expect(find.text('Adicionar pet'), findsOneWidget);

      final tituloRow = tester.widget<Row>(find.ancestor(
        of: find.text('Meus Pets'),
        matching: find.byType(Row),
      ));
      expect(
        find.descendant(
            of: find.byWidget(tituloRow), matching: find.text('Adicionar pet')),
        findsOneWidget,
        reason: '"Adicionar pet" deve estar na mesma Row do título',
      );
    });

    testWidgets('toque leva ao cadastro de um novo pet', (tester) async {
      final repo = FakePetRepository();

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Adicionar pet'));
      await tester.pumpAndSettle();

      expect(find.text('Tela Cadastrar Pet'), findsOneWidget);
    });
  });

  group('HomeScreen — card do pet', () {
    testWidgets('mostra foto (fallback), nome, espécie, gênero e chevron',
        (tester) async {
      final repo = FakePetRepository();
      await repo.createPet(
          _pet(id: '', nome: 'Rex', especie: 'Cachorro', genero: 'Macho'));

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      expect(find.text('Rex'), findsOneWidget);
      expect(find.textContaining('Cachorro'), findsOneWidget);
      expect(find.text('Macho'), findsOneWidget);
      expect(find.byIcon(Icons.pets), findsWidgets); // badge de pata
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('cada card abre o perfil do pet correto', (tester) async {
      final repo = FakePetRepository();
      final idRex = await repo.createPet(_pet(id: '', nome: 'Rex'));
      await repo.createPet(_pet(id: '', nome: 'Nina', genero: 'Fêmea'));

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rex'));
      await tester.pumpAndSettle();

      expect(find.text('Tela Perfil: $idRex'), findsOneWidget);
    });

    testWidgets('badge de gênero mostra "Fêmea" com ícone de fêmea',
        (tester) async {
      final repo = FakePetRepository();
      await repo.createPet(_pet(id: '', nome: 'Nina', genero: 'Fêmea'));

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      expect(find.text('Fêmea'), findsOneWidget);
      expect(find.byIcon(Icons.female), findsOneWidget);
    });
  });

  group('HomeScreen — badge "Vacina pendente"', () {
    testWidgets('pet sem nenhuma vacina cadastrada mostra o badge',
        (tester) async {
      final repo = FakePetRepository();
      await repo.createPet(_pet(id: '', nome: 'Rex'));

      // Override padrão de _appPara já devolve lista vazia de vacinas.
      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      expect(find.text('Vacina pendente'), findsOneWidget);
    });

    testWidgets('pet com ao menos uma vacina cadastrada não mostra o badge',
        (tester) async {
      final repo = FakePetRepository();
      final id = await repo.createPet(_pet(id: '', nome: 'Rex'));

      await tester.pumpWidget(_appPara(
        repo,
        overrideVacinas: vacinasProvider.overrideWith((ref, petId) {
          if (petId == id) {
            return Stream.value(const [
              Vacina(id: 'v1', nome: 'Raiva', dataAplicacao: '01/01/2024'),
            ]);
          }
          return Stream.value(const <Vacina>[]);
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Rex'), findsOneWidget);
      expect(find.text('Vacina pendente'), findsNothing);
    });

    testWidgets(
        'enquanto o status de vacina ainda está carregando, não mostra o badge (nem verdadeiro nem falso)',
        (tester) async {
      final repo = FakePetRepository();
      await repo.createPet(_pet(id: '', nome: 'Rex'));

      final controller = StreamController<List<Vacina>>();
      addTearDown(controller.close);

      await tester.pumpWidget(_appPara(
        repo,
        overrideVacinas:
            vacinasProvider.overrideWith((ref, petId) => controller.stream),
      ));
      // Sem pumpAndSettle: o provider fica propositalmente "pendurado" em
      // loading (o controller nunca emite).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rex'), findsOneWidget);
      expect(find.text('Vacina pendente'), findsNothing);
    });

    testWidgets(
        'erro ao carregar vacinas não é tratado como "sem vacina" (não mostra o badge)',
        (tester) async {
      final repo = FakePetRepository();
      await repo.createPet(_pet(id: '', nome: 'Rex'));

      await tester.pumpWidget(_appPara(
        repo,
        overrideVacinas: vacinasProvider
            .overrideWith((ref, petId) => Stream.error(Exception('boom'))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rex'), findsOneWidget);
      expect(find.text('Vacina pendente'), findsNothing);
    });
  });

  group('HomeScreen — estados', () {
    testWidgets('sem pets cadastrados mostra a mensagem de lista vazia',
        (tester) async {
      final repo = FakePetRepository();

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Você ainda não cadastrou nenhum pet'),
          findsOneWidget);
    });

    testWidgets('erro ao carregar os dados do tutor mostra mensagem amigável',
        (tester) async {
      final repo = FakePetRepository();

      await tester.pumpWidget(_appPara(
        repo,
        overrideUsuario: currentUsuarioProvider
            .overrideWith((ref) => Stream.error(Exception('boom'))),
      ));
      await tester.pumpAndSettle();

      expect(
          find.text('Não foi possível carregar seus dados.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('erro ao carregar os pets mostra mensagem amigável',
        (tester) async {
      final repo = FakePetRepository();

      await tester.pumpWidget(_appPara(
        repo,
        overridePets:
            petsProvider.overrideWith((ref) => Stream.error(Exception('boom'))),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar seus pets.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('HomeScreen — responsividade', () {
    testWidgets(
        'largura reduzida (320px), nome longo e badge de vacina: sem overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakePetRepository();
      await repo.createPet(_pet(
        id: '',
        nome: 'Alexandreverson Von Schwarzenegger Pettersen III',
        especie: 'Cachorro',
        genero: 'Fêmea',
      ));

      await tester.pumpWidget(_appPara(repo));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Vacina pendente'), findsOneWidget);
    });

    // Regressão: em 320x568 com fonte 1.3 a Home estourava ("A RenderFlex
    // overflowed by 11 pixels on the right").
    for (final escala in [1.0, 1.3]) {
      testWidgets('tela 320x568 com fonte $escala e um pet: sem overflow',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = escala;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final repo = FakePetRepository();
        await repo.createPet(_pet(id: '', nome: 'Rex'));

        await tester.pumpWidget(_appPara(repo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Meus Pets'), findsOneWidget);
        expect(find.text('Adicionar pet'), findsOneWidget);
        expect(find.text('Rex'), findsOneWidget);
      });
    }
  });
}
