// Cartão de Emergência (issue #41): telas de leitura e edição, entrada no
// perfil do pet e estados especiais (vazio, offline, sem permissão,
// Memorial, conflito, fonte grande, temas). Dados fictícios.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';
import 'package:pet_connect/features/pet/domain/cartao_emergencia.dart';
import 'package:pet_connect/features/pet/domain/cartao_emergencia_repository.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/presentation/providers/abrir_link_provider.dart';
import 'package:pet_connect/features/pet/presentation/providers/cartao_emergencia_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/consulta_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/vacina_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/cartao_emergencia_form_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/cartao_emergencia_screen.dart';
import 'package:pet_connect/features/pet/presentation/widgets/pet_feature_grid.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

const _tutor = Usuario(
  id: 'uid-1',
  usuarioID: 'uid-1',
  nome: 'Ana',
  email: 'ana@exemplo.com',
  telefone: '19900000000',
  dataNascimento: '',
  genero: '',
);

const _rex = Pet(
  id: 'pet-1',
  userId: 'uid-1',
  nome: 'Rex',
  especie: 'Cachorro',
  raca: 'SRD',
  cor: 'Caramelo',
  genero: '',
  porte: '',
  peso: '',
  dataNascimento: '',
  vacinado: false,
);

const _mel = Pet(
  id: 'pet-2',
  userId: 'uid-1',
  nome: 'Mel',
  especie: 'Gato',
  raca: '',
  cor: '',
  genero: '',
  porte: '',
  peso: '',
  dataNascimento: '',
  vacinado: false,
  situacao: SituacaoPet.falecido,
);

final _completo = CartaoEmergencia(
  situacaoAlergias: SituacaoDaLista.informada,
  alergias: const [
    Alergia(id: 'a1', substancia: 'Dipirona', reacao: 'Vômito'),
  ],
  situacaoMedicamentos: SituacaoDaLista.nenhumaDeclarada,
  tipoSanguineo: 'DEA 1.1 positivo',
  tipoSanguineoConfirmado: true,
  observacoes: 'Morde quando sente dor.',
  veterinario: const VeterinarioDeConfianca(
    nome: 'Dra. Exemplo',
    clinica: 'Clínica Exemplo',
    telefone: '+5519900000001',
  ),
  atualizadoEm: DateTime(2026, 11, 9, 10, 30),
  revisao: 2,
);

LeituraDoCartao _leitura(CartaoEmergencia c,
        {bool cache = false, bool? existe}) =>
    LeituraDoCartao(
        cartao: c, doCacheLocal: cache, existe: existe ?? !c.nuncaSalvo);

class _Repo implements CartaoEmergenciaRepository {
  _Repo(Map<String, LeituraDoCartao> inicial) : _atual = {...inicial};

  final Map<String, LeituraDoCartao> _atual;
  final _mudancas = StreamController<String>.broadcast();
  final salvos = <({String petId, CartaoEmergencia cartao, int revisao})>[];
  Object? erroDeLeitura;
  FalhaDoCartao? falhaAoSalvar;
  Completer<void>? segurar;

  @override
  Stream<LeituraDoCartao> observar(String petId) => Stream.multi((c) {
        if (erroDeLeitura != null) {
          c.addError(erroDeLeitura!);
          return;
        }
        c.add(_atual[petId] ?? _leitura(CartaoEmergencia.vazio));
        final sub = _mudancas.stream
            .where((id) => id == petId)
            .listen((_) => c.add(_atual[petId]!));
        c.onCancel = sub.cancel;
      });

  @override
  Future<void> salvar(String petId, CartaoEmergencia cartao,
      {required int revisaoEsperada}) async {
    salvos.add((petId: petId, cartao: cartao, revisao: revisaoEsperada));
    if (segurar != null) await segurar!.future;
    if (falhaAoSalvar != null) throw falhaAoSalvar!;
    _atual[petId] = _leitura(CartaoEmergencia.fromMap(
      {...cartao.toMap(), 'revisao': revisaoEsperada + 1},
      atualizadoEm: DateTime(2026, 11, 9, 11),
    ));
    _mudancas.add(petId);
  }
}

class _App {
  _App(this.repo, {this.links});

  final _Repo repo;
  final List<Pet> pets = const [_rex, _mel];
  final List<Uri>? links;

  late final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('início')),
      ),
      GoRoute(
        path: '/pet/:id/emergencia',
        builder: (context, state) =>
            CartaoEmergenciaScreen(petId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pet/:id/emergencia/editar',
        builder: (context, state) => CartaoEmergenciaFormScreen(
          petId: state.pathParameters['id']!,
          inicial: state.extra as CartaoEmergencia?,
        ),
      ),
    ],
  );

  Widget widget({
    ThemeData? tema,
    double escala = 1,
    bool disponivel = true,
  }) =>
      ProviderScope(
        overrides: [
          currentUsuarioProvider.overrideWith((ref) => Stream.value(_tutor)),
          petProvider.overrideWith((ref, id) =>
              Stream.value(pets.where((p) => p.id == id).firstOrNull)),
          cartaoEmergenciaDisponivelProvider.overrideWithValue(disponivel),
          cartaoEmergenciaRepositoryProvider.overrideWithValue(repo),
          abrirLinkProvider.overrideWithValue((uri) async {
            links?.add(uri);
            return true;
          }),
        ],
        child: MaterialApp.router(
          theme: tema ?? AppTheme.light(),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
        ),
      );
}

Future<_App> _abrir(
  WidgetTester tester,
  _Repo repo, {
  String petId = 'pet-1',
  List<Uri>? links,
  ThemeData? tema,
  double escala = 1,
  Size tela = const Size(1080, 12000),
}) async {
  tester.view.physicalSize = tela;
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final app = _App(repo, links: links);
  await tester.pumpWidget(app.widget(tema: tema, escala: escala));
  app.router.push('/pet/$petId/emergencia');
  await tester.pumpAndSettle();
  return app;
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  // Listas longas só constroem o que está perto da tela.
  if (alvo.evaluate().isEmpty) {
    await tester.scrollUntilVisible(alvo, 300,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

Future<void> _salvar(WidgetTester tester) =>
    _tocar(tester, find.widgetWithText(ElevatedButton, 'SALVAR'));

Finder _campo(String rotulo) => find.widgetWithText(TextFormField, rotulo);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('leitura', () {
    testWidgets('cartão vazio: convite para preencher e aviso de privacidade',
        (tester) async {
      await _abrir(tester, _Repo({}));

      expect(find.text('Preencher cartão'), findsOneWidget);
      expect(find.textContaining('Nada disso aparece na página do QR Code'),
          findsOneWidget);
      expect(find.text('Rex'), findsOneWidget);
    });

    testWidgets(
        'cartão completo: "Não informado" separado de "nenhum declarado"',
        (tester) async {
      await _abrir(tester, _Repo({'pet-1': _leitura(_completo)}));

      expect(find.text('Dipirona'), findsOneWidget);
      expect(find.text('Reação: Vômito'), findsOneWidget);
      expect(find.text('Nenhum em uso (declarado pelo tutor)'), findsOneWidget);
      // Condições: nada informado.
      expect(find.text('Não informado'), findsOneWidget);
      expect(find.text('DEA 1.1 positivo'), findsOneWidget);
      expect(find.text('Dra. Exemplo'), findsOneWidget);
      expect(find.text('(19) 90000-0001'), findsOneWidget);
      expect(find.text('(19) 90000-0000'), findsOneWidget,
          reason: 'telefone do perfil do tutor');
      expect(find.text('Atualizado em 09/11/2026 às 10:30'), findsOneWidget);
      expect(
          find.text(
              'Informações fornecidas pelo tutor; confirme com o veterinário.'),
          findsOneWidget);
    });

    testWidgets('ligar abre o discador com o número; não liga sozinho',
        (tester) async {
      final links = <Uri>[];
      await _abrir(tester, _Repo({'pet-1': _leitura(_completo)}), links: links);
      expect(links, isEmpty);

      await _tocar(tester, find.text('Ligar para o veterinário'));

      expect(links, [Uri(scheme: 'tel', path: '+5519900000001')]);
    });

    testWidgets('contato do tutor oculto quando ele escolheu não mostrar',
        (tester) async {
      final oculto = CartaoEmergencia.fromMap(
          {..._completo.toMap(), 'mostrarContatoDoTutor': false, 'revisao': 2});
      await _abrir(tester, _Repo({'pet-1': _leitura(oculto)}));

      expect(find.text('Contato do tutor'), findsNothing);
      expect(find.text('(19) 90000-0000'), findsNothing);
    });

    testWidgets('offline com cartão no aparelho: mostra e avisa',
        (tester) async {
      await _abrir(tester, _Repo({'pet-1': _leitura(_completo, cache: true)}));

      expect(find.textContaining('mostrando a última versão salva'),
          findsOneWidget);
      expect(find.text('Dipirona'), findsOneWidget);
    });

    testWidgets('offline sem cartão no aparelho: não convida a preencher',
        (tester) async {
      await _abrir(
          tester,
          _Repo({
            'pet-1':
                _leitura(CartaoEmergencia.vazio, cache: true, existe: false)
          }));

      expect(find.textContaining('ainda não foi baixado'), findsOneWidget);
      expect(find.text('Preencher cartão'), findsNothing);
      expect(find.byTooltip('Editar cartão'), findsNothing);
    });

    testWidgets('sem permissão: não mostra dado nenhum', (tester) async {
      await _abrir(
          tester,
          _Repo({'pet-1': _leitura(_completo)})
            ..erroDeLeitura = const CartaoSemPermissao());

      expect(find.text('Você não tem acesso a este cartão.'), findsOneWidget);
      expect(find.text('Dipirona'), findsNothing);
      expect(find.byTooltip('Editar cartão'), findsNothing);
    });

    testWidgets('Memorial: só leitura, sem editar nem preencher',
        (tester) async {
      await _abrir(tester, _Repo({'pet-2': _leitura(_completo)}),
          petId: 'pet-2');
      expect(find.text('No Memorial: somente leitura'), findsOneWidget);
      expect(find.byTooltip('Editar cartão'), findsNothing);
      expect(find.text('Dipirona'), findsOneWidget);
    });

    testWidgets('Memorial sem cartão: nada para preencher', (tester) async {
      await _abrir(tester, _Repo({}), petId: 'pet-2');
      expect(find.text('Preencher cartão'), findsNothing);
      expect(find.textContaining('não foi preenchido'), findsOneWidget);
    });

    testWidgets('cada pet vê só o próprio cartão', (tester) async {
      final app = await _abrir(tester, _Repo({'pet-1': _leitura(_completo)}),
          petId: 'pet-2');
      expect(find.text('Dipirona'), findsNothing);

      app.router.go('/');
      await tester.pumpAndSettle();
      app.router.push('/pet/pet-1/emergencia');
      await tester.pumpAndSettle();
      expect(find.text('Dipirona'), findsOneWidget);
    });

    testWidgets('desligado nesta versão: avisa e não lê o cartão',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      addTearDown(tester.view.reset);
      final repo = _Repo({'pet-1': _leitura(_completo)});
      final app = _App(repo);
      await tester.pumpWidget(app.widget(disponivel: false));
      app.router.push('/pet/pet-1/emergencia');
      await tester.pumpAndSettle();

      expect(find.textContaining('ainda não está disponível'), findsOneWidget);
      expect(find.text('Dipirona'), findsNothing);
    });
  });

  group('edição', () {
    testWidgets('salvar sem preencher nada é permitido e volta ao cartão',
        (tester) async {
      final repo = _Repo({});
      await _abrir(tester, repo);
      await _tocar(tester, find.text('Preencher cartão'));

      await _salvar(tester);

      expect(repo.salvos, hasLength(1));
      expect(repo.salvos.single.revisao, 0);
      expect(repo.salvos.single.cartao.semDados, isTrue);
      expect(find.text('Editar cartão'), findsNothing);
      expect(find.text('Cartão de Emergência'), findsOneWidget);
    });

    testWidgets('salvar e reabrir mostra o que foi digitado', (tester) async {
      final repo = _Repo({});
      await _abrir(tester, repo);
      await _tocar(tester, find.text('Preencher cartão'));

      await _tocar(tester, find.text('Informar alergias'));
      await _tocar(tester, find.text('Adicionar alergia'));
      await tester.enterText(_campo('Substância ou alimento'), ' Dipirona ');
      await tester.enterText(
          _campo('Observações (opcional)'), 'Usar focinheira');
      await _salvar(tester);

      final salvo = repo.salvos.single.cartao;
      expect(salvo.situacaoAlergias, SituacaoDaLista.informada);
      expect(salvo.alergias.single.substancia, 'Dipirona');
      expect(salvo.observacoes, 'Usar focinheira');
      expect(find.text('Dipirona'), findsOneWidget);
      expect(find.text('Usar focinheira'), findsOneWidget);
    });

    testWidgets('"Informar" sem item ou com item vazio não salva',
        (tester) async {
      final repo = _Repo({});
      await _abrir(tester, repo);
      await _tocar(tester, find.text('Preencher cartão'));

      await _tocar(tester, find.text('Informar alergias'));
      await _salvar(tester);
      expect(find.text('Adicione pelo menos um item ou escolha outra opção.'),
          findsOneWidget);

      await _tocar(tester, find.text('Adicionar alergia'));
      await _salvar(tester);
      expect(
          find.text('Informe a substância ou remova o item.'), findsOneWidget);
      expect(repo.salvos, isEmpty);
    });

    testWidgets('remover item pede confirmação', (tester) async {
      await _abrir(tester, _Repo({'pet-1': _leitura(_completo)}));
      await _tocar(tester, find.byTooltip('Editar cartão'));

      await _tocar(tester, find.byTooltip('Remover alergia 1'));
      expect(find.text('Remover esta alergia?'), findsOneWidget);
      await _tocar(tester, find.text('Cancelar'));
      expect(find.widgetWithText(TextFormField, 'Dipirona'), findsOneWidget);

      await _tocar(tester, find.byTooltip('Remover alergia 1'));
      await _tocar(tester, find.text('Remover'));
      expect(find.widgetWithText(TextFormField, 'Dipirona'), findsNothing);
    });

    testWidgets('tipo sanguíneo exige a confirmação de origem', (tester) async {
      final repo = _Repo({});
      await _abrir(tester, repo);
      await _tocar(tester, find.text('Preencher cartão'));

      await tester.enterText(_campo('Tipo sanguíneo (opcional)'), 'A');
      await _salvar(tester);
      expect(find.text('Marque a confirmação abaixo ou deixe em branco.'),
          findsOneWidget);
      expect(repo.salvos, isEmpty);

      await _tocar(tester, find.byType(CheckboxListTile));
      await _salvar(tester);
      expect(repo.salvos.single.cartao.tipoSanguineo, 'A');
      expect(repo.salvos.single.cartao.tipoSanguineoConfirmado, isTrue);
    });

    testWidgets('telefone do veterinário inválido não salva', (tester) async {
      final repo = _Repo({});
      await _abrir(tester, repo);
      await _tocar(tester, find.text('Preencher cartão'));

      await tester.enterText(_campo('Telefone (opcional)'), '123');
      await _salvar(tester);

      expect(find.textContaining('Telefone inválido'), findsOneWidget);
      expect(repo.salvos, isEmpty);
    });

    testWidgets('voltar com alterações pergunta antes de descartar',
        (tester) async {
      final repo = _Repo({'pet-1': _leitura(_completo)});
      final app = await _abrir(tester, repo);
      await _tocar(tester, find.byTooltip('Editar cartão'));
      await tester.enterText(_campo('Observações (opcional)'), 'Mudou');
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsOneWidget);
      await _tocar(tester, find.text('Continuar editando'));
      expect(find.text('Editar cartão'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await _tocar(tester, find.text('Descartar'));
      expect(app.router.state.uri.path, '/pet/pet-1/emergencia');
      expect(repo.salvos, isEmpty);
      expect(find.text('Morde quando sente dor.'), findsOneWidget);
    });

    testWidgets('voltar sem alterações não pergunta', (tester) async {
      await _abrir(tester, _Repo({'pet-1': _leitura(_completo)}));
      await _tocar(tester, find.byTooltip('Editar cartão'));

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Descartar alterações?'), findsNothing);
      expect(find.text('Cartão de Emergência'), findsOneWidget);
    });

    testWidgets('editado em outro lugar: avisa e não sobrescreve',
        (tester) async {
      final repo = _Repo({'pet-1': _leitura(_completo)})
        ..falhaAoSalvar = const CartaoAlteradoEmOutroLugar();
      await _abrir(tester, repo);
      await _tocar(tester, find.byTooltip('Editar cartão'));
      await tester.enterText(_campo('Observações (opcional)'), 'Mudou');

      await _salvar(tester);

      expect(find.text('O cartão mudou'), findsOneWidget);
      expect(repo.salvos.single.revisao, 2);
      await _tocar(tester, find.text('Continuar editando'));
      expect(find.textContaining('Nada foi salvo'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Mudou'), findsOneWidget);
    });

    testWidgets('sem conexão: avisa e mantém o formulário', (tester) async {
      final repo = _Repo({})..falhaAoSalvar = const CartaoSemConexao();
      await _abrir(tester, repo);
      await _tocar(tester, find.text('Preencher cartão'));
      await tester.enterText(_campo('Observações (opcional)'), 'Não perder');

      await _salvar(tester);

      expect(
          find.textContaining('Sem conexão. Nada foi salvo'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Não perder'), findsOneWidget);
      expect(find.text('Editar cartão'), findsOneWidget);
    });

    testWidgets('toque duplo em salvar grava uma vez só', (tester) async {
      final repo = _Repo({})..segurar = Completer<void>();
      await _abrir(tester, repo);
      await _tocar(tester, find.text('Preencher cartão'));

      final salvar = find.widgetWithText(ElevatedButton, 'SALVAR');
      await tester.ensureVisible(salvar);
      await tester.tap(salvar);
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();

      expect(repo.salvos, hasLength(1));
      repo.segurar!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('acessibilidade e temas', () {
    for (final modo in AppThemeMode.values) {
      testWidgets('cartão completo e formulário no tema ${modo.name}',
          (tester) async {
        await _abrir(tester, _Repo({'pet-1': _leitura(_completo)}),
            tema: AppTheme.build(modo));
        expect(tester.takeException(), isNull);
        await _tocar(tester, find.byTooltip('Editar cartão'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('fonte em 200% em tela pequena: sem estouro', (tester) async {
      await _abrir(tester, _Repo({'pet-1': _leitura(_completo)}),
          escala: 2, tela: const Size(720, 1280));
      expect(tester.takeException(), isNull);
      await _tocar(tester, find.byTooltip('Editar cartão'));
      expect(tester.takeException(), isNull);
      await _tocar(tester, find.text('Informar medicamentos'));
      await _tocar(tester, find.text('Adicionar medicamento'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('seções são cabeçalhos para o leitor de tela', (tester) async {
      final semantica = tester.ensureSemantics();
      await _abrir(tester, _Repo({'pet-1': _leitura(_completo)}));

      expect(
        tester.getSemantics(find.text('Alergias conhecidas')),
        isSemantics(label: 'Alergias conhecidas', isHeader: true),
      );
      semantica.dispose();
    });
  });

  group('perfil do pet', () {
    Widget grade({required bool disponivel}) => ProviderScope(
          overrides: [
            cartaoEmergenciaDisponivelProvider.overrideWithValue(disponivel),
            vacinasProvider.overrideWith((ref, id) => Stream.value(const [])),
            consultasProvider.overrideWith((ref, id) => Stream.value(const [])),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: PetFeatureGrid(pet: _rex)),
            ),
          ),
        );

    testWidgets('card "Cartão de Emergência" abaixo dos quatro cards',
        (tester) async {
      await tester.pumpWidget(grade(disponivel: true));
      await tester.pumpAndSettle();

      expect(find.text('Cartão de Emergência'), findsOneWidget);
      for (final titulo in [
        'Carteira de Vacinas',
        'Agenda de Consultas',
        'Histórico Médico',
        'QR Code do Pet',
      ]) {
        expect(find.text(titulo), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(titulo)).dy,
          lessThan(tester.getTopLeft(find.text('Cartão de Emergência')).dy),
        );
      }
    });

    testWidgets('sem o flag, o card não aparece', (tester) async {
      await tester.pumpWidget(grade(disponivel: false));
      await tester.pumpAndSettle();

      expect(find.text('Cartão de Emergência'), findsNothing);
      expect(find.text('QR Code do Pet'), findsOneWidget);
    });
  });
}
