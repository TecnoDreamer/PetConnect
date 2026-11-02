// Evidência da exportação do QR code (docs/features/qr-exportacao.md): grava
// um PNG e um PDF de exemplo, de um pet fictício, em build/evidencias/.
// Fora do CI de propósito. Rodar com:
//   flutter test test/evidencias/qr_evidencia_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/data/exportacao_qr.dart';

/// URL no formato real, com um publicId fictício.
const _url =
    'https://pet-connect-c53f1.web.app/pet/00000000-0000-4000-8000-000000000000';

void main() {
  test('PNG e PDF de exemplo', () async {
    Directory('build/evidencias').createSync(recursive: true);
    File('build/evidencias/qr_exemplo.png')
        .writeAsBytesSync(await gerarPngDoQr(_url));
    File('build/evidencias/qr_exemplo.pdf').writeAsBytesSync(
        await gerarPdfDoQr(dados: _url, nomeDoPet: 'Rex Ção'));
  });
}
