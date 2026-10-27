import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../domain/anexo_repository.dart';
import 'cloudinary_imagem_upload.dart';

/// Upload/exclusão de anexos via Cloudinary **assinado** pelo backend
/// (FASE 10) — substitui o preset unsigned. O arquivo em si continua indo
/// direto do app pro Cloudinary (não passa pelo nosso servidor); só a
/// assinatura vem da API, então a API secret nunca fica no app.
class ApiAnexoRepository implements AnexoRepository {
  ApiAnexoRepository({required ApiClient api, http.Client? httpClient})
      : _api = api,
        _http = httpClient ?? http.Client();

  final ApiClient _api;
  final http.Client _http;

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final sig = await _api.post('/uploads/signature', const {});
    final cloudName = sig['cloudName'] as String;

    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = sig['apiKey'] as String
      ..fields['timestamp'] = sig['timestamp'].toString()
      ..fields['signature'] = sig['signature'] as String
      // 'folder' faz parte dos parâmetros assinados pela API (não é só
      // organização) — é como o servidor confirma posse na hora de
      // excluir depois; se não mandar exatamente esse valor, o Cloudinary
      // rejeita por assinatura inválida.
      ..fields['folder'] = sig['folder'] as String
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: path.split('/').last));

    final streamedResponse = await _http.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
          'Falha no upload para o Cloudinary (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  @override
  Future<ImagemEnviada> enviarImagem({
    required String nomeArquivo,
    required Uint8List bytes,
    void Function(double fracao)? aoProgredir,
    Future<void>? cancelar,
  }) async {
    final sig = await _api.post('/uploads/signature', const {});
    return enviarImagemAoCloudinary(
      cliente: _http,
      cloudName: sig['cloudName'] as String,
      campos: {
        'api_key': sig['apiKey'] as String,
        'timestamp': sig['timestamp'].toString(),
        'signature': sig['signature'] as String,
        // Mesmo motivo do upload(): 'folder' é parâmetro assinado.
        'folder': sig['folder'] as String,
      },
      nomeArquivo: nomeArquivo,
      bytes: bytes,
      aoProgredir: aoProgredir,
      cancelar: cancelar,
    );
  }

  @override
  Future<void> delete(String url) async {
    await _api.delete('/uploads', {'url': url});
  }
}
