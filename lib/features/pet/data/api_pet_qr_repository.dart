import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/pet.dart';
import '../domain/pet_qr_code.dart';
import '../domain/pet_qr_repository.dart';

/// Regeneração do QR code pela API (RF19).
///
/// Com [firestore] (pets no Firestore, `USE_API_QR=true`), usa as rotas
/// `/legacy-pets/{id do documento}` e grava o novo `publicId` em
/// `Pets/{id}.qrPublicId`, que o stream do pet entrega à tela. Sem
/// [firestore] (`USE_API_PETS=true`), usa `/pets/{id}` e a própria API já é
/// a fonte do pet — a tela recarrega o pet depois.
///
/// A API só troca se o QR que mandamos (`expectedPublicId`) ainda for o
/// atual; se não for, responde 409 e aqui sincronizamos com o atual.
class ApiPetQrRepository implements PetQrRepository {
  ApiPetQrRepository({required ApiClient api, FirebaseFirestore? firestore})
      : _api = api,
        _firestore = firestore;

  final ApiClient _api;
  final FirebaseFirestore? _firestore;

  String _rota(Pet pet) =>
      _firestore == null ? '/pets/${pet.id}/qr' : '/legacy-pets/${pet.id}/qr';

  @override
  bool get suportaRegeneracao => true;

  @override
  Future<String> regenerar(Pet pet) async {
    final Map<String, dynamic> res;
    try {
      res = await _api.post(
        '${_rota(pet)}/rotation',
        {'expectedPublicId': publicIdDoQr(pet)},
      );
    } on ApiException catch (e) {
      final falha = _falhaDa(e);
      if (falha == QrFalha.conflito) {
        // Melhor esforço: se falhar, o próximo abrir do QR sincroniza.
        try {
          await sincronizar(pet);
        } catch (_) {}
      }
      throw QrRegeneracaoException(falha);
    }

    final novo = res['publicId'] as String;
    try {
      await _salvar(pet, novo);
    } catch (_) {
      throw const QrRegeneracaoException(QrFalha.naoSalvo);
    }
    return novo;
  }

  @override
  Future<void> sincronizar(Pet pet) async {
    final Map<String, dynamic> res;
    try {
      res = await _api.get(_rota(pet));
    } on ApiException catch (e) {
      throw QrRegeneracaoException(_falhaDa(e));
    }
    final atual = res['publicId'] as String?;
    if (atual == null || atual == publicIdDoQr(pet)) return;
    try {
      await _salvar(pet, atual);
    } catch (_) {
      throw const QrRegeneracaoException(QrFalha.naoSalvo);
    }
  }

  Future<void> _salvar(Pet pet, String publicId) async {
    final firestore = _firestore;
    if (firestore == null) return;
    await firestore.collection('Pets').doc(pet.id).update({
      'qrPublicId': publicId,
      'qrRegeneradoEm': FieldValue.serverTimestamp(),
    });
  }

  static QrFalha _falhaDa(ApiException e) {
    if (e.isNetwork) return QrFalha.semConexao;
    return switch (e.status) {
      404 => QrFalha.naoSincronizado,
      409 => QrFalha.conflito,
      429 => QrFalha.limite,
      _ => QrFalha.desconhecida,
    };
  }
}
