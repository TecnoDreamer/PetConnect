// Galeria de fotos por pet — telas, rotas e Memorial
// (docs/features/galeria-fotos-pet.md). Usa as rotas reais de pet
// (buildPetRoutes), com os guards.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';
import 'package:pet_connect/features/pet/domain/alteracao_situacao.dart';
import 'package:pet_connect/features/pet/domain/consulta.dart';
import 'package:pet_connect/features/pet/domain/envio_de_fotos.dart';
import 'package:pet_connect/features/pet/domain/historico_medico.dart';
import 'package:pet_connect/features/pet/domain/localizacao.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/domain/vacina.dart';
import 'package:pet_connect/features/pet/presentation/providers/consulta_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/galeria_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/historico_medico_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/localizacao_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/vacina_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/publicar_fotos_screen.dart';
import 'package:pet_connect/features/pet/presentation/widgets/foto_miniatura.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';
import 'package:pet_connect/routing/pet_routes.dart';

import 'fake_galeria_repository.dart';
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

Pet _pet(String nome, {String userId = 'uid-1'}) => Pet(
      id: '',
      userId: userId,
      nome: nome,
      especie: 'Cachorro',
      raca: 'SRD',
      cor: '',
      genero: 'Macho',
      porte: '',
      peso: '',
      dataNascimento: '10/02/2015',
      vacinado: true,
    );

class _Cenario {
  _Cenario(this.pets, this.galeria, this.router, this.leiturasClinicas);

  final FakePetRepository pets;
  final FakeGaleriaRepository galeria;
  final GoRouter router;
  final List<String> leiturasClinicas;
}

Future<_Cenario> _abrir(
  WidgetTester tester, {
  required FakePetRepository pets,
  FakeGaleriaRepository? galeria,
  required String rota,
  bool galeriaDisponivel = true,
  AppThemeMode tema = AppThemeMode.padrao,
  Size tamanho = const Size(412, 915),
  double escala = 1.0,
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final fotos = galeria ?? FakeGaleriaRepository();
  final leituras = <String>[];
  final router = GoRouter(initialLocation: rota, routes: buildPetRoutes());

  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUsuarioProvider.overrideWith((ref) => Stream.value(_tutor)),
      petRepositoryProvider.overrideWithValue(pets),
      galeriaRepositoryProvider.overrideWithValue(fotos),
      galeriaDisponivelProvider.overrideWithValue(galeriaDisponivel),
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
  await _assentar(tester);
  return _Cenario(pets, fotos, router, leituras);
}

/// Imagens de rede nunca terminam de carregar em teste (o placeholder fica
/// esperando), então pumpAndSettle não estabiliza; avança o tempo das
/// transições.
Future<void> _assentar(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<String> _falecido(FakePetRepository repo, Pet pet) async {
  final id = await repo.createPet(pet);
  await repo.alterarSituacao(id, AlteracaoDeSituacao.registrarFalecimento(),
      atorId: pet.userId);
  return id;
}

Finder _miniatura(String rotulo) => find.bySemanticsLabel(
    RegExp('^${RegExp.escape(rotulo)}(:.*)?\\. Toque para ampliar\\.\$'));

void main() {
  group('Grade', () {
    testWidgets('pet sem fotos: estado vazio com "Adicionar primeira foto"',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet('Rex'));

      await _abrir(tester, pets: pets, rota: '/pet/$id/fotos');

      expect(find.text('Fotos de Rex'), findsOneWidget);
      expect(find.text('Nenhuma foto ainda'), findsOneWidget);
      expect(find.text('Adicionar primeira foto'), findsOneWidget);
      expect(find.byType(FotoMiniatura), findsNothing);
      expect(find.text('Adicionar fotos'), findsNothing,
          reason: 'sem fotos, o botão flutuante não aparece (já há o CTA)');
    });

    testWidgets(
        'três colunas, mais recentes primeiro, e a próxima página ao rolar',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet('Rex'));
      final galeria = FakeGaleriaRepository()..semear(id, 40);

      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id/fotos');

      final grade = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grade.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(_miniatura('Foto 1 de Rex'), findsOneWidget);
      // A primeira da lista é a mais recente.
      final primeira =
          tester.widget<FotoMiniatura>(find.byType(FotoMiniatura).first);
      expect(primeira.foto.id, galeria.fotosDe(id).first.id);
      expect(primeira.foto.miniaturaUrl, contains('c_fill,w_360,h_360'));
      // Primeira página: 30. A seguinte começa depois da 30ª (pode já ter
      // sido pedida, se a primeira quase não encheu a tela).
      expect(galeria.listagens.first.depoisDe, isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await _assentar(tester);

      expect(galeria.listagens, hasLength(2));
      expect(galeria.listagens.last.depoisDe, galeria.fotosDe(id)[29].id);
      // A mais antiga (40ª) só existe na segunda página.
      final maisAntiga = galeria.fotosDe(id).last.id;
      await tester.scrollUntilVisible(
        find.byWidgetPredicate(
            (w) => w is FotoMiniatura && w.foto.id == maisAntiga),
        300,
        scrollable: find.byType(Scrollable).first,
      );
    });

    testWidgets('erro ao carregar: aviso e "Tentar de novo"', (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet('Rex'));
      final galeria = FakeGaleriaRepository()
        ..semear(id, 2)
        ..falharListagem = true;

      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id/fotos');
      expect(find.textContaining('Não foi possível carregar as fotos'),
          findsOneWidget);

      galeria.falharListagem = false;
      await tester.tap(find.text('Tentar de novo'));
      await _assentar(tester);

      expect(find.byType(FotoMiniatura), findsNWidgets(2));
    });

    testWidgets('trocar de pet não mistura as fotos', (tester) async {
      final pets = FakePetRepository();
      final rex = await pets.createPet(_pet('Rex'));
      final mel = await pets.createPet(_pet('Mel'));
      final galeria = FakeGaleriaRepository()
        ..semear(rex, 4)
        ..semear(mel, 1);

      final cenario = await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$rex/fotos');
      expect(find.byType(FotoMiniatura), findsNWidgets(4));

      cenario.router.go('/pet/$mel/fotos');
      await _assentar(tester);

      final mostradas = tester
          .widgetList<FotoMiniatura>(find.byType(FotoMiniatura))
          .map((m) => m.foto.petId)
          .toSet();
      expect(mostradas, {mel});
      expect(find.byType(FotoMiniatura), findsOneWidget);
    });
  });

  group('Visualizador', () {
    testWidgets('abre na foto tocada, mostra legenda e data, desliza',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet('Rex'));
      final galeria = FakeGaleriaRepository()
        ..semear(id, 3, legenda: 'Na praia');

      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id/fotos');
      await tester.tap(find.byType(FotoMiniatura).at(1));
      await _assentar(tester);

      expect(find.text('2 de 3'), findsOneWidget);
      expect(find.text('Na praia'), findsOneWidget);
      expect(find.textContaining('Publicada em'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await _assentar(tester);
      expect(find.text('3 de 3'), findsOneWidget);

      await tester.pageBack();
      await _assentar(tester);
      expect(find.text('Fotos de Rex'), findsOneWidget);
    });

    testWidgets('excluir pede confirmação; cancelar mantém, confirmar remove',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet('Rex'));
      final galeria = FakeGaleriaRepository()..semear(id, 2);
      final alvo = galeria.fotosDe(id).first;

      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id/fotos');
      await tester.tap(find.byType(FotoMiniatura).first);
      await _assentar(tester);

      await tester.tap(find.byTooltip('Excluir foto'));
      await _assentar(tester);
      expect(find.text('Excluir esta foto?'), findsOneWidget);
      expect(find.textContaining('não pode ser recuperada'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await _assentar(tester);
      expect(galeria.fotosDe(id), hasLength(2));

      await tester.tap(find.byTooltip('Excluir foto'));
      await _assentar(tester);
      await tester.tap(find.text('Excluir'));
      await _assentar(tester);

      expect(galeria.fotosDe(id).map((f) => f.id), isNot(contains(alvo.id)));
      expect(find.text('Foto excluída.'), findsOneWidget);
      expect(find.text('1 de 1'), findsOneWidget);
    });

    testWidgets('falha ao excluir: avisa e a foto continua', (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet('Rex'));
      final galeria = FakeGaleriaRepository()
        ..semear(id, 1)
        ..falharExclusao = true;

      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id/fotos');
      await tester.tap(find.byType(FotoMiniatura).first);
      await _assentar(tester);
      await tester.tap(find.byTooltip('Excluir foto'));
      await _assentar(tester);
      await tester.tap(find.text('Excluir'));
      await _assentar(tester);

      expect(find.textContaining('Não foi possível excluir a foto'),
          findsOneWidget);
      expect(galeria.fotosDe(id), hasLength(1));
      expect(find.text('1 de 1'), findsOneWidget);
    });
  });

  group('Publicar', () {
    Future<void> publicarDaGaleria(WidgetTester tester, String petId,
        FakePetRepository pets, int quantas) async {
      final pet = (await pets.watchPet(petId).first)!;
      final navegador =
          tester.state<NavigatorState>(find.byType(Navigator).last);
      navegador.push(MaterialPageRoute<void>(
        builder: (_) => PublicarFotosScreen(
          pet: pet,
          itens: [
            for (var i = 0; i < quantas; i++)
              ItemDeEnvio(bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, i])),
          ],
        ),
      ));
      await _assentar(tester);
    }

    testWidgets('prévia com legenda; publicar coloca as fotos na grade',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet('Rex'));
      final galeria = FakeGaleriaRepository();
      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id/fotos');

      await publicarDaGaleria(tester, id, pets, 2);
      expect(find.text('Publicar fotos'), findsOneWidget);
      expect(find.text('Legenda (opcional)'), findsNWidgets(2));
      await tester.enterText(
          find.byType(TextFormField).first, 'Primeiro banho');
      await tester.tap(find.text('Publicar 2 fotos'));
      await _assentar(tester);

      expect(galeria.fotosDe(id), hasLength(2));
      expect(galeria.fotosDe(id).map((f) => f.legenda),
          contains('Primeiro banho'));
      expect(
          find.text('2 fotos publicadas na galeria de Rex.'), findsOneWidget);
      expect(find.text('Fotos de Rex'), findsOneWidget);
      expect(find.byType(FotoMiniatura), findsNWidgets(2));
    });

    testWidgets('sucesso parcial: mostra o que falhou e tenta só ela de novo',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet('Rex'));
      final galeria = FakeGaleriaRepository()..falharPublicacaoEm = {1};
      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id/fotos');

      await publicarDaGaleria(tester, id, pets, 2);
      await tester.tap(find.text('Publicar 2 fotos'));
      await _assentar(tester);

      expect(find.text('Publicada'), findsOneWidget);
      expect(find.text('1 publicada, 1 não.'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(galeria.fotosDe(id), hasLength(1));

      await tester.tap(find.text('Tentar de novo'));
      await _assentar(tester);

      expect(galeria.fotosDe(id), hasLength(2));
      expect(find.text('Fotos de Rex'), findsOneWidget);
      expect(find.byType(FotoMiniatura), findsNWidgets(2));
    });
  });

  group('Memorial e perfil', () {
    testWidgets(
        'pet falecido: Memorial mostra as fotos e o botão de adicionar, sem '
        'recursos clínicos', (tester) async {
      final pets = FakePetRepository();
      final id = await _falecido(pets, _pet('Mel'));
      final galeria = FakeGaleriaRepository()..semear(id, 8);

      final cenario = await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/memorial/$id');

      expect(find.text('Fotos'), findsOneWidget);
      expect(find.byType(FotoMiniatura), findsNWidgets(6),
          reason: 'o Memorial mostra só as mais recentes');
      // A grade do resumo também é rolável; a rolagem é a da página.
      final pagina = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Adicionar fotos'), 200,
          scrollable: pagina);
      expect(find.text('Adicionar fotos'), findsOneWidget);
      expect(cenario.leiturasClinicas, isEmpty);

      await tester.scrollUntilVisible(find.text('Ver todas'), -200,
          scrollable: pagina);
      await tester.tap(find.text('Ver todas'));
      await _assentar(tester);
      expect(find.text('Fotos de Mel'), findsOneWidget);
      expect(find.byType(FotoMiniatura), findsNWidgets(8));
      expect(cenario.leiturasClinicas, isEmpty);
    });

    testWidgets('Memorial sem fotos: convite para a primeira', (tester) async {
      final pets = FakePetRepository();
      final id = await _falecido(pets, _pet('Mel'));

      await _abrir(tester, pets: pets, rota: '/memorial/$id');

      expect(find.text('Guarde aqui as lembranças de Mel.'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.text('Adicionar primeira foto'), 200);
      expect(find.text('Adicionar primeira foto'), findsOneWidget);
    });

    testWidgets('galeria desligada: nem perfil nem Memorial mostram Fotos',
        (tester) async {
      final pets = FakePetRepository();
      final ativo = await pets.createPet(_pet('Rex'));
      final falecido = await _falecido(pets, _pet('Mel'));

      final cenario = await _abrir(tester,
          pets: pets, rota: '/pet/$ativo', galeriaDisponivel: false);
      expect(find.text('Fotos', skipOffstage: false), findsNothing);

      cenario.router.go('/memorial/$falecido');
      await _assentar(tester);
      expect(find.text('Fotos', skipOffstage: false), findsNothing);
      expect(find.text('Lembranças', skipOffstage: false), findsOneWidget);

      // Nem por link direto.
      cenario.router.go('/pet/$ativo/fotos');
      await _assentar(tester);
      expect(find.text('A galeria de fotos ainda não está disponível.'),
          findsOneWidget);
      expect(cenario.galeria.listagens, isEmpty);
    });

    testWidgets('perfil do pet ativo: "Fotos" abre a galeria', (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet('Rex'));

      await _abrir(tester, pets: pets, rota: '/pet/$id');
      await tester.scrollUntilVisible(find.text('Fotos'), 200);
      // Os recursos do pet ativo continuam.
      expect(find.text('Localização'), findsOneWidget);
      expect(find.text('Carteira de Vacinas', skipOffstage: false),
          findsOneWidget);
      await tester.tap(find.text('Fotos'));
      await _assentar(tester);

      expect(find.text('Fotos de Rex'), findsOneWidget);
    });

    testWidgets('pet de outro tutor: "Pet não encontrado", sem listar fotos',
        (tester) async {
      final pets = FakePetRepository();
      final alheio = await pets.createPet(_pet('Thor', userId: 'uid-outro'));
      final galeria = FakeGaleriaRepository()..semear(alheio, 3);

      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$alheio/fotos');

      expect(find.text('Pet não encontrado.'), findsOneWidget);
      expect(find.byType(FotoMiniatura), findsNothing);
      expect(galeria.listagens, isEmpty);
    });
  });

  group('Temas e fonte ampliada', () {
    for (final tema in AppThemeMode.values) {
      testWidgets('${tema.name}: grade e vazio sem estouro em 320 dp, fonte 2x',
          (tester) async {
        final pets = FakePetRepository();
        final comFotos = await pets.createPet(_pet('Rex'));
        final semFotos = await pets.createPet(_pet('Mel'));
        final galeria = FakeGaleriaRepository()..semear(comFotos, 5);

        final cenario = await _abrir(tester,
            pets: pets,
            galeria: galeria,
            rota: '/pet/$comFotos/fotos',
            tema: tema,
            tamanho: const Size(320, 640),
            escala: 2.0);
        expect(tester.takeException(), isNull);
        expect(find.byType(FotoMiniatura), findsWidgets);

        cenario.router.go('/pet/$semFotos/fotos');
        await _assentar(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Adicionar primeira foto'), findsOneWidget);
      });
    }
  });
}
