// Cartaz de pet desaparecido — telas, rotas, consentimento, exportação e
// rascunho (docs/features/cartaz-pet-desaparecido.md). Usa as rotas reais de
// pet (buildPetRoutes), com os guards. Dados e telefones fictícios.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';
import 'package:pet_connect/core/theme/theme_providers.dart';
import 'package:pet_connect/features/pet/data/exportacao_cartaz.dart';
import 'package:pet_connect/features/pet/domain/alteracao_situacao.dart';
import 'package:pet_connect/features/pet/domain/cartaz_desaparecido.dart';
import 'package:pet_connect/features/pet/domain/consulta.dart';
import 'package:pet_connect/features/pet/domain/historico_medico.dart';
import 'package:pet_connect/features/pet/domain/localizacao.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/domain/vacina.dart';
import 'package:pet_connect/features/pet/presentation/providers/cartaz_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/consulta_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/galeria_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/historico_medico_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/localizacao_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/vacina_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/cartaz_editor_screen.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';
import 'package:pet_connect/routing/pet_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_galeria_repository.dart';
import 'fake_pet_repository.dart';

Usuario _tutor({String telefone = '(11) 90000-0000'}) => Usuario(
      id: 'uid-1',
      usuarioID: 'uid-1',
      nome: 'Ana',
      email: 'ana@teste.com',
      telefone: telefone,
      dataNascimento: '',
      genero: '',
    );

Pet _pet({String userId = 'uid-1', String? telefone}) => Pet(
      id: '',
      userId: userId,
      nome: 'Rex',
      especie: 'Cachorro',
      raca: 'SRD',
      cor: 'Caramelo',
      genero: 'Macho',
      porte: 'Médio',
      peso: '',
      dataNascimento: '',
      vacinado: true,
      telefone: telefone,
    );

class _FakeDestino implements DestinoDoCartaz {
  final compartilhados = <({Uint8List bytes, String nome, String mime})>[];
  final salvos = <({Uint8List png, String nome})>[];
  bool fecharFolha = false;
  MotivoFalhaAoSalvar? falhaAoSalvar;

  @override
  Future<bool> compartilhar({
    required Uint8List bytes,
    required String nomeDoArquivo,
    required String mimeType,
  }) async {
    compartilhados.add((bytes: bytes, nome: nomeDoArquivo, mime: mimeType));
    return !fecharFolha;
  }

  @override
  Future<void> salvarNaGaleria({
    required Uint8List png,
    required String nome,
  }) async {
    if (falhaAoSalvar != null) throw FalhaAoSalvarCartaz(falhaAoSalvar!);
    salvos.add((png: png, nome: nome));
  }
}

class _Cenario {
  _Cenario(this.pets, this.destino, this.router, this.leiturasClinicas);

  final FakePetRepository pets;
  final _FakeDestino destino;
  final GoRouter router;
  final List<String> leiturasClinicas;
}

late Uint8List _png;

/// Tela alta o bastante para o editor inteiro ser construído.
const _alta = Size(412, 2600);

Future<Uint8List> _imagem(Color cor) async {
  final gravador = ui.PictureRecorder();
  Canvas(gravador)
      .drawRect(const Rect.fromLTWH(0, 0, 60, 40), Paint()..color = cor);
  final imagem = await gravador.endRecording().toImage(60, 40);
  final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
  imagem.dispose();
  return dados!.buffer.asUint8List();
}

Future<_Cenario> _abrir(
  WidgetTester tester, {
  required FakePetRepository pets,
  required String rota,
  FakeGaleriaRepository? galeria,
  Usuario? tutor,
  Map<String, Object> preferencias = const {},
  AppThemeMode tema = AppThemeMode.padrao,
  Size tamanho = const Size(412, 915),
  double escala = 1.0,
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  SharedPreferences.setMockInitialValues(preferencias);
  final prefs = await SharedPreferences.getInstance();
  final destino = _FakeDestino();
  final leituras = <String>[];
  final router = GoRouter(initialLocation: rota, routes: buildPetRoutes());

  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUsuarioProvider
          .overrideWith((ref) => Stream.value(tutor ?? _tutor())),
      petRepositoryProvider.overrideWithValue(pets),
      galeriaRepositoryProvider
          .overrideWithValue(galeria ?? FakeGaleriaRepository()),
      galeriaDisponivelProvider.overrideWithValue(true),
      sharedPreferencesProvider.overrideWithValue(prefs),
      destinoDoCartazProvider.overrideWithValue(destino),
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
  return _Cenario(pets, destino, router, leituras);
}

/// Imagens de rede nunca terminam de carregar em teste, então
/// pumpAndSettle não estabiliza; avança o tempo das transições.
Future<void> _assentar(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// A exportação decodifica as fotos e captura o PNG de verdade (tempo
/// real), intercalado com quadros.
Future<void> _esperarExportacao(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

CartazController _controller(WidgetTester tester, String petId) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first))
        .read(cartazControllerProvider(petId).notifier);

RascunhoCartaz _rascunho(WidgetTester tester, String petId) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first))
        .read(cartazControllerProvider(petId));

/// Três fotos do celular nas posições, autorizando ou não o telefone.
void _preencher(WidgetTester tester, String petId, {String? autorizado}) {
  _controller(tester, petId).atualizar((r) => RascunhoCartaz(
        espacos: [
          for (var i = 0; i < 3; i++) EspacoDeFoto(foto: FotoDoAparelho(_png)),
        ],
        caracteristicas: r.caracteristicas,
        telefoneAutorizado: autorizado,
      ));
}

Future<void> _abrirPrevia(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Ver cartaz'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Ver cartaz'));
  await _assentar(tester);
}

ButtonStyleButton _botao(WidgetTester tester, String rotulo) =>
    tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text(rotulo), matching: find.bySubtype<ButtonStyleButton>()));

void main() {
  setUpAll(() async {
    _png = await _imagem(const Color(0xFF8D6E63));
  });

  group('Entrada e acesso', () {
    testWidgets('perfil do pet ativo tem "Pet desaparecido" e abre o editor',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      final c = await _abrir(tester, pets: pets, rota: '/pet/$id');

      await tester.scrollUntilVisible(find.text('Pet desaparecido'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Pet desaparecido'));
      await _assentar(tester);

      expect(find.byType(CartazEditorScreen), findsOneWidget);
      expect(c.router.routerDelegate.currentConfiguration.last.matchedLocation,
          '/pet/$id/cartaz');
      expect(find.text('Rex'), findsOneWidget);
      expect(find.text('Cachorro · SRD'), findsOneWidget);

      // Voltar retorna ao perfil, sem fechar o app.
      await tester.pageBack();
      await _assentar(tester);
      expect(c.router.routerDelegate.currentConfiguration.uri.path, '/pet/$id');
    });

    testWidgets('pet no Memorial não abre o cartaz, nem por link direto',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      await pets.alterarSituacao(id, AlteracaoDeSituacao.registrarFalecimento(),
          atorId: 'uid-1');

      await _abrir(tester, pets: pets, rota: '/pet/$id/cartaz');

      expect(find.byType(CartazEditorScreen), findsNothing);
      expect(find.textContaining('está no Memorial'), findsOneWidget);
    });

    testWidgets('pet de outro tutor: "Pet não encontrado"', (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet(userId: 'outro'));

      await _abrir(tester, pets: pets, rota: '/pet/$id/cartaz/previa');

      expect(find.text('Pet não encontrado.'), findsOneWidget);
      expect(find.text('Prévia do cartaz'), findsNothing);
    });
  });

  group('Fotos', () {
    testWidgets('escolhe da galeria do pet; foto já usada fica bloqueada',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      final galeria = FakeGaleriaRepository()..semear(id, 4);
      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id/cartaz');

      await tester.tap(find.byKey(const ValueKey('cartaz-espaco-0')));
      await _assentar(tester);
      expect(find.text('Escolher do celular'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Foto 1 de Rex'));
      await _assentar(tester);

      final escolhida = _rascunho(tester, id).espacos[0].foto;
      expect(escolhida, isA<FotoDaGaleria>());
      expect(
          (escolhida! as FotoDaGaleria).fotoId, galeria.fotosDe(id).first.id);

      await tester.tap(find.byKey(const ValueKey('cartaz-espaco-1')));
      await _assentar(tester);
      expect(find.bySemanticsLabel('Foto 1 de Rex. Já está no cartaz.'),
          findsOneWidget);
      await tester
          .tap(find.bySemanticsLabel('Foto 1 de Rex. Já está no cartaz.'));
      await _assentar(tester);
      expect(_rascunho(tester, id).espacos[1].foto, isNull);
    });

    testWidgets('mover para outra posição e remover', (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      final galeria = FakeGaleriaRepository()..semear(id, 1);
      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id/cartaz');
      await tester.tap(find.byKey(const ValueKey('cartaz-espaco-0')));
      await _assentar(tester);
      await tester.tap(find.bySemanticsLabel('Foto 1 de Rex'));
      await _assentar(tester);

      await tester.tap(find.byKey(const ValueKey('cartaz-espaco-0')));
      await _assentar(tester);
      await tester.tap(find.text('Mover para Foto 3'));
      await _assentar(tester);
      expect(_rascunho(tester, id).espacos[0].foto, isNull);
      expect(_rascunho(tester, id).espacos[2].foto, isA<FotoDaGaleria>());

      await tester.tap(find.byKey(const ValueKey('cartaz-espaco-2')));
      await _assentar(tester);
      await tester.tap(find.text('Remover do cartaz'));
      await _assentar(tester);
      expect(_rascunho(tester, id).fotosEscolhidas, 0);
    });

    testWidgets('galeria fora do ar: aviso e "Tentar de novo"', (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      final galeria = FakeGaleriaRepository()
        ..semear(id, 2)
        ..falharListagem = true;
      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id/cartaz');

      await tester.tap(find.byKey(const ValueKey('cartaz-espaco-0')));
      await _assentar(tester);
      expect(find.text('Não foi possível carregar as fotos.'), findsOneWidget);

      galeria.falharListagem = false;
      await tester.tap(find.text('Tentar de novo'));
      await _assentar(tester);
      expect(find.bySemanticsLabel('Foto 1 de Rex'), findsOneWidget);
    });
  });

  group('Contato e consentimento', () {
    testWidgets(
        'sem telefone válido: aviso, caminho para corrigir e prévia '
        'bloqueada', (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      await _abrir(tester,
          pets: pets,
          tutor: _tutor(telefone: '1234'),
          rota: '/pet/$id/cartaz',
          tamanho: _alta);
      _preencher(tester, id);
      await tester.pump();

      expect(find.byKey(const ValueKey('cartaz-sem-telefone')), findsOneWidget);
      expect(find.text('Cadastrar telefone em Editar perfil'), findsOneWidget);

      await _abrirPrevia(tester);
      expect(
          find.textContaining('Cadastre um telefone válido'), findsOneWidget);
      expect(_botao(tester, 'Compartilhar imagem').onPressed, isNull);
      expect(_botao(tester, 'Salvar imagem').onPressed, isNull);
      expect(_botao(tester, 'Gerar PDF').onPressed, isNull);
    });

    testWidgets('o telefone só entra no cartaz depois de autorizado',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      await _abrir(tester, pets: pets, rota: '/pet/$id/cartaz');
      _preencher(tester, id);
      await tester.pump();

      await _abrirPrevia(tester);
      expect(find.textContaining('Confirme que o telefone'), findsOneWidget);
      expect(find.byKey(const ValueKey('cartaz-telefone')), findsOneWidget);
      expect(find.text('(11) 90000-0000'), findsNothing);
      expect(_botao(tester, 'Compartilhar imagem').onPressed, isNull);

      await tester.pageBack();
      await _assentar(tester);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('cartaz-consentimento')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('cartaz-consentimento')));
      await tester.pump();
      expect(_rascunho(tester, id).telefoneAutorizado, '11900000000');

      await _abrirPrevia(tester);
      expect(find.text('(11) 90000-0000'), findsOneWidget);
      expect(_botao(tester, 'Compartilhar imagem').onPressed, isNotNull);
    });

    testWidgets('trocar o número escolhido pede nova autorização',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet(telefone: '(21) 3456-0000'));
      await _abrir(tester, pets: pets, rota: '/pet/$id/cartaz');
      _preencher(tester, id, autorizado: '11900000000');
      await tester.pump();

      await tester.scrollUntilVisible(find.text('(21) 3456-0000'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('(21) 3456-0000'));
      await tester.pump();

      final caixa = tester.widget<CheckboxListTile>(
          find.byKey(const ValueKey('cartaz-consentimento')));
      expect(caixa.value, isFalse);
    });
  });

  group('Exportação', () {
    Future<_Cenario> pronto(WidgetTester tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      final c = await _abrir(tester, pets: pets, rota: '/pet/$id/cartaz');
      _preencher(tester, id, autorizado: '11900000000');
      await tester.pump();
      await _abrirPrevia(tester);
      return c;
    }

    testWidgets('compartilhar imagem: PNG pela folha do sistema, só no toque',
        (tester) async {
      final c = await pronto(tester);
      expect(c.destino.compartilhados, isEmpty);

      await tester.tap(find.text('Compartilhar imagem'));
      await _esperarExportacao(tester);

      final enviado = c.destino.compartilhados.single;
      expect(enviado.mime, 'image/png');
      expect(enviado.nome,
          matches(RegExp(r'^petconnect_procura-se_[0-9a-f]{8}_\d{8}\.png$')));
      expect(enviado.bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(find.byType(SnackBar), findsNothing,
          reason: 'compartilhar não anuncia sucesso que não pode confirmar');
    });

    testWidgets('gerar PDF: arquivo PDF pela folha do sistema', (tester) async {
      final c = await pronto(tester);

      await tester.tap(find.text('Gerar PDF'));
      await _esperarExportacao(tester);

      final enviado = c.destino.compartilhados.single;
      expect(enviado.mime, 'application/pdf');
      expect(enviado.nome, endsWith('.pdf'));
      expect(String.fromCharCodes(enviado.bytes.sublist(0, 4)), '%PDF');
    });

    testWidgets('salvar imagem: aviso só depois de salvar', (tester) async {
      final c = await pronto(tester);

      await tester.tap(find.text('Salvar imagem'));
      await _esperarExportacao(tester);

      expect(c.destino.salvos.single.nome,
          matches(RegExp(r'^petconnect_procura-se_[0-9a-f]{8}_\d{8}$')));
      expect(find.text('Cartaz salvo na galeria de fotos.'), findsOneWidget);
    });

    testWidgets('salvar sem acesso à galeria: orienta a compartilhar',
        (tester) async {
      final c = await pronto(tester);
      c.destino.falhaAoSalvar = MotivoFalhaAoSalvar.semPermissao;

      await tester.tap(find.text('Salvar imagem'));
      await _esperarExportacao(tester);

      expect(c.destino.salvos, isEmpty);
      expect(find.textContaining('Use "Compartilhar imagem"'), findsOneWidget);
      expect(find.text('Cartaz salvo na galeria de fotos.'), findsNothing);
    });

    testWidgets('foto que não carrega bloqueia a exportação', (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      final c = await _abrir(tester, pets: pets, rota: '/pet/$id/cartaz');
      _controller(tester, id).atualizar((_) => RascunhoCartaz(
            espacos: [
              EspacoDeFoto(foto: FotoDoAparelho(_png)),
              EspacoDeFoto(foto: FotoDoAparelho(_png)),
              // Bytes que não são imagem.
              EspacoDeFoto(foto: FotoDoAparelho(Uint8List.fromList([1, 2]))),
            ],
            telefoneAutorizado: '11900000000',
          ));
      await tester.pump();
      await _abrirPrevia(tester);

      await tester.tap(find.text('Compartilhar imagem'));
      await _esperarExportacao(tester);

      expect(c.destino.compartilhados, isEmpty);
      expect(find.textContaining('Uma das fotos não carregou'), findsOneWidget);
    });

    testWidgets('exportar não muda nada no pet nem lê dados clínicos',
        (tester) async {
      final c = await pronto(tester);
      final id = c.pets.eventosSituacao.isEmpty
          ? (await c.pets.watchPets('uid-1').first).single.id
          : fail('não deveria haver eventos');
      final antes = (await c.pets.watchPet(id).first)!.toMap();

      await tester.tap(find.text('Compartilhar imagem'));
      await _esperarExportacao(tester);

      expect((await c.pets.watchPet(id).first)!.toMap(), antes);
      expect(c.pets.eventosSituacao, isEmpty);
      expect(c.leiturasClinicas, isEmpty);
    });
  });

  group('Rascunho', () {
    testWidgets('textos e fotos da galeria voltam; consentimento não',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      final galeria = FakeGaleriaRepository()..semear(id, 1);
      final c = await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id', tamanho: _alta);

      await tester.scrollUntilVisible(find.text('Pet desaparecido'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Pet desaparecido'));
      await _assentar(tester);
      await tester.tap(find.byKey(const ValueKey('cartaz-espaco-0')));
      await _assentar(tester);
      await tester.tap(find.bySemanticsLabel('Foto 1 de Rex'));
      await _assentar(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Recompensa (opcional)'), 'R\$ 100');
      _controller(tester, id)
          .atualizar((r) => r.autorizarTelefone('11900000000'));
      await tester.pump(CartazController.esperaAntesDeSalvar);

      await tester.pageBack();
      await _assentar(tester);
      c.router.push('/pet/$id/cartaz');
      await _assentar(tester);

      final rascunho = _rascunho(tester, id);
      expect(rascunho.recompensa, 'R\$ 100');
      expect(find.text('R\$ 100'), findsOneWidget);
      expect(rascunho.espacos[0].foto, isA<FotoDaGaleria>());
      expect(rascunho.telefoneAutorizado, isNull);
    });

    testWidgets('com foto do celular, sair pede confirmação', (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      final c = await _abrir(tester, pets: pets, rota: '/pet/$id');
      await tester.scrollUntilVisible(find.text('Pet desaparecido'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Pet desaparecido'));
      await _assentar(tester);
      _preencher(tester, id);
      await tester.pump();

      await tester.binding.handlePopRoute();
      await _assentar(tester);
      expect(find.text('Sair do cartaz?'), findsOneWidget);
      await tester.tap(find.text('Continuar editando'));
      await _assentar(tester);
      expect(find.byType(CartazEditorScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _assentar(tester);
      await tester.tap(find.text('Sair'));
      await _assentar(tester);
      expect(c.router.routerDelegate.currentConfiguration.uri.path, '/pet/$id');
    });

    testWidgets('descartar apaga o rascunho salvo', (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      await _abrir(tester,
          pets: pets,
          rota: '/pet/$id/cartaz',
          tamanho: _alta,
          preferencias: {
            'cartaz_rascunho_v1_uid-1_$id':
                '{"versao":1,"espacos":[],"recompensa":"R\$ 50"}',
          });
      expect(find.text('R\$ 50'), findsOneWidget);

      await tester.tap(find.byTooltip('Mais opções'));
      await _assentar(tester);
      await tester.tap(find.text('Descartar rascunho'));
      await _assentar(tester);
      await tester.tap(find.text('Descartar'));
      await _assentar(tester);

      expect(find.text('R\$ 50'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cartaz_rascunho_v1_uid-1_$id'), isNull);
    });
  });

  testWidgets('editor em tema escuro, tela estreita e fonte grande',
      (tester) async {
    final pets = FakePetRepository();
    final id = await pets.createPet(_pet());
    await _abrir(tester,
        pets: pets,
        rota: '/pet/$id/cartaz',
        tema: AppThemeMode.escuro,
        tamanho: const Size(320, 640),
        escala: 1.5);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Ver cartaz'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
}
