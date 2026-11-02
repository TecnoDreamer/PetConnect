// Exportação do QR code para impressão (docs/features/qr-exportacao.md):
// o arquivo tem o mesmo conteúdo e a mesma matriz do QR da tela, é lido
// por um decodificador de verdade (zxing) e não leva dados pessoais.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/data/exportacao_qr.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/domain/pet_qr_code.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zxing2/qrcode.dart';

Pet _pet({String nome = 'Rex', String? qrPublicId}) => Pet(
      id: 'pet-1',
      userId: 'uid-1',
      nome: nome,
      especie: 'Cachorro',
      raca: '',
      cor: '',
      genero: '',
      porte: '',
      peso: '',
      dataNascimento: '',
      vacinado: false,
      qrPublicId: qrPublicId,
    );

/// Pixel opaco preto e branco, como inteiros de 32 bits com sinal (RGBA).
final _preto = 0xFF000000.toSigned(32);
const _branco = -1;

/// Pixels do PNG (um inteiro por pixel) e o tamanho.
Future<({Int32List pixels, int largura, int altura})> _pixels(
    Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final quadro = await codec.getNextFrame();
  final imagem = quadro.image;
  final rgba = (await imagem.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final resultado = (
    pixels: Int32List.fromList(rgba.buffer.asInt32List()),
    largura: imagem.width,
    altura: imagem.height,
  );
  imagem.dispose();
  codec.dispose();
  return resultado;
}

/// Lê o QR do PNG como um leitor faria (zxing, porta Dart).
Future<String> _lerQr(Uint8List png) async {
  final p = await _pixels(png);
  final fonte = RGBLuminanceSource(p.largura, p.altura, p.pixels);
  return QRCodeReader()
      .decode(BinaryBitmap(GlobalHistogramBinarizer(fonte)))
      .text;
}

void main() {
  group('PNG', () {
    test('é lido por um decodificador e dá a mesma URL da tela', () async {
      for (final pet in [
        _pet(), // pet antigo: publicId calculado
        _pet(qrPublicId: 'b0f6c1a2-novo-qr-depois-de-regenerar'),
      ]) {
        final png = await gerarPngDoQr(publicPetUrl(pet));
        expect(await _lerQr(png), publicPetUrl(pet));
      }
    });

    test('alta resolução, quadrado, módulos inteiros e só preto e branco',
        () async {
      final url = publicPetUrl(_pet());
      final png = await gerarPngDoQr(url);
      final p = await _pixels(png);
      final qr = matrizDoQr(url);
      final total = qr.moduleCount + 2 * margemDoQrEmModulos;

      expect(p.largura, p.altura);
      expect(p.largura, greaterThanOrEqualTo(1200));
      expect(p.largura % total, 0, reason: 'módulo com número inteiro de px');

      final cores = p.pixels.toSet();
      expect(cores, {_preto, _branco}, reason: 'sem cinza de suavização');

      // Cada módulo no lugar certo, e a margem de 4 módulos toda branca.
      final modulo = p.largura ~/ total;
      bool escuro(int linha, int coluna) {
        final x = coluna * modulo + modulo ~/ 2;
        final y = linha * modulo + modulo ~/ 2;
        return p.pixels[y * p.largura + x] == _preto;
      }

      for (var linha = 0; linha < total; linha++) {
        for (var coluna = 0; coluna < total; coluna++) {
          final dentro = linha >= margemDoQrEmModulos &&
              coluna >= margemDoQrEmModulos &&
              linha < total - margemDoQrEmModulos &&
              coluna < total - margemDoQrEmModulos;
          final esperado = dentro &&
              qr.isDark(
                  linha - margemDoQrEmModulos, coluna - margemDoQrEmModulos);
          expect(escuro(linha, coluna), esperado,
              reason: 'módulo ($linha, $coluna)');
        }
      }
    });
  });

  test('a matriz é a mesma que o QrImageView da tela desenha', () {
    final url = publicPetUrl(_pet(qrPublicId: 'qr-atual'));
    // O mesmo caminho do QrImageView: validação com versão automática e o
    // nível de correção da tela.
    final validacao = QrValidator.validate(
        data: url, errorCorrectionLevel: nivelDeCorrecaoDoQr);
    expect(validacao.isValid, isTrue);
    final daTela = QrImage(validacao.qrCode!);
    final doArquivo = matrizDoQr(url);
    expect(doArquivo.moduleCount, daTela.moduleCount);
    for (var linha = 0; linha < daTela.moduleCount; linha++) {
      for (var coluna = 0; coluna < daTela.moduleCount; coluna++) {
        expect(doArquivo.isDark(linha, coluna), daTela.isDark(linha, coluna));
      }
    }
  });

  group('PDF', () {
    test('uma página A4, vetorial (sem imagem embutida)', () async {
      final pdf =
          await gerarPdfDoQr(dados: publicPetUrl(_pet()), nomeDoPet: 'Rex');
      final texto = latin1.decode(pdf);
      expect(texto, startsWith('%PDF'));
      expect(RegExp(r'/Type\s*/Page\b').allMatches(texto), hasLength(1));
      expect(texto, contains('595.27'));
      expect(texto, isNot(contains('/Subtype /Image')));
      expect(texto, isNot(contains('/Subtype/Image')));
    });

    test('nome com caracteres especiais não quebra o PDF', () async {
      final pdf = await gerarPdfDoQr(
          dados: publicPetUrl(_pet()), nomeDoPet: 'Ção Ñandú 🐶 "Bolt" <3');
      expect(latin1.decode(pdf), startsWith('%PDF'));
      expect(textoParaPdf('Ção Ñandú 🐶 "Bolt" <3'), 'Ção Ñandú  "Bolt" <3');
      expect(textoParaPdf('🐶'), '');
    });
  });

  group('nome do arquivo', () {
    test('sem nome do pet nem identificador interno', () {
      final pet = _pet(nome: 'Rex');
      final nome = nomeDoArquivoDoQr(
          publicId: publicIdDoQr(pet),
          data: DateTime(2026, 11, 2),
          extensao: 'png');
      expect(
          nome, matches(RegExp(r'^petconnect-qr-[0-9a-f]{8}-20261102\.png$')));
      expect(nome, isNot(contains('Rex')));
      expect(nome, isNot(contains('pet-1')));
      expect(nome, isNot(contains(publicIdDoQr(pet))));
    });

    test('um QR regenerado gera outro nome', () {
      String nome(Pet pet) => nomeDoArquivoDoQr(
          publicId: publicIdDoQr(pet),
          data: DateTime(2026, 11, 2),
          extensao: 'pdf');
      expect(nome(_pet()), isNot(nome(_pet(qrPublicId: 'qr-novo'))));
    });
  });
}
