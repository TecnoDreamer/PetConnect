/// Cartão de Emergência do pet (issue #41): resumo privado, só do tutor, do
/// que um veterinário precisa saber numa urgência. Ver
/// docs/features/cartao-emergencia.md e a ADR 0009.
///
/// Gravado em `Pets/{petId}/emergencia/cartao`, um documento por pet. Nada
/// aqui vai para a página pública do QR nem para a API.
///
/// Regra de produto: dado ausente é **"Não informado"**, nunca "Não possui".
/// "Nenhuma conhecida" só aparece quando o tutor declarou isso.
library;

/// Limites de tamanho. Os mesmos valores estão em `firestore.rules` (o que
/// as regras conseguem conferir: listas, textos de primeiro nível).
abstract final class LimitesDoCartao {
  static const itensPorLista = 20;
  static const nomeCurto = 80;
  static const textoCurto = 120;
  static const textoMedio = 200;
  static const observacoes = 1000;
  static const tipoSanguineo = 40;
}

/// Situação de uma lista do cartão (alergias, medicamentos, condições).
///
/// Separa "ninguém disse nada" ([naoInformado]) de "o tutor disse que não
/// há" ([nenhumaDeclarada]).
enum SituacaoDaLista {
  naoInformado('NAO_INFORMADO'),
  nenhumaDeclarada('NENHUMA_DECLARADA'),
  informada('INFORMADA');

  const SituacaoDaLista(this.valor);

  final String valor;

  /// Valor desconhecido ou ausente vira [naoInformado]: nunca deduz que não
  /// há nada.
  static SituacaoDaLista doBanco(Object? valor) => SituacaoDaLista.values
      .firstWhere((s) => s.valor == valor, orElse: () => naoInformado);
}

class Alergia {
  const Alergia({
    required this.id,
    required this.substancia,
    this.reacao = '',
    this.observacao = '',
  });

  final String id;
  final String substancia;
  final String reacao;
  final String observacao;

  Map<String, dynamic> toMap() => {
        'id': id,
        'substancia': substancia,
        if (reacao.isNotEmpty) 'reacao': reacao,
        if (observacao.isNotEmpty) 'observacao': observacao,
      };

  static Alergia? fromMap(Object? bruto) {
    if (bruto is! Map) return null;
    final substancia = _texto(bruto['substancia']);
    if (substancia.isEmpty) return null;
    return Alergia(
      id: _texto(bruto['id']),
      substancia: substancia,
      reacao: _texto(bruto['reacao']),
      observacao: _texto(bruto['observacao']),
    );
  }
}

class Medicamento {
  const Medicamento({
    required this.id,
    required this.nome,
    this.dose = '',
    this.frequencia = '',
    this.via = '',
    this.observacao = '',
  });

  final String id;
  final String nome;

  /// Dose como o tutor escreveu, com a unidade ("5 mg", "meio comprimido").
  /// O app nunca sugere nem confere dose.
  final String dose;

  /// Frequência ou horário, como o tutor escreveu ("a cada 12 h").
  final String frequencia;

  /// Via de administração ("oral", "colírio").
  final String via;
  final String observacao;

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        if (dose.isNotEmpty) 'dose': dose,
        if (frequencia.isNotEmpty) 'frequencia': frequencia,
        if (via.isNotEmpty) 'via': via,
        if (observacao.isNotEmpty) 'observacao': observacao,
      };

  static Medicamento? fromMap(Object? bruto) {
    if (bruto is! Map) return null;
    final nome = _texto(bruto['nome']);
    if (nome.isEmpty) return null;
    return Medicamento(
      id: _texto(bruto['id']),
      nome: nome,
      dose: _texto(bruto['dose']),
      frequencia: _texto(bruto['frequencia']),
      via: _texto(bruto['via']),
      observacao: _texto(bruto['observacao']),
    );
  }
}

class VeterinarioDeConfianca {
  const VeterinarioDeConfianca({
    this.nome = '',
    this.clinica = '',
    this.telefone = '',
  });

  final String nome;
  final String clinica;

  /// Em E.164 (`+5519999990000`) ou vazio.
  final String telefone;

  bool get vazio => nome.isEmpty && clinica.isEmpty && telefone.isEmpty;

  Map<String, dynamic> toMap() => {
        if (nome.isNotEmpty) 'nome': nome,
        if (clinica.isNotEmpty) 'clinica': clinica,
        if (telefone.isNotEmpty) 'telefone': telefone,
      };

  static VeterinarioDeConfianca fromMap(Object? bruto) {
    if (bruto is! Map) return const VeterinarioDeConfianca();
    return VeterinarioDeConfianca(
      nome: _texto(bruto['nome']),
      clinica: _texto(bruto['clinica']),
      telefone: _texto(bruto['telefone']),
    );
  }
}

class CartaoEmergencia {
  const CartaoEmergencia({
    this.situacaoAlergias = SituacaoDaLista.naoInformado,
    this.alergias = const [],
    this.situacaoMedicamentos = SituacaoDaLista.naoInformado,
    this.medicamentos = const [],
    this.situacaoCondicoes = SituacaoDaLista.naoInformado,
    this.condicoes = const [],
    this.tipoSanguineo = '',
    this.tipoSanguineoConfirmado = false,
    this.observacoes = '',
    this.veterinario = const VeterinarioDeConfianca(),
    this.mostrarContatoDoTutor = true,
    this.atualizadoEm,
    this.revisao = 0,
  });

  /// Versão do formato gravado. Sobe só com mudança incompatível.
  static const versaoEsquema = 1;

  /// Cartão que ainda não existe no banco.
  static const vazio = CartaoEmergencia();

  final SituacaoDaLista situacaoAlergias;
  final List<Alergia> alergias;
  final SituacaoDaLista situacaoMedicamentos;
  final List<Medicamento> medicamentos;
  final SituacaoDaLista situacaoCondicoes;
  final List<String> condicoes;

  /// Texto livre, sem lista universal: os sistemas de cães e gatos são
  /// diferentes. Só é gravado com [tipoSanguineoConfirmado].
  final String tipoSanguineo;

  /// O tutor confirmou que o tipo veio de exame ou do veterinário.
  final bool tipoSanguineoConfirmado;

  final String observacoes;
  final VeterinarioDeConfianca veterinario;

  /// Mostra o telefone do perfil do tutor no cartão. O telefone não é
  /// copiado para o cartão.
  final bool mostrarContatoDoTutor;

  /// Horário do servidor da última gravação; nulo se nunca foi salvo.
  final DateTime? atualizadoEm;

  /// Contador de gravações (0 = nunca salvo). Evita sobrescrever, sem
  /// aviso, uma edição feita em outro aparelho.
  final int revisao;

  bool get nuncaSalvo => revisao == 0;

  /// Nada preenchido: só a tela de "Preencher cartão" faz sentido.
  bool get semDados =>
      situacaoAlergias == SituacaoDaLista.naoInformado &&
      situacaoMedicamentos == SituacaoDaLista.naoInformado &&
      situacaoCondicoes == SituacaoDaLista.naoInformado &&
      tipoSanguineo.isEmpty &&
      observacoes.isEmpty &&
      veterinario.vazio;

  /// Dados gravados no Firestore, sem `atualizadoEm` e `revisao`, que o
  /// repositório acrescenta na transação.
  Map<String, dynamic> toMap() => {
        'versaoEsquema': versaoEsquema,
        'situacaoAlergias': situacaoAlergias.valor,
        'alergias': [
          if (situacaoAlergias == SituacaoDaLista.informada)
            for (final a in alergias) a.toMap(),
        ],
        'situacaoMedicamentos': situacaoMedicamentos.valor,
        'medicamentos': [
          if (situacaoMedicamentos == SituacaoDaLista.informada)
            for (final m in medicamentos) m.toMap(),
        ],
        'situacaoCondicoes': situacaoCondicoes.valor,
        'condicoes': [
          if (situacaoCondicoes == SituacaoDaLista.informada) ...condicoes,
        ],
        'tipoSanguineo': tipoSanguineoConfirmado ? tipoSanguineo : '',
        'tipoSanguineoConfirmado':
            tipoSanguineoConfirmado && tipoSanguineo.isNotEmpty,
        'observacoes': observacoes,
        'veterinario': veterinario.toMap(),
        'mostrarContatoDoTutor': mostrarContatoDoTutor,
      };

  /// Lê o documento com tolerância: campo ausente, de outro tipo ou item
  /// malformado vira "Não informado" ou é ignorado, nunca um erro de tela.
  static CartaoEmergencia fromMap(
    Map<String, dynamic> dados, {
    DateTime? atualizadoEm,
  }) {
    List<T> lista<T>(Object? bruto, T? Function(Object?) ler) {
      if (bruto is! List) return const [];
      return bruto
          .take(LimitesDoCartao.itensPorLista)
          .map(ler)
          .whereType<T>()
          .toList();
    }

    final alergias = lista(dados['alergias'], Alergia.fromMap);
    final medicamentos = lista(dados['medicamentos'], Medicamento.fromMap);
    final condicoes = lista<String>(dados['condicoes'], (bruto) {
      final t = _texto(bruto);
      return t.isEmpty ? null : t;
    });
    final tipo = _texto(dados['tipoSanguineo']);
    final confirmado = dados['tipoSanguineoConfirmado'] == true;
    final revisao = dados['revisao'];

    return CartaoEmergencia(
      situacaoAlergias:
          _situacao(dados['situacaoAlergias'], alergias.isNotEmpty),
      alergias: alergias,
      situacaoMedicamentos:
          _situacao(dados['situacaoMedicamentos'], medicamentos.isNotEmpty),
      medicamentos: medicamentos,
      situacaoCondicoes:
          _situacao(dados['situacaoCondicoes'], condicoes.isNotEmpty),
      condicoes: condicoes,
      tipoSanguineo: confirmado ? tipo : '',
      tipoSanguineoConfirmado: confirmado && tipo.isNotEmpty,
      observacoes: _texto(dados['observacoes']),
      veterinario: VeterinarioDeConfianca.fromMap(dados['veterinario']),
      mostrarContatoDoTutor: dados['mostrarContatoDoTutor'] != false,
      atualizadoEm: atualizadoEm,
      revisao: revisao is int && revisao > 0 ? revisao : 0,
    );
  }

  /// "Informada" sem nenhum item válido não se sustenta: vira "Não
  /// informado".
  static SituacaoDaLista _situacao(Object? bruto, bool temItens) {
    final situacao = SituacaoDaLista.doBanco(bruto);
    if (situacao == SituacaoDaLista.informada && !temItens) {
      return SituacaoDaLista.naoInformado;
    }
    return situacao;
  }
}

String _texto(Object? valor) => valor is String ? valor.trim() : '';

/// Texto digitado, pronto para gravar: sem caracteres de controle (exceto a
/// quebra de linha, se [multilinha]), sem espaços nas pontas e cortado em
/// [maximo] caracteres.
String limparTexto(String bruto, int maximo, {bool multilinha = false}) {
  final controle = multilinha
      ? RegExp(r'[\u0000-\u0009\u000B-\u001F\u007F]')
      : RegExp(r'[\u0000-\u001F\u007F]');
  var texto = bruto.replaceAll('\r\n', '\n').replaceAll(controle, '').trim();
  if (texto.length > maximo) texto = texto.substring(0, maximo).trim();
  return texto;
}

/// Erros do cartão que a tela trata de forma diferente.
sealed class FalhaDoCartao implements Exception {
  const FalhaDoCartao();
}

/// Outra gravação aconteceu depois que o formulário abriu (outro aparelho,
/// por exemplo). Nada foi gravado.
final class CartaoAlteradoEmOutroLugar extends FalhaDoCartao {
  const CartaoAlteradoEmOutroLugar();
}

/// As regras negaram: pet de outro tutor, pet no Memorial ou sessão
/// expirada.
final class CartaoSemPermissao extends FalhaDoCartao {
  const CartaoSemPermissao();
}

/// Sem conexão com o Firestore. Nada foi gravado.
final class CartaoSemConexao extends FalhaDoCartao {
  const CartaoSemConexao();
}

/// Qualquer outra falha.
final class CartaoFalhaDesconhecida extends FalhaDoCartao {
  const CartaoFalhaDesconhecida();
}

/// O que a tela de leitura recebe: o cartão e de onde ele veio.
class LeituraDoCartao {
  const LeituraDoCartao({
    required this.cartao,
    required this.doCacheLocal,
    required this.existe,
  });

  final CartaoEmergencia cartao;

  /// Veio do cache do aparelho, sem confirmação do servidor.
  final bool doCacheLocal;

  /// O documento existe. Com [doCacheLocal] e sem documento, não dá para
  /// saber se o cartão está vazio ou só não foi baixado.
  final bool existe;
}
