import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Cliente HTTP fino para a API Spring do PetConnect.
///
/// - Prefixa `/api/v1` em todos os caminhos.
/// - Anexa `Authorization: Bearer <Firebase ID Token>` quando disponível.
/// - Converte o envelope de erro `{code, message}` em [ApiException].
class ApiClient {
  ApiClient({
    required String baseUrl,
    required Future<String?> Function() getToken,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
  })  : _base = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _getToken = getToken,
        _http = httpClient ?? http.Client(),
        _timeout = timeout;

  final String _base;
  final Future<String?> Function() _getToken;
  final http.Client _http;
  final Duration _timeout;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _send('PATCH', path, body);

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body);

  Future<void> delete(String path, [Map<String, dynamic>? body]) =>
      _send('DELETE', path, body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('$_base/api/v1$path');
    final token = await _getToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(
        status: 0,
        code: 'NETWORK',
        message: 'Tempo de conexão esgotado. Verifique sua internet.',
      );
    } catch (_) {
      throw const ApiException(
        status: 0,
        code: 'NETWORK',
        message: 'Não foi possível falar com o servidor.',
      );
    }

    final status = response.statusCode;
    final text = utf8.decode(response.bodyBytes);

    if (status >= 200 && status < 300) {
      if (text.isEmpty) return const {};
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }

    String code = 'UNKNOWN';
    String message = 'Erro inesperado (HTTP $status).';
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        code = decoded['code']?.toString() ?? code;
        message = decoded['message']?.toString() ?? message;
      }
    } catch (_) {
      // corpo não-JSON — mantém a mensagem genérica
    }
    throw ApiException(status: status, code: code, message: message);
  }

  void close() => _http.close();
}
