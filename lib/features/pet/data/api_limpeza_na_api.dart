import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/limpeza_na_api.dart';

/// [LimpezaNaApi] pela API Spring, com os pets no Firestore.
///
/// Os pedidos que não chegaram à API ficam em [SharedPreferences], por conta
/// (uid do Firebase), só com o id do documento do pet: nada de nome, foto ou
/// contato.
class ApiLimpezaNaApi implements LimpezaNaApi {
  ApiLimpezaNaApi({
    required ApiClient api,
    required SharedPreferences prefs,
    required String? Function() uidAtual,
    this.limite = const Duration(seconds: 8),
  })  : _api = api,
        _prefs = prefs,
        _uidAtual = uidAtual;

  final ApiClient _api;
  final SharedPreferences _prefs;
  final String? Function() _uidAtual;

  /// Prazo de cada pedido feito durante uma exclusão: o tutor está esperando.
  /// A API no Render pode levar perto de um minuto para acordar; nesse caso
  /// o pedido fica guardado e é repetido depois.
  final Duration limite;

  static String chave(String uid) => 'qr_limpeza_pendente_v1_$uid';

  @override
  Future<ResultadoDaLimpeza> antesDeExcluirPet(String petId,
      {bool guardarSeFalhar = true}) async {
    final resultado = await _apagar(petId, limite);
    if (resultado == ResultadoDaLimpeza.recusado) {
      // API anterior a esta rota: ao menos desliga a página pública, como o
      // app fazia antes (o telefone e o nome de exibição saem na hora).
      await _revogarPagina(petId);
    }
    final uid = _uidAtual();
    if (resultado == ResultadoDaLimpeza.apiInacessivel &&
        guardarSeFalhar &&
        uid != null) {
      await _guardar(uid, petId);
    }
    return resultado;
  }

  @override
  Future<void> retomarPendentes() async {
    final uid = _uidAtual();
    if (uid == null) return;
    final pendentes = _lerPendentes(uid);
    if (pendentes.isEmpty) return;

    final ficam = <String>[];
    for (final petId in pendentes) {
      // Sem a pressa da exclusão: o prazo do próprio cliente da API.
      final resultado = await _apagar(petId, null);
      if (resultado == ResultadoDaLimpeza.apiInacessivel) ficam.add(petId);
    }
    // Pedidos guardados enquanto esta retomada rodava também ficam.
    final atuais = _lerPendentes(uid);
    final restantes = {
      ...ficam,
      ...atuais.where((id) => !pendentes.contains(id)),
    }.toList();
    await _salvar(uid, restantes);
    debugPrint('Limpeza do QR: ${pendentes.length - ficam.length} pedido(s) '
        'guardado(s) concluído(s), ${restantes.length} pendente(s).');
  }

  @override
  Future<bool> excluirConta() async {
    final uid = _uidAtual();
    try {
      await _api.delete('/me').timeout(limite);
    } catch (e) {
      debugPrint('Limpeza na API: conta não excluída lá (${_tipoDa(e)}).');
      return false;
    }
    // A conta saiu da API: os pedidos guardados dela não servem mais.
    if (uid != null) await _prefs.remove(chave(uid));
    return true;
  }

  Future<ResultadoDaLimpeza> _apagar(String petId, Duration? prazo) async {
    try {
      final pedido = _api.delete('/legacy-pets/$petId/qr-data');
      await (prazo == null ? pedido : pedido.timeout(prazo));
      return ResultadoDaLimpeza.apagado;
    } on ApiException catch (e) {
      // Sem o id do pet no log.
      debugPrint('Limpeza do QR na API falhou (${e.status} ${e.code}).');
      return _vaiAdiantarRepetir(e)
          ? ResultadoDaLimpeza.apiInacessivel
          : ResultadoDaLimpeza.recusado;
    } catch (e) {
      debugPrint('Limpeza do QR na API falhou (${_tipoDa(e)}).');
      return ResultadoDaLimpeza.apiInacessivel;
    }
  }

  Future<void> _revogarPagina(String petId) async {
    try {
      await _api.put('/legacy-pets/$petId/public-sharing',
          {'enabled': false}).timeout(limite);
    } catch (_) {
      // Sem a página desligada aqui, a API apaga a configuração no próximo
      // acesso ao QR do pet excluído.
    }
  }

  /// Sem rede, tempo esgotado, servidor fora (5xx), sessão a renovar (401)
  /// ou limite de pedidos (429): vale tentar de novo depois.
  static bool _vaiAdiantarRepetir(ApiException e) =>
      e.isNetwork || e.status >= 500 || e.status == 401 || e.status == 429;

  static String _tipoDa(Object e) =>
      e is TimeoutException ? 'tempo esgotado' : e.runtimeType.toString();

  List<String> _lerPendentes(String uid) =>
      _prefs.getStringList(chave(uid)) ?? const [];

  Future<void> _guardar(String uid, String petId) async {
    final lista = _lerPendentes(uid);
    if (lista.contains(petId)) return;
    await _salvar(uid, [...lista, petId]);
  }

  Future<void> _salvar(String uid, List<String> lista) => lista.isEmpty
      ? _prefs.remove(chave(uid))
      : _prefs.setStringList(chave(uid), lista);
}
