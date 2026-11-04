import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../domain/aviso_do_qr.dart';

/// Avisos do QR na API (issue #36). O token do aparelho vai no corpo, nunca
/// na URL.
///
/// Com [porIdDoFirestore] (pets no Firestore, `USE_API_QR=true`), as
/// preferências usam `/legacy-pets/{id}`; sem ele, `/pets/{id}`.
class ApiAvisosRepository implements AvisosRepository {
  ApiAvisosRepository({required ApiClient api, required bool porIdDoFirestore})
      : _api = api,
        _porIdDoFirestore = porIdDoFirestore;

  final ApiClient _api;
  final bool _porIdDoFirestore;

  String _preferencias(String petId) => _porIdDoFirestore
      ? '/legacy-pets/$petId/notification-preferences'
      : '/pets/$petId/notification-preferences';

  @override
  Future<void> registrarAparelho(String token) => _api.put('/me/push-devices', {
        'token': token,
        'platform':
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });

  @override
  Future<void> removerAparelho(String token) =>
      _api.delete('/me/push-devices', {'token': token});

  @override
  Future<PreferenciasDeAviso> preferencias(String petId) async =>
      PreferenciasDeAviso.daApi(await _api.get(_preferencias(petId)));

  @override
  Future<PreferenciasDeAviso> salvarPreferencias(
          String petId, PreferenciasDeAviso preferencias) async =>
      PreferenciasDeAviso.daApi(
          await _api.put(_preferencias(petId), preferencias.paraApi()));
}
