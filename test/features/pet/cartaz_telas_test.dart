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
import 'package:pet_connect/features/pet/presentation/widgets/cartaz_fotos.dart';
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

/// A exportação (e o ajuste de foto) decodifica as fotos de verdade (tempo
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

/// Escolhe uma foto da galeria para [espaco] e confirma o ajuste, que abre
/// logo depois da escolha.
Future<void> _escolherDaGaleria(WidgetTester tester, int espaco,
    {String foto = 'Foto 1 de Rex'}) async {
  await tester.tap(find.byKey(ValueKey('cartaz-espaco-$espaco')));
  await _assentar(tester);
  await tester.tap(find.bySemanticsLabel(foto));
  await _assentar(tester);
  expect(find.byType(EnquadramentoScreen), findsOneWidget);
  await tester.tap(find.text('Pronto'));
  await _assentar(tester);
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
      // O ajuste abre logo depois da escolha.
      expect(find.text('Ajustar Foto principal'), findsOneWidget);
      await tester.tap(find.text('Pronto'));
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
      await _escolherDaGaleria(tester, 0);

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

    testWidgets(
        'ajuste: tocar escolhe o ponto de foco; "Foto inteira" não '
        'corta', (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      await _abrir(tester, pets: pets, rota: '/pet/$id/cartaz', tamanho: _alta);
      _preencher(tester, id);
      await tester.pump();

      Future<void> abrirAjuste() async {
        await tester.tap(find.byKey(const ValueKey('cartaz-ajustar-1')));
        await _assentar(tester);
        await _esperarExportacao(tester);
        expect(find.text('Ajustar Foto 2'), findsOneWidget);
      }

      await abrirAjuste();
      // A prévia tem o formato do espaço no cartaz atual.
      expect(find.bySemanticsLabel('Foto como vai aparecer no cartaz'),
          findsOneWidget);
      final foto = find.byKey(const ValueKey('cartaz-escolha-do-foco'));
      await tester.tapAt(tester.getTopLeft(foto) + const Offset(2, 2));
      await tester.pump();
      await tester.tap(find.text('Pronto'));
      await _assentar(tester);

      var enquadramento = _rascunho(tester, id).espacos[1].enquadramento;
      expect(enquadramento.focoX, lessThan(0.05));
      expect(enquadramento.focoY, lessThan(0.05));
      expect(enquadramento.inteira, isFalse);

      await abrirAjuste();
      await tester.tap(find.text('Foto inteira'));
      await tester.pump();
      expect(
          find.byKey(const ValueKey('cartaz-escolha-do-foco')), findsNothing);
      expect(find.text('Zoom'), findsNothing);
      await tester.tap(find.text('Pronto'));
      await _assentar(tester);

      enquadramento = _rascunho(tester, id).espacos[1].enquadramento;
      expect(enquadramento.inteira, isTrue);
      expect(_rascunho(tester, id).espacos[0].enquadramento,
          EnquadramentoFoto.centralizado);
    });

    testWidgets('voltar do ajuste mantém a foto, sem mudar o enquadramento',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      final galeria = FakeGaleriaRepository()..semear(id, 1);
      await _abrir(tester,
          pets: pets, galeria: galeria, rota: '/pet/$id/cartaz');
      await tester.tap(find.byKey(const ValueKey('cartaz-espaco-2')));
      await _assentar(tester);
      await tester.tap(find.bySemanticsLabel('Foto 1 de Rex'));
      await _assentar(tester);

      await tester.pageBack();
      await _assentar(tester);
      expect(find.byType(CartazEditorScreen), findsOneWidget);
      final espaco = _rascunho(tester, id).espacos[2];
      expect(espaco.foto, isA<FotoDaGaleria>());
      expect(espaco.enquadramento, EnquadramentoFoto.centralizado);
    });
  });

  group('Visto por último e recompensa', () {
    testWidgets('data no calendário em português, período e local num campo',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      await _abrir(tester, pets: pets, rota: '/pet/$id/cartaz', tamanho: _alta);
      // "Desapareceu em" não existe mais: um campo só.
      expect(find.textContaining('Desapareceu em'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('cartaz-visto-data')));
      await _assentar(tester);
      expect(find.text('Cancelar'), findsOneWidget,
          reason: 'calendário em português');
      await tester.tap(find.text('OK'));
      await _assentar(tester);

      final hoje = DateUtils.dateOnly(DateTime.now());
      expect(_rascunho(tester, id).vistoPorUltimo.data, hoje);

      await tester.tap(find.text('Tarde'));
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'Onde'), 'Perto da praça');
      await tester.pump();
      expect(
          find.text('No cartaz: ${formatarDataDoCartaz(hoje)}, à tarde — '
              'Perto da praça'),
          findsOneWidget);

      // Horário exato no lugar do período.
      await tester.tap(find.byKey(const ValueKey('cartaz-visto-horario')));
      await _assentar(tester);
      expect(find.text('Cancelar'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await _assentar(tester);
      final visto = _rascunho(tester, id).vistoPorUltimo;
      expect(visto.periodo, isNull);
      expect(visto.horario, isNotNull);
      expect(visto.local, 'Perto da praça');

      await tester.tap(find.byTooltip('Tirar a data'));
      await tester.pump();
      expect(_rascunho(tester, id).vistoPorUltimo.data, isNull);
    });

    testWidgets('recompensa em dinheiro com máscara de reais, ou outra',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      await _abrir(tester, pets: pets, rota: '/pet/$id/cartaz', tamanho: _alta);

      final valor = find.byKey(const ValueKey('cartaz-recompensa-valor'));
      await tester.enterText(valor, '150050');
      await tester.pump();
      expect(find.text('1.500,50'), findsOneWidget);
      expect(find.text('R\$ '), findsOneWidget);
      expect(_rascunho(tester, id).recompensa.noCartaz, 'R\$ 1.500,50');

      await tester.enterText(valor, '');
      await tester.pump();
      expect(_rascunho(tester, id).recompensa.noCartaz, isEmpty);

      await tester.tap(find.text('Outra'));
      await tester.pump();
      await tester.enterText(
          find.byKey(const ValueKey('cartaz-recompensa-texto')),
          'Um vale-presente');
      await tester.pump();
      expect(_rascunho(tester, id).recompensa.noCartaz, 'Um vale-presente');
    });

    test('máscara de reais: números entram pela direita', () {
      final mascara = MascaraDeReais();
      var atual = TextEditingValue.empty;
      for (final (digito, esperado) in [
        ('2', '0,02'),
        ('0', '0,20'),
        ('0', '2,00'),
        ('0', '20,00'),
        ('0', '200,00'),
        ('5', '2.000,05'),
      ]) {
        atual = mascara.formatEditUpdate(
            atual, TextEditingValue(text: '${atual.text}$digito'));
        expect(atual.text, esperado);
        expect(atual.selection.baseOffset, esperado.length);
      }
      // Apagar o último número.
      atual = mascara.formatEditUpdate(
          atual,
          TextEditingValue(
              text: atual.text.substring(0, atual.text.length - 1)));
      expect(atual.text, '200,00');
      // Letras e zeros à esquerda não entram; o máximo é R$ 999.999,99.
      expect(
          mascara
              .formatEditUpdate(
                  TextEditingValue.empty, const TextEditingValue(text: 'a0012'))
              .text,
          '0,12');
      expect(
          mascara
              .formatEditUpdate(TextEditingValue.empty,
                  const TextEditingValue(text: '12345678901'))
              .text,
          '123.456,78');
      expect(MascaraDeReais.centavos('0,00'), isNull);
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

    testWidgets('cor do cartaz: preto, vermelho ou azul, escolhida na prévia',
        (tester) async {
      final pets = FakePetRepository();
      final id = await pets.createPet(_pet());
      await _abrir(tester, pets: pets, rota: '/pet/$id/cartaz');
      _preencher(tester, id, autorizado: '11900000000');
      await tester.pump();
      await _abrirPrevia(tester);

      Color cabecalho() => (tester
              .widget<DecoratedBox>(
                  find.byKey(const ValueKey('cartaz-cabecalho')))
              .decoration as BoxDecoration)
          .color!;
      expect(cabecalho(), const Color(0xFF111111));
      expect(find.text('Preto'), findsOneWidget);
      expect(find.text('Vermelho'), findsOneWidget);

      await tester.tap(find.text('Azul'));
      await tester.pump();
      expect(_rascunho(tester, id).cor, CorDoCartaz.azul);
      expect(cabecalho(), const Color(0xFF1565C0));
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
      await _escolherDaGaleria(tester, 0);
      await tester.enterText(
          find.byKey(const ValueKey('cartaz-recompensa-valor')), '10000');
      _controller(tester, id)
          .atualizar((r) => r.autorizarTelefone('11900000000'));
      await tester.pump(CartazController.esperaAntesDeSalvar);

      await tester.pageBack();
      await _assentar(tester);
      c.router.push('/pet/$id/cartaz');
      await _assentar(tester);

      final rascunho = _rascunho(tester, id);
      expect(rascunho.recompensa, const Recompensa(centavos: 10000));
      expect(find.text('100,00'), findsOneWidget);
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
      // Rascunho da versão 1: a recompensa em texto vira valor.
      expect(find.text('50,00'), findsOneWidget);

      await tester.tap(find.byTooltip('Mais opções'));
      await _assentar(tester);
      await tester.tap(find.text('Descartar rascunho'));
      await _assentar(tester);
      await tester.tap(find.text('Descartar'));
      await _assentar(tester);

      expect(find.text('50,00'), findsNothing);
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
