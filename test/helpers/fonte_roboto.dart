import 'dart:io';

import 'package:flutter/services.dart';

/// Carrega a Roboto (fonte padrão do Material no Android) a partir do
/// cache do próprio Flutter SDK, para testes que medem geometria real.
///
/// Sem isto, `flutter test` desenha todo texto com a fonte de teste
/// "FlutterTest", em que cada caractere ocupa 1em de largura — bem mais
/// larga que a Roboto — e textos que cabem numa linha no aparelho quebram
/// em duas ou três no teste, distorcendo qualquer medida de altura.
Future<void> carregarRoboto() async {
  final raizFlutter = Platform.environment['FLUTTER_ROOT'];
  if (raizFlutter == null) {
    throw StateError('FLUTTER_ROOT não definido — rode com `flutter test`.');
  }
  final pasta = '$raizFlutter/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final arquivo in const [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]) {
    final fonte = File('$pasta/$arquivo');
    if (!fonte.existsSync()) {
      throw StateError('Fonte não encontrada: ${fonte.path}. Rode '
          '`flutter precache` para baixar os artefatos do SDK.');
    }
    final bytes = fonte.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}
