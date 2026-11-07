import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Cliente HTTP fino para a API Spring do PetConnect.
///
/// - Prefixa `/api/v1` em todos os caminhos.
/// - Anexa `Authorization: Bearer <Firebase ID Token>` quando disponível.
/// - Converte o envelope de erro `{code, message}` em [ApiException].
/// - Falha de rede em GET, PUT e DELETE (que podem repetir sem efeito
///   colateral) ganha mais uma tentativa, numa conexão nova. POST e PATCH
///   nunca repetem: o servidor poderia ter recebido o primeiro envio.
///
/// No Android, a rede do app é cortada enquanto ele está em segundo plano. As
/// conexões que ficaram abertas morrem e a primeira chamada depois da volta
/// esperava até o tempo limite, mostrando "Sem conexão" com a internet boa.
/// Por isso a nova tentativa usa uma conexão nova, e o app chama
/// [descartarConexoesAntigas] quando volta ao primeiro plano.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required Future<String?> Function() getToken,
    http.Client? httpClient,
    http.Client Function()? criarCliente,
    Duration timeout = const Duration(seconds: 15),
    Duration pausaEntreTentativas = const Duration(milliseconds: 300),
  })  : _base = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _getToken = getToken,
        // Um cliente injetado (testes) é usado como está, sem ser trocado.
        _criarCliente =
            criarCliente ?? (httpClient == null ? http.Client.new : null),
        _timeout = timeout,
        _pausaEntreTentativas = pausaEntreTentativas {
    // Sem cliente injetado, [_criarCliente] sempre existe (o padrão ou o do
    // chamador).
    _conexao = _Conexao(httpClient ?? _criarCliente!());
  }

  final String _base;
  final Future<String?> Function() _getToken;
  final http.Client Function()? _criarCliente;
  final Duration _timeout;
  final Duration _pausaEntreTentativas;
  late _Conexao _conexao;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _send('PATCH', path, body);

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body);

  Future<void> delete(String path, [Map<String, dynamic>? body]) =>
      _send('DELETE', path, body);

  /// Troca as conexões abertas por novas. As chamadas em andamento terminam
  /// na conexão antiga, que só fecha depois delas.
  void descartarConexoesAntigas() => _renovar(_conexao);

  void _renovar(_Conexao antiga) {
    final criar = _criarCliente;
    if (criar == null) return;
    if (identical(antiga, _conexao)) _conexao = _Conexao(criar());
    antiga.aposentar();
  }

  static bool _podeRepetir(String method) =>
      method == 'GET' || method == 'PUT' || method == 'DELETE';

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

    final tentativas = _podeRepetir(method) ? 2 : 1;
    http.Response response;
    for (var tentativa = 1;; tentativa++) {
      final conexao = _conexao;
      conexao.ativas++;
      try {
        final request = http.Request(method, uri)..headers.addAll(headers);
        if (body != null) request.body = jsonEncode(body);
        final streamed = await conexao.cliente.send(request).timeout(_timeout);
        response = await http.Response.fromStream(streamed);
        if (tentativa > 1) {
          debugPrint('API: $method ${rotaParaLog(path)} deu certo na '
              'tentativa $tentativa.');
        }
        break;
      } catch (erro) {
        debugPrint('API: falha de rede em $method ${rotaParaLog(path)} '
            '(${erro.runtimeType}), tentativa $tentativa de $tentativas.');
        if (tentativa >= tentativas) {
          throw erro is TimeoutException
              ? const ApiException(
                  status: 0,
                  code: 'NETWORK',
                  message: 'Tempo de conexão esgotado. Verifique sua internet.',
                )
              : const ApiException(
                  status: 0,
                  code: 'NETWORK',
                  message: 'Não foi possível falar com o servidor.',
                );
        }
        _renovar(conexao);
        await Future<void>.delayed(_pausaEntreTentativas);
      } finally {
        conexao.liberar();
      }
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

  void close() => _conexao.aposentar();

  /// A rota para o log, sem identificadores: só os trechos fixos (letras
  /// minúsculas e hífen) ficam, e o resto vira `:id`. Nunca vai query, token
  /// nem corpo.
  @visibleForTesting
  static String rotaParaLog(String path) {
    final semQuery = path.split('?').first;
    return semQuery
        .split('/')
        .map((trecho) =>
            trecho.isEmpty || RegExp(r'^[a-z][a-z-]*$').hasMatch(trecho)
                ? trecho
                : ':id')
        .join('/');
  }
}

/// Um cliente HTTP com a contagem das chamadas que o usam. Depois de
/// aposentado, fecha assim que a última termina.
class _Conexao {
  _Conexao(this.cliente);

  final http.Client cliente;
  int ativas = 0;
  bool _aposentada = false;

  void liberar() {
    ativas--;
    if (_aposentada && ativas <= 0) cliente.close();
  }

  void aposentar() {
    _aposentada = true;
    if (ativas <= 0) cliente.close();
  }
}
