import 'dart:io';

import 'package:flutter/services.dart';

/// Carrega a Roboto (fonte padrão do Material no Android) para testes que
/// medem geometria real.
///
/// Sem isto, `flutter test` desenha todo texto com a fonte de teste
/// "FlutterTest", em que cada caractere ocupa 1em de largura — bem mais
/// larga que a Roboto — e textos que cabem numa linha no aparelho quebram
/// em duas ou três no teste, distorcendo qualquer medida de altura.
///
/// Os arquivos ficam versionados em `test/fonts/` (Apache 2.0, ver
/// LICENSE-Roboto.txt): o cache de fontes do Flutter SDK não existe na
/// máquina do CI.
Future<void> carregarRoboto() async {
  final loader = FontLoader('Roboto');
  for (final arquivo in const [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]) {
    final bytes = File('test/fonts/$arquivo').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}
