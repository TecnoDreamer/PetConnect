import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

/// Exportação do QR code do pet para imprimir na coleira
/// (docs/features/qr-exportacao.md).
///
/// O arquivo codifica exatamente o que a tela mostra (`publicPetUrl`), com
/// a mesma matriz: mesmo pacote e mesmo nível de correção do `QrImageView`
/// de `PetQrCode`. Nada vai a servidor; o arquivo é gerado no celular.

/// Nível de correção do QR da tela e dos arquivos. É o padrão do
/// `QrImageView`, explícito para os dois nunca divergirem.
const nivelDeCorrecaoDoQr = QrErrorCorrectLevel.L;

/// Margem branca em volta do código (*quiet zone*), em módulos. A norma do
/// QR pede no mínimo 4.
const margemDoQrEmModulos = 4;

QrImage matrizDoQr(String dados) => QrImage(
    QrCode.fromData(data: dados, errorCorrectLevel: nivelDeCorrecaoDoQr));

/// PNG do QR: módulos pretos inteiros, sem suavização, sobre branco, com a
/// margem de [margemDoQrEmModulos]. O lado tem pelo menos [ladoMinimo] px e
/// é múltiplo exato do número de módulos, para nenhum módulo sair borrado.
Future<Uint8List> gerarPngDoQr(String dados, {int ladoMinimo = 1200}) async {
  final qr = matrizDoQr(dados);
  final total = qr.moduleCount + 2 * margemDoQrEmModulos;
  final modulo = (ladoMinimo / total).ceil();
  final lado = modulo * total;

  final gravador = ui.PictureRecorder();
  final tela = Canvas(gravador)
    ..drawRect(Rect.fromLTWH(0, 0, lado.toDouble(), lado.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF));
  final preto = Paint()
    ..color = const Color(0xFF000000)
    ..isAntiAlias = false;
  for (var linha = 0; linha < qr.moduleCount; linha++) {
    for (var coluna = 0; coluna < qr.moduleCount; coluna++) {
      if (!qr.isDark(linha, coluna)) continue;
      tela.drawRect(
        Rect.fromLTWH(
          ((coluna + margemDoQrEmModulos) * modulo).toDouble(),
          ((linha + margemDoQrEmModulos) * modulo).toDouble(),
          modulo.toDouble(),
          modulo.toDouble(),
        ),
        preto,
      );
    }
  }
  final imagem = await gravador.endRecording().toImage(lado, lado);
  try {
    final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
    return dados!.buffer.asUint8List();
  } finally {
    imagem.dispose();
  }
}

/// Tamanhos do QR na folha de impressão, em centímetros: um grande e três
/// para etiquetas de coleira.
const tamanhosDoQrNoPdf = [8.0, 4.0, 3.0, 2.0];

/// PDF A4 para imprimir: o QR em [tamanhosDoQrNoPdf], vetorial (nítido em
/// qualquer impressora), com o nome do pet e instruções. Sem telefone,
/// endereço nem dados de saúde.
Future<Uint8List> gerarPdfDoQr({
  required String dados,
  required String nomeDoPet,
}) async {
  final qr = matrizDoQr(dados);
  final nome = textoParaPdf(nomeDoPet);
  final documento =
      pw.Document(title: 'QR code de identificação', creator: 'PetConnect');

  pw.Widget codigo(double ladoEmCm) => pw.SizedBox(
        width: ladoEmCm * PdfPageFormat.cm,
        height: ladoEmCm * PdfPageFormat.cm,
        child: pw.CustomPaint(painter: (tela, tamanho) {
          final total = qr.moduleCount + 2 * margemDoQrEmModulos;
          final modulo = tamanho.x / total;
          tela
            ..setFillColor(PdfColors.white)
            ..drawRect(0, 0, tamanho.x, tamanho.y)
            ..fillPath()
            ..setFillColor(PdfColors.black);
          // Um caminho só, com uma faixa por sequência de módulos pretos:
          // sem frestas entre módulos vizinhos no leitor de PDF.
          for (var linha = 0; linha < qr.moduleCount; linha++) {
            var coluna = 0;
            while (coluna < qr.moduleCount) {
              if (!qr.isDark(linha, coluna)) {
                coluna++;
                continue;
              }
              final inicio = coluna;
              while (coluna < qr.moduleCount && qr.isDark(linha, coluna)) {
                coluna++;
              }
              // O PDF conta y de baixo para cima.
              tela.drawRect(
                (inicio + margemDoQrEmModulos) * modulo,
                tamanho.y - (linha + margemDoQrEmModulos + 1) * modulo,
                (coluna - inicio) * modulo,
                modulo,
              );
            }
          }
          tela.fillPath();
        }),
      );

  pw.Widget etiqueta(double ladoEmCm) => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          codigo(ladoEmCm),
          pw.SizedBox(height: 4),
          pw.Text('${ladoEmCm.toStringAsFixed(0)} cm',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
      );

  documento.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(2 * PdfPageFormat.cm),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('QR code de identificação',
            style: const pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold)),
        if (nome.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(nome, style: const pw.TextStyle(fontSize: 16)),
        ],
        pw.SizedBox(height: 18),
        codigo(tamanhosDoQrNoPdf.first),
        pw.SizedBox(height: 6),
        pw.Text(
            'Quem encontrar o pet pode escanear este código com a câmera '
            'do celular para ver como devolvê-lo.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 24),
        pw.Text('Para a coleira ou plaquinha',
            style: const pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            for (final lado in tamanhosDoQrNoPdf.skip(1)) etiqueta(lado)
          ],
        ),
        pw.Spacer(),
        pw.Text(
          'Imprima em tamanho real (100%, sem "ajustar à página"), em preto '
          'sobre papel branco. Antes de colocar na coleira, teste a leitura '
          'com a câmera do celular. Se você gerar um novo QR code no app, '
          'este deixa de funcionar e precisa ser impresso de novo.',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Gerado no app PetConnect',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    ),
  ));
  return documento.save();
}

/// A fonte padrão do PDF (Helvetica) só desenha os caracteres latinos do
/// Windows-1252, o que inclui os acentos do português. Outros caracteres,
/// como emojis, saem do nome no PDF; o QR não muda.
String textoParaPdf(String texto) => String.fromCharCodes(texto.runes
    .where((c) => (c >= 0x20 && c <= 0x7E) || (c >= 0xA0 && c <= 0xFF))).trim();

/// Nome do arquivo, sem dado pessoal: o identificador é o começo do SHA-256
/// do `publicId` do QR. Um QR novo, depois de regenerado, gera outro nome,
/// e o tutor não confunde o arquivo antigo com o atual.
String nomeDoArquivoDoQr({
  required String publicId,
  required DateTime data,
  required String extensao,
}) {
  final resumo =
      sha256.convert(utf8.encode(publicId)).toString().substring(0, 8);
  String dois(int n) => n.toString().padLeft(2, '0');
  final dia = '${data.year}${dois(data.month)}${dois(data.day)}';
  return 'petconnect-qr-$resumo-$dia.$extensao';
}
