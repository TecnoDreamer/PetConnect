// Evidência do cartaz de pet desaparecido com a fonte real (Roboto do SDK do
// Flutter), para conferir legibilidade e gerar PNG e PDF de exemplo com dados
// fictícios (docs/features/cartaz-pet-desaparecido.md, "Evidências").
//
// Fora do CI de propósito: depende das fontes no cache do SDK e grava em
// build/evidencias/. Rodar com:
//   flutter test test/evidencias/cartaz_evidencia_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/data/exportacao_cartaz.dart';
import 'package:pet_connect/features/pet/domain/cartaz_desaparecido.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/presentation/widgets/cartaz_procura_se.dart';

/// `.../bin/cache/artifacts/engine/<plataforma>/flutter_tester` →
/// `.../bin/cache/artifacts/material_fonts`.
Directory get _fontes =>
    Directory('${File(Platform.resolvedExecutable).parent.parent.parent.path}'
        '${Platform.pathSeparator}material_fonts');

Future<void> _carregarRoboto() async {
  final roboto = FontLoader('Roboto');
  for (final peso in ['regular', 'medium', 'bold', 'black']) {
    final bytes = File('${_fontes.path}/roboto-$peso.ttf').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await roboto.load();
}

Future<Uint8List> _imagem(
    int largura, int altura, Color fundo, Color forma) async {
  final gravador = ui.PictureRecorder();
  final tela = Canvas(gravador);
  final w = largura.toDouble(), h = altura.toDouble();
  tela.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = fundo);
  tela.drawOval(Rect.fromLTWH(w * 0.25, h * 0.2, w * 0.5, h * 0.6),
      Paint()..color = forma);
  final imagem = await gravador.endRecording().toImage(largura, altura);
  final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
  imagem.dispose();
  return dados!.buffer.asUint8List();
}

Pet _pet({String nome = 'Mimi', String especie = 'Gato'}) => Pet(
      id: 'pet-exemplo',
      userId: 'uid-exemplo',
      nome: nome,
      especie: especie,
      raca: 'Siamês',
      cor: 'Creme com pontas marrons',
      genero: 'Fêmea',
      porte: 'Pequeno',
      peso: '',
      dataNascimento: '',
      vacinado: true,
    );

/// Número fictício (prefixo 9 0000, sem assinante).
const _telefone = '11900000000';

void main() {
  final disponivel = _fontes.existsSync();

  late List<FotoDoAparelho> fotos;

  setUpAll(() async {
    if (!disponivel) return;
    await _carregarRoboto();
    fotos = [
      FotoDoAparelho(await _imagem(
          1200, 900, const Color(0xFFBCAAA4), const Color(0xFF6D4C41))),
      FotoDoAparelho(await _imagem(
          700, 900, const Color(0xFF90A4AE), const Color(0xFF37474F))),
      FotoDoAparelho(await _imagem(
          900, 700, const Color(0xFFC5E1A5), const Color(0xFF558B2F))),
    ];
    Directory('build/evidencias').createSync(recursive: true);
  });

  Future<void> gerar(
    WidgetTester tester,
    String nome,
    ConteudoCartaz conteudo, {
    bool pdf = false,
  }) async {
    final limite = GlobalKey();
    tester.view.physicalSize =
        const Size(CartazProcuraSe.largura, CartazProcuraSe.altura);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      debugShowCheckedModeBanner: false,
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
            key: limite, child: CartazProcuraSe(conteudo: conteudo)),
      ),
    ));
    final contexto = tester.element(find.byType(CartazProcuraSe));
    await tester.runAsync(() async {
      for (final espaco in conteudo.espacos) {
        await precacheImage(imagemDoCartaz(espaco.foto!), contexto);
      }
    });
    await tester.pump();
    expect(tester.takeException(), isNull);

    final dados = find.byKey(const ValueKey('cartaz-dados'));
    final natural = tester.getSize(
        find.descendant(of: dados, matching: find.byType(SizedBox)).first);
    final escala = tester.getSize(dados).height / natural.height;
    // ignore: avoid_print
    print('$nome: escala dos dados ${escala.toStringAsFixed(2)}');
    expect(escala, greaterThanOrEqualTo(0.75), reason: nome);

    await tester.runAsync(() async {
      final render =
          limite.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final imagem = await render.toImage(pixelRatio: 2);
      final png = (await imagem.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      imagem.dispose();
      File('build/evidencias/$nome.png').writeAsBytesSync(png);
      if (pdf) {
        File('build/evidencias/$nome.pdf')
            .writeAsBytesSync(await gerarPdfDoCartaz(png));
      }
    });
  }

  RascunhoCartaz rascunho({
    String? caracteristicas,
    VistoPorUltimo vistoPorUltimo = VistoPorUltimo.vazio,
    String observacoes = '',
    Recompensa recompensa = Recompensa.nenhuma,
    CorDoCartaz cor = CorDoCartaz.preto,
    List<EnquadramentoFoto> enquadramentos = const [
      EnquadramentoFoto.centralizado,
      EnquadramentoFoto.centralizado,
      EnquadramentoFoto.centralizado,
    ],
  }) =>
      RascunhoCartaz(
        espacos: [
          for (var i = 0; i < 3; i++)
            EspacoDeFoto(foto: fotos[i], enquadramento: enquadramentos[i]),
        ],
        caracteristicas: caracteristicas,
        vistoPorUltimo: vistoPorUltimo,
        observacoes: observacoes,
        recompensa: recompensa,
        cor: cor,
      );

  testWidgets('gato com todos os dados', skip: !disponivel, (tester) async {
    await gerar(
      tester,
      'cartaz_gato_completo',
      ConteudoCartaz.de(
        pet: _pet(),
        rascunho: rascunho(
          caracteristicas: 'Fêmea, porte pequeno, olhos azuis',
          vistoPorUltimo: VistoPorUltimo(
              data: DateTime(2026, 10, 20),
              periodo: PeriodoDoDia.noite,
              local: 'Praça da Matriz, Centro'),
          observacoes: 'Muito medrosa: não corra atrás dela. Atende pelo '
              'nome e tem uma mancha escura na orelha esquerda.',
          recompensa: const Recompensa(centavos: 30000),
          enquadramentos: const [
            EnquadramentoFoto(focoX: 0.5, focoY: 0.4),
            EnquadramentoFoto(focoY: 0.3),
            EnquadramentoFoto(inteira: true),
          ],
        ),
        telefone: _telefone,
      ),
      pdf: true,
    );
  });

  for (final cor in [CorDoCartaz.vermelho, CorDoCartaz.azul]) {
    testWidgets('cartaz ${cor.nome.toLowerCase()}', skip: !disponivel,
        (tester) async {
      await gerar(
        tester,
        'cartaz_${cor.name}',
        ConteudoCartaz.de(
          pet: _pet(nome: 'Thor', especie: 'Cachorro'),
          rascunho: rascunho(
            caracteristicas: 'Macho, porte grande, coleira vermelha',
            vistoPorUltimo: VistoPorUltimo(
                data: DateTime(2026, 10, 28),
                horario: 18 * 60 + 30,
                local: 'Rua das Flores, perto da padaria'),
            observacoes: 'É dócil, mas assustado com barulho.',
            recompensa: const Recompensa(
                tipo: TipoRecompensa.outra, texto: 'A combinar'),
            cor: cor,
          ),
          telefone: _telefone,
        ),
      );
    });
  }

  testWidgets('cachorro sem campos opcionais', skip: !disponivel,
      (tester) async {
    await gerar(
      tester,
      'cartaz_cachorro_sem_opcionais',
      ConteudoCartaz.de(
        pet: _pet(nome: 'Thor', especie: 'Cachorro'),
        rascunho: rascunho(caracteristicas: ''),
        telefone: _telefone,
      ),
    );
  });

  testWidgets('textos no limite', skip: !disponivel, (tester) async {
    String limite(int n) =>
        ('Áçãé longo com acentuação e várias palavras ' * 10).substring(0, n);
    await gerar(
      tester,
      'cartaz_textos_no_limite',
      ConteudoCartaz.de(
        pet: _pet(nome: 'Príncipe Frederico Augusto', especie: 'Coelho'),
        rascunho: rascunho(
          caracteristicas: limite(LimitesCartaz.caracteristicas),
          vistoPorUltimo: VistoPorUltimo(
              data: DateTime(2026, 10, 29),
              horario: 23 * 60 + 59,
              local: limite(LimitesCartaz.localVisto)),
          observacoes: limite(LimitesCartaz.observacoes),
          recompensa:
              const Recompensa(centavos: LimitesCartaz.recompensaEmCentavos),
        ),
        telefone: '1134560000',
      ),
    );
  });
}
