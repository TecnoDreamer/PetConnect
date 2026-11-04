import '../../../core/network/api_client.dart';
import '../domain/atividade_do_qr.dart';

/// Atividade do QR pela API (issue #37).
///
/// Com [porIdDoFirestore] (pets no Firestore, `USE_API_QR=true`), usa
/// `/legacy-pets/{id do documento}`, como a configuração da página pública.
/// Sem ele (`USE_API_PETS=true`), usa `/pets/{id}`.
class ApiAtividadeDoQrRepository implements AtividadeDoQrRepository {
  ApiAtividadeDoQrRepository({
    required ApiClient api,
    required bool porIdDoFirestore,
  })  : _api = api,
        _porIdDoFirestore = porIdDoFirestore;

  final ApiClient _api;
  final bool _porIdDoFirestore;

  @override
  Future<AtividadeDoQr> buscar(String petId) async {
    final rota = _porIdDoFirestore
        ? '/legacy-pets/$petId/qr-activity'
        : '/pets/$petId/qr-activity';
    return AtividadeDoQr.daApi(await _api.get(rota));
  }
}
