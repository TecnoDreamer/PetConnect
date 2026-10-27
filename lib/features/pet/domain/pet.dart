/// Situação do pet (Memorial do Pet, ver docs/features/memorial-pet.md).
///
/// Gravada no Firestore como `situacao: 'ATIVO' | 'FALECIDO'`. Documentos
/// sem o campo — todos os pets anteriores ao Memorial — são tratados como
/// [ativo]: até esta versão não havia nenhuma forma de registrar
/// falecimento no app, então nenhum pet legado pode estar falecido.
enum SituacaoPet {
  ativo('ATIVO'),
  falecido('FALECIDO');

  const SituacaoPet(this.valor);

  final String valor;

  static SituacaoPet doBanco(Object? valor) =>
      valor == falecido.valor ? falecido : ativo;
}

/// Espelha a coleção `Pets` já existente no Firestore, com o campo
/// [vacinado] adicionado nesta fase (ver docs/modelo-dados-firestore.md).
///
/// [dono] é mantido por compatibilidade com documentos existentes, mas sua
/// função é redundante com [userId] — ainda não confirmada.
class Pet {
  const Pet({
    required this.id,
    required this.userId,
    required this.nome,
    required this.especie,
    required this.raca,
    required this.cor,
    required this.genero,
    required this.porte,
    required this.peso,
    required this.dataNascimento,
    required this.vacinado,
    this.dono,
    this.telefone,
    this.foto,
    this.capa,
    this.capaAlinhamentoY,
    this.qrCodeId,
    this.qrPublicId,
    this.situacao = SituacaoPet.ativo,
    this.dataFalecimento,
    this.homenagem,
  });

  final String id;
  final String userId;
  final String nome;
  final String especie;
  final String raca;
  final String cor;
  final String genero;
  final String porte;

  /// Armazenado como string no banco existente (ex: `"12kg"`), não número.
  final String peso;

  /// Formato `dd/MM/yyyy`, pode ser vazio.
  final String dataNascimento;

  final bool vacinado;
  final String? dono;

  /// Contato a exibir na página pública do QR code; se nulo, usa o
  /// telefone do usuário dono (Usuario.telefone).
  final String? telefone;

  final String? foto;

  /// Foto de capa do cabeçalho do perfil (fica atrás do avatar). Pets
  /// legados não têm — nula/vazia é o caso normal, tratado com fallback
  /// visual, nunca um erro.
  final String? capa;

  /// Alinhamento vertical da capa dentro do cabeçalho, de -1.0 (topo) a 1.0
  /// (base) — mesma escala do eixo Y de [Alignment]; nulo (ou 0.0) é o
  /// centro. Deixa o tutor escolher a área visível, em vez do recorte
  /// automático.
  final double? capaAlinhamentoY;

  /// Campo do app antigo, mantido só para não apagar o valor de documentos
  /// legados ao editar o pet. **Não** é usado no QR code: a API nunca
  /// reconheceu esse valor — o QR usa [qrPublicId].
  final String? qrCodeId;

  /// `publicId` atual do QR code (RF16/RF19), o mesmo que a API resolve na
  /// página pública. No modo Firestore só existe depois que o tutor regenera
  /// o QR; até lá, nulo, e o QR usa o id determinístico da migração (ver
  /// `publicIdDoQr`). Pela API, vem sempre preenchido.
  ///
  /// Fora de [toMap] de propósito: só `PetQrRepository` grava este campo,
  /// então salvar o formulário de edição com dados antigos nunca volta o QR
  /// para um id já revogado.
  final String? qrPublicId;

  final SituacaoPet situacao;

  /// Formato `dd/MM/yyyy`. Opcional — nunca é inventada quando o tutor não
  /// informa.
  final String? dataFalecimento;

  /// Texto livre e opcional do tutor exibido no memorial.
  final String? homenagem;

  bool get falecido => situacao == SituacaoPet.falecido;

  factory Pet.fromMap(String id, Map<String, dynamic> map) {
    return Pet(
      id: id,
      userId: map['userId'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      especie: map['especie'] as String? ?? '',
      raca: map['raca'] as String? ?? '',
      cor: map['cor'] as String? ?? '',
      genero: map['genero'] as String? ?? '',
      porte: map['porte'] as String? ?? '',
      peso: map['peso'] as String? ?? '',
      dataNascimento: map['dataNascimento'] as String? ?? '',
      vacinado: map['vacinado'] as bool? ?? false,
      dono: map['dono'] as String?,
      telefone: map['telefone'] as String?,
      foto: map['foto'] as String?,
      capa: map['capa'] as String?,
      capaAlinhamentoY: (map['capaAlinhamentoY'] as num?)?.toDouble(),
      qrCodeId: map['qrCodeId'] as String?,
      qrPublicId: map['qrPublicId'] as String?,
      situacao: SituacaoPet.doBanco(map['situacao']),
      dataFalecimento: map['dataFalecimento'] as String?,
      homenagem: map['homenagem'] as String?,
    );
  }

  /// Não inclui [situacao], [dataFalecimento] nem [homenagem]: esses campos
  /// só mudam por `PetRepository.alterarSituacao`, que registra auditoria.
  /// Assim, editar o perfil (`updatePet`) nunca altera a situação.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'nome': nome,
      'especie': especie,
      'raca': raca,
      'cor': cor,
      'genero': genero,
      'porte': porte,
      'peso': peso,
      'dataNascimento': dataNascimento,
      'vacinado': vacinado,
      'dono': dono,
      'telefone': telefone,
      'foto': foto,
      'capa': capa,
      'capaAlinhamentoY': capaAlinhamentoY,
      'qrCodeId': qrCodeId,
    };
  }

  Pet copyWith({
    String? nome,
    String? especie,
    String? raca,
    String? cor,
    String? genero,
    String? porte,
    String? peso,
    String? dataNascimento,
    bool? vacinado,
    String? dono,
    String? telefone,
    String? foto,
    String? capa,
    double? capaAlinhamentoY,
    String? qrCodeId,
  }) {
    return Pet(
      id: id,
      userId: userId,
      nome: nome ?? this.nome,
      especie: especie ?? this.especie,
      raca: raca ?? this.raca,
      cor: cor ?? this.cor,
      genero: genero ?? this.genero,
      porte: porte ?? this.porte,
      peso: peso ?? this.peso,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      vacinado: vacinado ?? this.vacinado,
      dono: dono ?? this.dono,
      telefone: telefone ?? this.telefone,
      foto: foto ?? this.foto,
      capa: capa ?? this.capa,
      capaAlinhamentoY: capaAlinhamentoY ?? this.capaAlinhamentoY,
      qrCodeId: qrCodeId ?? this.qrCodeId,
      qrPublicId: qrPublicId,
      situacao: situacao,
      dataFalecimento: dataFalecimento,
      homenagem: homenagem,
    );
  }
}
