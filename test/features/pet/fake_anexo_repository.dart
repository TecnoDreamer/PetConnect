import 'dart:typed_data';

import 'package:pet_connect/features/pet/domain/anexo_repository.dart';

/// Fake sem operação real — nos testes de widget, o fluxo de seleção de
/// arquivo (image_picker) não é exercido, pois depende de um canal de
/// plataforma indisponível em `flutter test`. Isto só evita que os
/// providers de histórico médico toquem o Firebase Storage real.
///
/// Para a galeria, registra os envios e exclusões e pode falhar sob
/// demanda ([falharEnvio], [falharExclusao]).
class FakeAnexoRepository implements AnexoRepository {
  final enviadas = <String>[];
  final excluidas = <String>[];
  Object? falharEnvio;
  Object? falharExclusao;
  var _contador = 0;

  @override
  Future<String> upload(
      {required String path,
      required Uint8List bytes,
      required String contentType}) async {
    return 'https://fake.storage/$path';
  }

  @override
  Future<void> delete(String url) async {
    final erro = falharExclusao;
    if (erro != null) throw erro;
    excluidas.add(url);
  }

  @override
  Future<ImagemEnviada> enviarImagem({
    required String nomeArquivo,
    required Uint8List bytes,
    void Function(double fracao)? aoProgredir,
    Future<void>? cancelar,
  }) async {
    final erro = falharEnvio;
    if (erro != null) throw erro;
    aoProgredir?.call(0.5);
    aoProgredir?.call(1);
    final n = ++_contador;
    final url =
        'https://res.cloudinary.com/demo/image/upload/v1/users/u/foto$n.jpg';
    enviadas.add(url);
    return ImagemEnviada(
        url: url, publicId: 'users/u/foto$n', largura: 800, altura: 600);
  }
}
