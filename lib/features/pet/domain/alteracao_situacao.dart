import 'pet.dart';

/// Transição de [SituacaoPet] pedida pelo tutor (Memorial do Pet, ver
/// docs/features/memorial-pet.md). Só duas transições existem:
/// registrar o falecimento e corrigir uma marcação feita por engano.
class AlteracaoDeSituacao {
  const AlteracaoDeSituacao._({
    required this.nova,
    required this.motivo,
    this.dataFalecimento,
    this.homenagem,
  });

  /// [dataFalecimento] no formato `dd/MM/yyyy`; vazia ou nula = não
  /// informada.
  factory AlteracaoDeSituacao.registrarFalecimento({
    String? dataFalecimento,
    String? homenagem,
  }) =>
      AlteracaoDeSituacao._(
        nova: SituacaoPet.falecido,
        motivo: MotivoAlteracaoSituacao.registroFalecimento,
        dataFalecimento: _textoOuNulo(dataFalecimento),
        homenagem: _textoOuNulo(homenagem),
      );

  /// Volta o pet para [SituacaoPet.ativo]. Data e homenagem do falecimento
  /// são descartadas (a marcação estava errada); nenhum dado clínico é
  /// tocado.
  factory AlteracaoDeSituacao.corrigirMarcacao() => const AlteracaoDeSituacao._(
        nova: SituacaoPet.ativo,
        motivo: MotivoAlteracaoSituacao.correcaoMarcacao,
      );

  final SituacaoPet nova;
  final MotivoAlteracaoSituacao motivo;
  final String? dataFalecimento;
  final String? homenagem;

  static String? _textoOuNulo(String? texto) {
    final t = texto?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}

/// Motivo técnico gravado na auditoria da transição.
enum MotivoAlteracaoSituacao {
  registroFalecimento('registro_falecimento'),
  correcaoMarcacao('correcao_marcacao');

  const MotivoAlteracaoSituacao(this.valor);

  final String valor;
}

/// O pet não existe (ou não é visível para quem pediu a alteração).
class PetNaoEncontradoException implements Exception {
  const PetNaoEncontradoException();
}

/// A fonte de dados atual não permite registrar falecimento — ver
/// [PetRepository.suportaMemorial].
class MemorialNaoSuportadoException implements Exception {
  const MemorialNaoSuportadoException();
}
