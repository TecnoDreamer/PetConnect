import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Lado máximo das fotos de perfil (tutor e pet) e da capa ao escolher na
/// galeria. Bem acima do que as telas mostram, inclusive em tela cheia, e
/// deixa o arquivo pequeno para o envio ser rápido.
const ladoMaximoDaFoto = 1600.0;

/// Guarda no cache de imagens a foto que o app acabou de enviar, com a URL
/// que o Cloudinary devolveu. Assim a Home, o perfil do pet e as outras telas
/// mostram a foto nova na hora, sem baixar de novo o que já está no celular.
///
/// É o mesmo cache do `CachedNetworkImage`. Uma falha aqui só faz a tela
/// baixar a foto, como antes.
Future<void> guardarFotoEnviadaNoCache(
  String url,
  Uint8List bytes, {
  Future<void> Function(String url, Uint8List bytes)? guardar,
}) async {
  try {
    await (guardar ?? _guardarNoCachePadrao)(url, bytes);
  } catch (_) {}
}

Future<void> _guardarNoCachePadrao(String url, Uint8List bytes) =>
    DefaultCacheManager().putFile(url, bytes, fileExtension: 'jpg');
