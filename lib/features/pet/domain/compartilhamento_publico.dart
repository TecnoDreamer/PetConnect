import 'pet.dart';

/// Página pública do QR com consentimento (issue #35, fase 1 do épico #102).
/// Quem escaneia o QR vê só o que o tutor marcou aqui; sem consentimento, a
/// página mostra apenas que o pet está cadastrado e o formulário para avisar
/// o tutor. Ver docs/features/qr-compartilhamento-publico.md.

/// Versão do texto de [textoDoConsentimento]. Tem que ser a mesma da API
/// (`PublicSharingService.CONSENT_VERSION`): mudar o texto exige mudar as
/// duas, e publicações na versão antiga deixam de valer até o tutor aceitar
/// de novo.
const versaoDoConsentimento = '2026-11-02';

/// O que o tutor aceita ao marcar a caixa de consentimento.
String textoDoConsentimento(String nomeDoPet) =>
    'Autorizo mostrar os dados marcados acima na página pública do QR Code '
    'de $nomeDoPet. Qualquer pessoa com o QR ou o link pode ver esses dados. '
    'Se eu marcar o telefone, quem abrir a página verá o número. Posso '
    'desativar a página quando quiser.';

/// Dados que podem aparecer na página, um a um. [api] é o nome na API.
enum CampoPublico {
  nomePet('PET_NAME', 'Nome do pet'),
  especie('SPECIES', 'Espécie'),
  raca('BREED', 'Raça'),
  cor('COLOR', 'Cor'),
  fotoPerfil('PROFILE_PHOTO', 'Foto de perfil'),
  nomeTutor('TUTOR_NAME', 'Seu nome'),
  telefone('CONTACT_PHONE', 'Telefone ou WhatsApp');

  const CampoPublico(this.api, this.rotulo);

  final String api;
  final String rotulo;

  static CampoPublico? daApi(Object? valor) {
    for (final c in values) {
      if (c.api == valor) return c;
    }
    return null;
  }
}

/// A configuração salva na API.
class CompartilhamentoPublico {
  const CompartilhamentoPublico({
    required this.ativado,
    required this.ativo,
    required this.campos,
    this.nomeTutor,
    this.telefone,
    this.consentidoEm,
    this.revogadoEm,
    this.versaoAtual = versaoDoConsentimento,
  });

  /// O tutor deixou a página ligada.
  final bool ativado;

  /// A página está mostrando os dados agora: ligada, com consentimento na
  /// versão atual do texto e com ao menos um campo.
  final bool ativo;
  final Set<CampoPublico> campos;
  final String? nomeTutor;

  /// Em E.164.
  final String? telefone;
  final DateTime? consentidoEm;
  final DateTime? revogadoEm;

  /// Versão do texto que a API aceita hoje.
  final String versaoAtual;

  factory CompartilhamentoPublico.daApi(Map<String, dynamic> m) {
    DateTime? data(Object? v) =>
        v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final campos = <CampoPublico>{};
    for (final v in (m['fields'] as List?) ?? const []) {
      final campo = CampoPublico.daApi(v);
      if (campo != null) campos.add(campo);
    }
    return CompartilhamentoPublico(
      ativado: m['enabled'] == true,
      ativo: m['active'] == true,
      campos: campos,
      nomeTutor: m['tutorDisplayName'] as String?,
      telefone: m['contactPhone'] as String?,
      consentidoEm: data(m['consentAcceptedAt']),
      revogadoEm: data(m['consentRevokedAt']),
      versaoAtual:
          m['currentConsentVersion'] as String? ?? versaoDoConsentimento,
    );
  }
}

/// O que o tutor quer publicar. O consentimento é dado ao salvar: a tela só
/// chama [CompartilhamentoRepository.publicar] com a caixa marcada.
class PedidoDeCompartilhamento {
  const PedidoDeCompartilhamento({
    required this.campos,
    this.nomeTutor,
    this.telefone,
  });

  final Set<CampoPublico> campos;
  final String? nomeTutor;
  final String? telefone;

  Map<String, dynamic> paraApi() => {
        'enabled': true,
        'consentAccepted': true,
        'consentVersion': versaoDoConsentimento,
        'fields': [
          for (final c in CampoPublico.values)
            if (campos.contains(c)) c.api
        ],
        if (campos.contains(CampoPublico.nomeTutor))
          'tutorDisplayName': nomeTutor,
        if (campos.contains(CampoPublico.telefone)) 'contactPhone': telefone,
      };
}

abstract class CompartilhamentoRepository {
  Future<CompartilhamentoPublico> buscar(Pet pet);

  Future<CompartilhamentoPublico> publicar(
      Pet pet, PedidoDeCompartilhamento pedido);

  /// Desliga a página e revoga o consentimento. A API apaga o telefone e o
  /// nome de exibição.
  Future<CompartilhamentoPublico> revogar(Pet pet);
}

enum FalhaDoCompartilhamento {
  semConexao,

  /// A API não achou o pet ou ele é de outra conta.
  petNaoEncontrado,

  /// O texto do consentimento mudou; o app precisa ser atualizado.
  textoDesatualizado,

  /// Pet no Memorial não tem página pública.
  memorial,

  /// Algum dado recusado pela API (ex.: telefone).
  dadosInvalidos,

  /// A API não conseguiu confirmar o pet no Firestore agora.
  servidorIndisponivel,
  desconhecida,
}

class CompartilhamentoException implements Exception {
  const CompartilhamentoException(this.falha, [this.mensagemDaApi]);

  final FalhaDoCompartilhamento falha;
  final String? mensagemDaApi;

  String get mensagem => switch (falha) {
        FalhaDoCompartilhamento.semConexao =>
          'Sem conexão com o servidor. Verifique a internet e tente de novo. '
              'Na primeira vez do dia, o servidor pode levar até 2 minutos '
              'para responder.',
        FalhaDoCompartilhamento.petNaoEncontrado =>
          'Não foi possível encontrar este pet no servidor.',
        FalhaDoCompartilhamento.textoDesatualizado =>
          'O texto do consentimento mudou. Atualize o app para continuar.',
        FalhaDoCompartilhamento.memorial =>
          'Pets no Memorial não têm página pública.',
        FalhaDoCompartilhamento.dadosInvalidos =>
          mensagemDaApi ?? 'Confira os dados e tente de novo.',
        FalhaDoCompartilhamento.servidorIndisponivel =>
          'O servidor não conseguiu confirmar o pet agora. Tente de novo em '
              'instantes.',
        FalhaDoCompartilhamento.desconhecida =>
          'Não foi possível salvar agora. Tente de novo.',
      };

  @override
  String toString() => 'CompartilhamentoException($falha)';
}
