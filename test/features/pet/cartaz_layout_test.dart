// Cartaz de pet desaparecido — composição, limites de texto, captura em PNG
// e regressão visual (docs/features/cartaz-pet-desaparecido.md, "Testes").
//
// Goldens em goldens/cartaz_*.png. No flutter_test o texto usa a fonte de
// teste (blocos), então as imagens conferem a composição (posições,
// tamanhos, recortes), não a tipografia. Tolerância de 2% dos pixels, para
// diferenças de suavização entre Windows e o Linux do CI. Para regerar:
// flutter test --update-goldens test/features/pet/cartaz_layout_test.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/domain/cartaz_desaparecido.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/presentation/widgets/cartaz_procura_se.dart';

class _ComparadorTolerante extends LocalFileComparator {
  _ComparadorTolerante(super.testFile);

  /// 2%: no CI (Linux) o golden com mais texto deu 1,09% de diferença na
  /// suavização; uma foto ou um bloco fora do lugar passa bem disso.
  static const tolerancia = 0.02;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final resultado = await GoldenFileComparator.compareLists(
        imageBytes, await getGoldenBytes(golden));
    if (resultado.passed || resultado.diffPercent <= tolerancia) {
      resultado.dispose();
      return true;
    }
    final erro = await generateFailureOutput(resultado, golden, basedir);
    resultado.dispose();
    throw FlutterError(erro);
  }
}

Pet _pet({
  String nome = 'Mimi',
  String especie = 'Gato',
  String raca = 'Siamês',
  String cor = 'Creme com pontas marrons',
}) =>
    Pet(
      id: 'pet-1',
      userId: 'uid-1',
      nome: nome,
      especie: especie,
      raca: raca,
      cor: cor,
      genero: 'Fêmea',
      porte: 'Pequeno',
      peso: '',
      dataNascimento: '',
      vacinado: true,
    );

/// Imagem de teste: fundo de uma cor e um círculo branco fora do centro,
/// para o recorte aparecer na regressão visual.
Future<Uint8List> _imagem(int largura, int altura, Color cor) async {
  final gravador = ui.PictureRecorder();
  final tela = Canvas(gravador);
  final w = largura.toDouble(), h = altura.toDouble();
  tela.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = cor);
  tela.drawCircle(Offset(w * 0.3, h * 0.3), (w < h ? w : h) * 0.2,
      Paint()..color = Colors.white);
  final imagem = await gravador.endRecording().toImage(largura, altura);
  final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
  imagem.dispose();
  return dados!.buffer.asUint8List();
}

late List<FotoDoAparelho> _fotos;

RascunhoCartaz _rascunho({
  List<EnquadramentoFoto> enquadramentos = const [
    EnquadramentoFoto.centralizado,
    EnquadramentoFoto.centralizado,
    EnquadramentoFoto.centralizado,
  ],
  String? caracteristicas,
  String vistoPorUltimoEm = '',
  String desapareceuEm = '',
  String observacoes = '',
  String recompensa = '',
  int fotos = 3,
}) =>
    RascunhoCartaz(
      espacos: [
        for (var i = 0; i < 3; i++)
          i < fotos
              ? EspacoDeFoto(foto: _fotos[i], enquadramento: enquadramentos[i])
              : EspacoDeFoto.vazio,
      ],
      caracteristicas: caracteristicas,
      vistoPorUltimoEm: vistoPorUltimoEm,
      desapareceuEm: desapareceuEm,
      observacoes: observacoes,
      recompensa: recompensa,
    );

final _limite = GlobalKey();

Future<void> _mostrar(WidgetTester tester, ConteudoCartaz conteudo) async {
  tester.view.physicalSize =
      const Size(CartazProcuraSe.largura, CartazProcuraSe.altura);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _limite,
        child: CartazProcuraSe(conteudo: conteudo),
      ),
    ),
  ));
  final contexto = tester.element(find.byType(CartazProcuraSe));
  await tester.runAsync(() async {
    for (final espaco in conteudo.espacos) {
      if (espaco.foto != null) {
        await precacheImage(imagemDoCartaz(espaco.foto!), contexto);
      }
    }
  });
  await tester.pump();
}

Rect _rect(WidgetTester tester, String chave) =>
    tester.getRect(find.byKey(ValueKey(chave)));

/// Número fictício.
const _telefone = '11900000000';

void main() {
  setUpAll(() async {
    final atual = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _ComparadorTolerante(
        Uri.parse('${atual.basedir}cartaz_layout_test.dart'));
  });

  setUpAll(() async {
    // Uma paisagem, um retrato e um quadrado: orientações diferentes.
    final bytes = await Future.wait([
      _imagem(1200, 800, const Color(0xFF8D6E63)),
      _imagem(600, 900, const Color(0xFF455A64)),
      _imagem(700, 700, const Color(0xFF7CB342)),
    ]);
    _fotos = [for (final b in bytes) FotoDoAparelho(b)];
  });

  testWidgets('gato com todos os dados: composição do modelo', (tester) async {
    final rascunho = _rascunho(
      vistoPorUltimoEm: 'Praça da Matriz, Centro',
      desapareceuEm: '20/10, à noite',
      observacoes: 'Muito medrosa. Mancha escura na orelha esquerda.',
      recompensa: 'R\$ 300',
    );
    await _mostrar(
        tester,
        ConteudoCartaz.de(
            pet: _pet(), rascunho: rascunho, telefone: _telefone));

    expect(tester.getSize(find.byType(CartazProcuraSe)),
        const Size(CartazProcuraSe.largura, CartazProcuraSe.altura));
    expect(find.text('PROCURA-SE'), findsOneWidget);
    expect(find.text('MIMI'), findsOneWidget);
    expect(find.text('GATO DESAPARECIDO'), findsOneWidget);
    expect(find.text('(11) 90000-0000'), findsOneWidget);
    for (final rotulo in [
      'Nome:',
      'Espécie/Raça:',
      'Cor:',
      'Características:',
      'Visto por último em:',
      'Desapareceu em:',
      'Observações:',
      'Recompensa:',
    ]) {
      expect(find.text(rotulo), findsOneWidget, reason: rotulo);
    }

    // Uma foto grande à esquerda e duas menores empilhadas à direita.
    final principal = _rect(tester, 'cartaz-foto-0');
    final segunda = _rect(tester, 'cartaz-foto-1');
    final terceira = _rect(tester, 'cartaz-foto-2');
    expect(principal.right, lessThan(segunda.left));
    expect(segunda.left, terceira.left);
    expect(segunda.bottom, lessThan(terceira.top));
    expect(principal.top, segunda.top);
    expect(principal.bottom, terceira.bottom);
    expect(principal.width, greaterThan(segunda.width));
    expect(principal.height, greaterThan(segunda.height * 1.8));

    // Ordem vertical: cabeçalho, título, fotos, dados, contato.
    expect(_rect(tester, 'cartaz-nome').bottom,
        lessThan(_rect(tester, 'cartaz-titulo').top));
    expect(_rect(tester, 'cartaz-titulo').bottom, lessThan(principal.top));
    expect(principal.bottom, lessThan(_rect(tester, 'cartaz-dados').top));
    expect(_rect(tester, 'cartaz-dados').bottom,
        lessThan(_rect(tester, 'cartaz-telefone').top));

    await expectLater(find.byType(CartazProcuraSe),
        matchesGoldenFile('goldens/cartaz_gato_completo.png'));
  });

  testWidgets('cachorro sem campos opcionais: nada vazio, fotos maiores',
      (tester) async {
    await _mostrar(
        tester,
        ConteudoCartaz.de(
          pet: _pet(nome: 'Thor', especie: 'Cachorro', raca: '', cor: ''),
          rascunho: _rascunho(caracteristicas: ''),
          telefone: _telefone,
        ));

    expect(find.text('CACHORRO DESAPARECIDO'), findsOneWidget);
    expect(find.text('Nome:'), findsOneWidget);
    expect(find.text('Espécie/Raça:'), findsOneWidget);
    for (final rotulo in [
      'Cor:',
      'Características:',
      'Visto por último em:',
      'Desapareceu em:',
      'Observações:',
      'Recompensa:',
    ]) {
      expect(find.text(rotulo), findsNothing, reason: rotulo);
    }
    expect(find.textContaining('null'), findsNothing);
    expect(_rect(tester, 'cartaz-foto-0').height, greaterThan(600));

    await expectLater(find.byType(CartazProcuraSe),
        matchesGoldenFile('goldens/cartaz_cachorro_sem_opcionais.png'));
  });

  testWidgets('nome longo encolhe para caber na faixa, sem cortar',
      (tester) async {
    const nome = 'Príncipe Frederico Augusto de Bragança';
    await _mostrar(
        tester,
        ConteudoCartaz.de(
            pet: _pet(nome: nome, especie: 'Coelho'),
            rascunho: _rascunho(),
            telefone: _telefone));

    expect(find.text(nome.toUpperCase()), findsOneWidget);
    expect(find.text('PET DESAPARECIDO'), findsOneWidget);
    final texto = _rect(tester, 'cartaz-nome');
    expect(texto.left, greaterThanOrEqualTo(0));
    expect(texto.right, lessThanOrEqualTo(CartazProcuraSe.largura));

    await expectLater(find.byType(CartazProcuraSe),
        matchesGoldenFile('goldens/cartaz_nome_longo.png'));
  });

  testWidgets('textos no limite e telefone fixo: cabem sem cortar',
      (tester) async {
    String limite(int n) =>
        ('Áçãé longo com acentuação e várias palavras ' * 10).substring(0, n);
    await _mostrar(
        tester,
        ConteudoCartaz.de(
          pet: _pet(cor: limite(40)),
          rascunho: _rascunho(
            caracteristicas: limite(LimitesCartaz.caracteristicas),
            vistoPorUltimoEm: limite(LimitesCartaz.vistoPorUltimoEm),
            desapareceuEm: limite(LimitesCartaz.desapareceuEm),
            observacoes: limite(LimitesCartaz.observacoes),
            recompensa: limite(LimitesCartaz.recompensa),
          ),
          telefone: '1134567890',
        ));

    expect(tester.takeException(), isNull);
    expect(find.text('(11) 3456-7890'), findsOneWidget);
    expect(find.text(limite(LimitesCartaz.observacoes)), findsOneWidget);
    expect(_rect(tester, 'cartaz-foto-0').height,
        greaterThanOrEqualTo(CartazProcuraSe.alturaMinimaDasFotos));

    // A escala dos dados com a fonte real (Roboto) é conferida em
    // test/evidencias/cartaz_evidencia_test.dart: a fonte de teste tem
    // letras duas vezes mais largas e não serve para medir isso.

    await expectLater(find.byType(CartazProcuraSe),
        matchesGoldenFile('goldens/cartaz_textos_longos.png'));
  });

  testWidgets('enquadramento: zoom e posição mudam o recorte', (tester) async {
    await _mostrar(
        tester,
        ConteudoCartaz.de(
          pet: _pet(),
          rascunho: _rascunho(enquadramentos: const [
            EnquadramentoFoto(x: -1, y: -1, zoom: 2),
            EnquadramentoFoto(y: 1),
            EnquadramentoFoto(x: 1, zoom: 1.5),
          ]),
          telefone: _telefone,
        ));

    final escalas = tester
        .widgetList<Transform>(find.descendant(
            of: find.byType(FotoEnquadrada), matching: find.byType(Transform)))
        .map((t) => t.transform.getMaxScaleOnAxis())
        .toList();
    expect(escalas, [2.0, 1.0, 1.5]);

    await expectLater(find.byType(CartazProcuraSe),
        matchesGoldenFile('goldens/cartaz_enquadramento.png'));
  });

  testWidgets('rascunho incompleto mostra os espaços vazios na prévia',
      (tester) async {
    await _mostrar(
        tester,
        ConteudoCartaz.de(
            pet: _pet(), rascunho: _rascunho(fotos: 1), telefone: null));

    expect(find.text('FOTO 2'), findsOneWidget);
    expect(find.text('FOTO 3'), findsOneWidget);
    expect(find.text('FOTO PRINCIPAL'), findsNothing);
  });

  testWidgets('tamanho de fonte do sistema não muda o cartaz', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _mostrar(
        tester,
        ConteudoCartaz.de(
            pet: _pet(), rascunho: _rascunho(), telefone: _telefone));

    expect(tester.takeException(), isNull);
    final texto = tester.widget<RichText>(find
        .descendant(
            of: find.byKey(const ValueKey('cartaz-telefone')),
            matching: find.byType(RichText))
        .first);
    expect(texto.textScaler, TextScaler.noScaling);
  });

  testWidgets('PNG exportado: 2110 × 2982 px, a mesma composição da prévia',
      (tester) async {
    await _mostrar(
        tester,
        ConteudoCartaz.de(
            pet: _pet(), rascunho: _rascunho(), telefone: _telefone));

    final limite =
        _limite.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final tamanho = await tester.runAsync(() async {
      final imagem = await limite.toImage(pixelRatio: 2);
      final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
      final medidas = (imagem.width, imagem.height, png!.lengthInBytes);
      imagem.dispose();
      return medidas;
    });
    expect(tamanho!.$1, 2110);
    expect(tamanho.$2, 2982);
    expect(tamanho.$3, greaterThan(0));
  });
}
