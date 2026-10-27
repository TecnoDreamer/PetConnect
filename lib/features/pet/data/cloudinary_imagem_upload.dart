import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/anexo_repository.dart';

/// Envio de uma imagem ao Cloudinary com progresso e cancelamento, usado
/// pelos dois [AnexoRepository] (preset unsigned e assinatura da API).
/// [campos] são os parâmetros de autorização de cada modo
/// (`upload_preset`, ou `api_key`/`timestamp`/`signature`/`folder`).
///
/// Vai para `/image/upload`: o Cloudinary recusa o que não for imagem,
/// conferindo o conteúdo do arquivo do lado de lá.
Future<ImagemEnviada> enviarImagemAoCloudinary({
  required http.Client cliente,
  required String cloudName,
  required Map<String, String> campos,
  required String nomeArquivo,
  required Uint8List bytes,
  void Function(double fracao)? aoProgredir,
  Future<void>? cancelar,
}) async {
  final uri =
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
  final request = _EnvioComProgresso('POST', uri,
      abortTrigger: cancelar, aoProgredir: aoProgredir)
    ..fields.addAll(campos)
    ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: nomeArquivo));

  final http.Response response;
  try {
    response = await http.Response.fromStream(await cliente.send(request));
  } on http.RequestAbortedException {
    throw const EnvioCancelado();
  }

  if (response.statusCode != 200) {
    throw Exception(
        'Falha no upload para o Cloudinary (${response.statusCode}): ${response.body}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return ImagemEnviada(
    url: data['secure_url'] as String,
    publicId: data['public_id'] as String,
    largura: (data['width'] as num?)?.toInt(),
    altura: (data['height'] as num?)?.toInt(),
  );
}

/// Conta os bytes à medida que o corpo é entregue ao cliente HTTP. É o
/// progresso real do envio, com a ressalva de que o último trecho fica no
/// buffer do sistema até a resposta chegar.
class _EnvioComProgresso extends http.MultipartRequest with http.Abortable {
  _EnvioComProgresso(super.method, super.url,
      {this.abortTrigger, this.aoProgredir});

  @override
  final Future<void>? abortTrigger;

  final void Function(double fracao)? aoProgredir;

  @override
  http.ByteStream finalize() {
    final corpo = super.finalize();
    final total = contentLength;
    final avisar = aoProgredir;
    if (avisar == null || total <= 0) return corpo;

    var enviados = 0;
    return http.ByteStream(corpo.transform(
      StreamTransformer.fromHandlers(handleData: (pedaco, sink) {
        enviados += pedaco.length;
        avisar((enviados / total).clamp(0, 1).toDouble());
        sink.add(pedaco);
      }),
    ));
  }
}
