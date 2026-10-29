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
  VistoPorUltimo vistoPorUltimo = VistoPorUltimo.vazio,
  String observacoes = '',
  Recompensa recompensa = Recompensa.nenhuma,
  CorDoCartaz cor = CorDoCartaz.preto,
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
      vistoPorUltimo: vistoPorUltimo,
      observacoes: observacoes,
      recompensa: recompensa,
      cor: cor,
    );

final _limite = GlobalKey();

Future<void> _mostrar(WidgetTester tester, ConteudoCartaz conteudo,
    {ValueChanged<Size>? aoMedirMosaico}) async {
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
        child:
            CartazProcuraSe(conteudo: conteudo, aoMedirMosaico: aoMedirMosaico),
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
      vistoPorUltimo: VistoPorUltimo(
          data: DateTime(2026, 10, 20),
          periodo: PeriodoDoDia.noite,
          local: 'Praça da Matriz, Centro'),
      observacoes: 'Muito medrosa. Mancha escura na orelha esquerda.',
      recompensa: const Recompensa(centavos: 30000),
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
      'Características:',
      'Visto por último:',
      'Recompensa:',
      'OBSERVAÇÕES',
    ]) {
      expect(find.text(rotulo), findsOneWidget, reason: rotulo);
    }
    // Fora do cartaz, a pedido do proprietário.
    for (final rotulo in ['Espécie/Raça:', 'Cor:', 'Desapareceu em:']) {
      expect(find.text(rotulo), findsNothing, reason: rotulo);
    }
    expect(find.text('20/10/2026, à noite — Praça da Matriz, Centro'),
        findsOneWidget);
    expect(find.text('R\$ 300,00'), findsOneWidget);

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

    // Observações em destaque: largura toda, abaixo das linhas de dados e
    // com letra maior que a delas.
    final observacoes = _rect(tester, 'cartaz-observacoes');
    expect(observacoes.top,
        greaterThan(tester.getRect(find.text('Recompensa:')).bottom));
    final dados = tester.getRect(find
        .descendant(
            of: find.byKey(const ValueKey('cartaz-dados')),
            matching: find.byType(SizedBox))
        .first);
    expect(observacoes.width, closeTo(dados.width, 1));
    final valor = tester.widget<Text>(
        find.text('Muito medrosa. Mancha escura na orelha esquerda.'));
    expect(valor.style!.fontSize, greaterThan(30));

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
    for (final rotulo in [
      'Características:',
      'Visto por último:',
      'OBSERVAÇÕES',
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
          pet: _pet(),
          rascunho: _rascunho(
            caracteristicas: limite(LimitesCartaz.caracteristicas),
            vistoPorUltimo: VistoPorUltimo(
                data: DateTime(2026, 10, 29),
                horario: 23 * 60 + 59,
                local: limite(LimitesCartaz.localVisto)),
            observacoes: limite(LimitesCartaz.observacoes),
            recompensa:
                const Recompensa(centavos: LimitesCartaz.recompensaEmCentavos),
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

  testWidgets('enquadramento: foco, zoom e foto inteira', (tester) async {
    await _mostrar(
        tester,
        ConteudoCartaz.de(
          pet: _pet(),
          rascunho: _rascunho(enquadramentos: const [
            EnquadramentoFoto(focoX: 0, focoY: 0, zoom: 2),
            EnquadramentoFoto(focoY: 1),
            EnquadramentoFoto(inteira: true),
          ]),
          telefone: _telefone,
        ));

    Rect foto(int i) => tester.getRect(find
        .descendant(
            of: find.byKey(ValueKey('cartaz-foto-$i')),
            matching: find.byType(Image))
        .first);
    final principal = _rect(tester, 'cartaz-foto-0');
    // Paisagem 3:2 com zoom 2 e foco no canto: a foto encosta no canto do
    // espaço e fica com o dobro da altura dele.
    expect(foto(0).topLeft, principal.topLeft);
    expect(foto(0).height, closeTo(principal.height * 2, 0.5));
    expect(foto(0).width, closeTo(foto(0).height * 1.5, 0.5));
    // Retrato num espaço largo, foco embaixo: a base da foto na base dele.
    expect(foto(1).bottom, closeTo(_rect(tester, 'cartaz-foto-1').bottom, 0.5));
    // Foto inteira: sem corte, sobre o fundo desfocado.
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('cartaz-foto-2')),
            matching: find.byType(ImageFiltered)),
        findsOneWidget);
    final inteira = tester.widget<Image>(find
        .descendant(
            of: find.byKey(const ValueKey('cartaz-foto-2')),
            matching: find.byType(Image))
        .last);
    expect(inteira.fit, BoxFit.contain);

    await expectLater(find.byType(CartazProcuraSe),
        matchesGoldenFile('goldens/cartaz_enquadramento.png'));
  });

  testWidgets('cor escolhida no cabeçalho e no rodapé', (tester) async {
    await _mostrar(
        tester,
        ConteudoCartaz.de(
          pet: _pet(),
          rascunho: _rascunho(
              cor: CorDoCartaz.vermelho, observacoes: 'Atende pelo nome'),
          telefone: _telefone,
        ));

    BoxDecoration decoracao(String chave) {
      final caixa = tester.widget(find.byKey(ValueKey(chave)));
      return (caixa is Container
          ? caixa.decoration
          : (caixa as DecoratedBox).decoration)! as BoxDecoration;
    }

    const vermelho = Color(0xFFC62828);
    expect(decoracao('cartaz-cabecalho').color, vermelho);
    expect(decoracao('cartaz-rodape').color, vermelho);

    await expectLater(find.byType(CartazProcuraSe),
        matchesGoldenFile('goldens/cartaz_vermelho.png'));
  });

  testWidgets('medida do mosaico bate com os espaços de foto', (tester) async {
    Size? mosaico;
    await _mostrar(
        tester,
        ConteudoCartaz.de(
            pet: _pet(), rascunho: _rascunho(), telefone: _telefone),
        aoMedirMosaico: (m) => mosaico = m);
    await tester.pump();

    expect(mosaico, isNotNull);
    final espacos = CartazProcuraSe.espacosDoMosaico(mosaico!);
    for (var i = 0; i < 3; i++) {
      final real = _rect(tester, 'cartaz-foto-$i').size;
      expect(espacos[i].width, closeTo(real.width, 0.01), reason: '$i');
      expect(espacos[i].height, closeTo(real.height, 0.01), reason: '$i');
    }
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
