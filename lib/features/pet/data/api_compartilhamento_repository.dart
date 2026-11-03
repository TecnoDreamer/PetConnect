import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/compartilhamento_publico.dart';
import '../domain/pet.dart';

/// Configuração da página pública do QR pela API (issue #35).
///
/// Com [porIdDoFirestore] (pets no Firestore, `USE_API_QR=true`), usa
/// `/legacy-pets/{id do documento}`: a API lê o pet no Firestore para
/// conferir o dono, então funciona mesmo para pets que a migração ainda não
/// levou ao MongoDB. Sem ele (`USE_API_PETS=true`), usa `/pets/{id}`.
class ApiCompartilhamentoRepository implements CompartilhamentoRepository {
  ApiCompartilhamentoRepository({
    required ApiClient api,
    required bool porIdDoFirestore,
  })  : _api = api,
        _porIdDoFirestore = porIdDoFirestore;

  final ApiClient _api;
  final bool _porIdDoFirestore;

  String _rota(Pet pet) => _porIdDoFirestore
      ? '/legacy-pets/${pet.id}/public-sharing'
      : '/pets/${pet.id}/public-sharing';

  @override
  Future<CompartilhamentoPublico> buscar(Pet pet) =>
      _chamar(() => _api.get(_rota(pet)));

  @override
  Future<CompartilhamentoPublico> publicar(
          Pet pet, PedidoDeCompartilhamento pedido) =>
      _chamar(() => _api.put(_rota(pet), pedido.paraApi()));

  @override
  Future<CompartilhamentoPublico> revogar(Pet pet) =>
      _chamar(() => _api.put(_rota(pet), {'enabled': false}));

  Future<CompartilhamentoPublico> _chamar(
      Future<Map<String, dynamic>> Function() pedido) async {
    try {
      return CompartilhamentoPublico.daApi(await pedido());
    } on ApiException catch (e) {
      throw CompartilhamentoException(_falhaDa(e), e.message);
    }
  }

  static FalhaDoCompartilhamento _falhaDa(ApiException e) {
    if (e.isNetwork) return FalhaDoCompartilhamento.semConexao;
    return switch (e.status) {
      400 => FalhaDoCompartilhamento.dadosInvalidos,
      404 => FalhaDoCompartilhamento.petNaoEncontrado,
      409 when e.code == 'PET_IN_MEMORIAL' => FalhaDoCompartilhamento.memorial,
      409 when e.code == 'CONSENT_VERSION_OUTDATED' =>
        FalhaDoCompartilhamento.textoDesatualizado,
      503 => FalhaDoCompartilhamento.servidorIndisponivel,
      _ => FalhaDoCompartilhamento.desconhecida,
    };
  }
}
