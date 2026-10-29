import 'dart:typed_data';

import '../../../core/utils/cloudinary_url.dart';
import 'foto_pet.dart';
import 'pet.dart';

/// Cartaz "Procura-se" de um pet desaparecido
/// (docs/features/cartaz-pet-desaparecido.md).
///
/// O cartaz é montado no aparelho, a partir do cadastro do pet, do telefone
/// do tutor e do que o tutor escolhe no editor. Nada aqui é gravado no
/// Firestore nem enviado ao Cloudinary: não muda a situação do pet, a
/// galeria, o QR code nem os registros clínicos.

/// Linha de destaque abaixo do nome, derivada da espécie do cadastro. O
/// registro do pet não é alterado; só a leitura é normalizada.
enum TituloCartaz {
  gato('GATO DESAPARECIDO'),
  cachorro('CACHORRO DESAPARECIDO'),
  pet('PET DESAPARECIDO');

  const TituloCartaz(this.texto);

  final String texto;

  static const _gato = {
    'gato', 'gata', 'gatinho', 'gatinha', 'felino', 'felina', 'cat', //
  };
  static const _cachorro = {
    'cachorro', 'cachorra', 'cachorrinho', 'cachorrinha', 'cao', 'caes',
    'cadela', 'canino', 'canina', 'dog', //
  };

  /// Reconhece variações de grafia, acentos e maiúsculas ("Cão", "GATA",
  /// "cachorro srd"). Qualquer outra espécie (ou espécie vazia) fica com
  /// [pet]: o cartaz nunca chama um coelho de cachorro.
  static TituloCartaz daEspecie(String especie) {
    final palavras = semAcentos(especie.toLowerCase())
        .split(RegExp(r'[^a-z]+'))
        .where((p) => p.isNotEmpty);
    for (final palavra in palavras) {
      if (_gato.contains(palavra)) return gato;
      if (_cachorro.contains(palavra)) return cachorro;
    }
    return pet;
  }
}

String semAcentos(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final saida = StringBuffer();
  for (final rune in texto.runes) {
    final c = String.fromCharCode(rune);
    final i = de.indexOf(c);
    saida.write(i >= 0 ? para[i] : c);
  }
  return saida.toString();
}

/// Parte da foto que aparece no espaço, em frações da foto (0 a 1).
typedef AreaVisivel = ({
  double esquerda,
  double topo,
  double largura,
  double altura,
});

/// Como uma foto ocupa o espaço dela no cartaz. A foto original não é
/// alterada: o recorte é só de exibição.
///
/// Por padrão a foto preenche o espaço e as sobras são cortadas, mantendo o
/// ponto de foco ([focoX], [focoY]) no centro sempre que a foto permite.
/// Assim o recorte acompanha o espaço, que muda de formato conforme o texto
/// do cartaz. Com [inteira], a foto aparece toda, sem cortes.
class EnquadramentoFoto {
  const EnquadramentoFoto({
    this.focoX = 0.5,
    this.focoY = 0.5,
    this.zoom = 1,
    this.inteira = false,
  });

  /// Ponto de foco, em frações da foto: 0 é a borda esquerda (ou o topo) e
  /// 1, a direita (ou a base).
  final double focoX;
  final double focoY;

  /// De 1 (a foto só cobre o espaço) a [zoomMaximo].
  final double zoom;

  /// Foto inteira, sem cortes; o resto do espaço fica com um fundo
  /// desfocado da própria foto. Foco e zoom não se aplicam.
  final bool inteira;

  static const zoomMaximo = 3.0;
  static const centralizado = EnquadramentoFoto();

  EnquadramentoFoto ajustado({
    double? focoX,
    double? focoY,
    double? zoom,
    bool? inteira,
  }) =>
      EnquadramentoFoto(
        focoX: (focoX ?? this.focoX).clamp(0.0, 1.0),
        focoY: (focoY ?? this.focoY).clamp(0.0, 1.0),
        zoom: (zoom ?? this.zoom).clamp(1.0, zoomMaximo),
        inteira: inteira ?? this.inteira,
      );

  /// O que aparece de uma foto com a proporção (largura ÷ altura)
  /// [proporcaoDaFoto] num espaço de proporção [proporcaoDoEspaco], quando
  /// a foto preenche o espaço: o maior recorte com o formato do espaço,
  /// reduzido pelo zoom e centrado no foco, sem passar da borda da foto.
  AreaVisivel areaVisivel({
    required double proporcaoDaFoto,
    required double proporcaoDoEspaco,
  }) {
    final largura =
        (proporcaoDoEspaco / proporcaoDaFoto).clamp(0.0, 1.0) / zoom;
    final altura = (proporcaoDaFoto / proporcaoDoEspaco).clamp(0.0, 1.0) / zoom;
    return (
      esquerda: (focoX - largura / 2).clamp(0.0, 1 - largura),
      topo: (focoY - altura / 2).clamp(0.0, 1 - altura),
      largura: largura,
      altura: altura,
    );
  }

  Map<String, Object> toJson() =>
      {'focoX': focoX, 'focoY': focoY, 'zoom': zoom, 'inteira': inteira};

  static EnquadramentoFoto fromJson(Object? json) {
    if (json is! Map) return centralizado;
    double? ler(String chave) => (json[chave] as num?)?.toDouble();
    // Rascunho da versão 1: âncora de -1 a 1 (`x`, `y`), convertida para o
    // ponto de foco equivalente mais próximo.
    double? antigo(String chave) {
      final valor = ler(chave);
      return valor == null ? null : (valor + 1) / 2;
    }

    return centralizado.ajustado(
      focoX: ler('focoX') ?? antigo('x') ?? 0.5,
      focoY: ler('focoY') ?? antigo('y') ?? 0.5,
      zoom: ler('zoom') ?? 1,
      inteira: json['inteira'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EnquadramentoFoto &&
      other.focoX == focoX &&
      other.focoY == focoY &&
      other.zoom == zoom &&
      other.inteira == inteira;

  @override
  int get hashCode => Object.hash(focoX, focoY, zoom, inteira);
}

/// De onde veio uma foto do cartaz. Fotos da galeria e do perfil já estão
/// no Cloudinary do próprio pet; fotos do celular ficam só na memória e não
/// são enviadas a lugar nenhum.
sealed class FotoDoCartaz {
  const FotoDoCartaz();

  /// Fotos do celular não entram no rascunho salvo: o arquivo temporário
  /// do seletor pode sumir, e guardar uma cópia não é necessário.
  bool get persistivel => this is! FotoDoAparelho;
}

class FotoDaGaleria extends FotoDoCartaz {
  const FotoDaGaleria({required this.fotoId, required this.url});

  FotoDaGaleria.de(FotoPet foto) : this(fotoId: foto.id, url: foto.url);

  final String fotoId;

  /// URL original; o cartaz usa [ampliadaUrl].
  final String url;

  String get ampliadaUrl => ampliadaCloudinary(url) ?? url;

  @override
  bool operator ==(Object other) =>
      other is FotoDaGaleria && other.fotoId == fotoId && other.url == url;

  @override
  int get hashCode => Object.hash(fotoId, url);
}

class FotoDoPerfil extends FotoDoCartaz {
  const FotoDoPerfil(this.url);

  final String url;

  @override
  bool operator ==(Object other) => other is FotoDoPerfil && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

class FotoDoAparelho extends FotoDoCartaz {
  const FotoDoAparelho(this.bytes);

  final Uint8List bytes;
}

/// Uma das três posições de foto do cartaz.
class EspacoDeFoto {
  const EspacoDeFoto(
      {this.foto, this.enquadramento = EnquadramentoFoto.centralizado});

  final FotoDoCartaz? foto;
  final EnquadramentoFoto enquadramento;

  static const vazio = EspacoDeFoto();
}

/// Nomes das posições, na ordem do cartaz.
const nomesDosEspacos = ['Foto principal', 'Foto 2', 'Foto 3'];

/// Qual telefone vai no cartaz.
enum OrigemDoContato {
  /// `Usuario.telefone`, do cadastro do tutor.
  tutor,

  /// `Pet.telefone`, o contato do QR code do pet, quando o tutor cadastrou
  /// um diferente.
  pet,
}

/// Limites dos textos livres, escolhidos para caberem no cartaz sem cortar
/// nada (conferido nos testes com o texto mais longo permitido).
abstract final class LimitesCartaz {
  static const caracteristicas = 80;
  static const localVisto = 60;
  static const observacoes = 150;
  static const recompensaTexto = 30;

  /// R$ 999.999,99.
  static const recompensaEmCentavos = 99999999;

  /// Até quantos dias para trás o calendário de "Visto por último" vai.
  static const diasDoCalendario = 365;

  static const fotos = 3;
}

/// Cor do cabeçalho "PROCURA-SE" e do rodapé "CONTATO". Todas deixam o
/// texto branco legível (contraste acima de 5:1).
enum CorDoCartaz {
  preto('Preto', 0xFF111111),
  vermelho('Vermelho', 0xFFC62828),
  azul('Azul', 0xFF1565C0);

  const CorDoCartaz(this.nome, this.argb);

  final String nome;
  final int argb;
}

/// Período do dia em que o pet foi visto, quando o tutor não sabe o
/// horário exato.
enum PeriodoDoDia {
  madrugada('Madrugada', 'de madrugada'),
  manha('Manhã', 'de manhã'),
  tarde('Tarde', 'à tarde'),
  noite('Noite', 'à noite');

  const PeriodoDoDia(this.rotulo, this.noCartaz);

  final String rotulo;
  final String noCartaz;
}

/// Quando e onde o pet foi visto pela última vez: um campo só, para data e
/// local nunca se contradizerem. Tudo é opcional; o período e o horário
/// exato são alternativos.
class VistoPorUltimo {
  const VistoPorUltimo({
    this.data,
    this.periodo,
    this.horario,
    this.local = '',
  });

  /// Só o dia (sem hora).
  final DateTime? data;
  final PeriodoDoDia? periodo;

  /// Minutos desde a meia-noite.
  final int? horario;
  final String local;

  static const vazio = VistoPorUltimo();

  VistoPorUltimo comData(DateTime? data) => VistoPorUltimo(
        data: data == null ? null : DateTime(data.year, data.month, data.day),
        periodo: periodo,
        horario: horario,
        local: local,
      );

  /// Escolher um período tira o horário exato.
  VistoPorUltimo comPeriodo(PeriodoDoDia? periodo) =>
      VistoPorUltimo(data: data, periodo: periodo, local: local);

  /// Escolher um horário exato tira o período.
  VistoPorUltimo comHorario(int? horario) => VistoPorUltimo(
      data: data, horario: horario?.clamp(0, 24 * 60 - 1), local: local);

  VistoPorUltimo comLocal(String local) => VistoPorUltimo(
      data: data, periodo: periodo, horario: horario, local: local);

  /// Como aparece no cartaz: "29/10/2026, à tarde — Perto da praça".
  /// Vazio se nada foi preenchido.
  String get texto {
    final quando = [
      if (data != null) formatarDataDoCartaz(data!),
      if (periodo != null) periodo!.noCartaz,
      if (horario != null) 'às ${formatarHorarioDoCartaz(horario!)}',
    ].join(', ');
    final junto = [quando, local.trim()].where((p) => p.isNotEmpty).join(' — ');
    return junto.isEmpty ? '' : junto[0].toUpperCase() + junto.substring(1);
  }

  Map<String, Object?> toJson() => {
        'data': data == null
            ? null
            : '${data!.year.toString().padLeft(4, '0')}-'
                '${_dois(data!.month)}-${_dois(data!.day)}',
        'periodo': periodo?.name,
        'horario': horario,
        'local': local,
      };

  static VistoPorUltimo fromJson(Object? json) {
    if (json is! Map) return vazio;
    final data = json['data'] is String
        ? DateTime.tryParse(json['data'] as String)
        : null;
    final horario = json['horario'];
    final local = json['local'];
    final periodo =
        PeriodoDoDia.values.where((p) => p.name == json['periodo']).firstOrNull;
    return VistoPorUltimo(
      data: data == null ? null : DateTime(data.year, data.month, data.day),
      periodo: periodo,
      horario: periodo == null && horario is int && horario >= 0
          ? horario.clamp(0, 24 * 60 - 1)
          : null,
      local: local is String ? _cortar(local, LimitesCartaz.localVisto) : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VistoPorUltimo &&
      other.data == data &&
      other.periodo == periodo &&
      other.horario == horario &&
      other.local == local;

  @override
  int get hashCode => Object.hash(data, periodo, horario, local);
}

String _dois(int n) => n.toString().padLeft(2, '0');

String _cortar(String texto, int limite) =>
    texto.length > limite ? texto.substring(0, limite) : texto;

/// `29/10/2026`.
String formatarDataDoCartaz(DateTime data) =>
    '${_dois(data.day)}/${_dois(data.month)}/${data.year}';

/// `15h30`, ou `15h` na hora cheia.
String formatarHorarioDoCartaz(int minutos) {
  final hora = minutos ~/ 60;
  final minuto = minutos % 60;
  return minuto == 0 ? '${hora}h' : '${hora}h${_dois(minuto)}';
}

/// `1.234,56`: valor em reais com ponto no milhar e vírgula nos centavos.
String formatarValorEmReais(int centavos) {
  final reais = (centavos ~/ 100)
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');
  return '$reais,${_dois(centavos % 100)}';
}

/// `R$ 1.234,56`.
String formatarReais(int centavos) => 'R\$ ${formatarValorEmReais(centavos)}';

/// Lê um valor escrito à mão ("200", "R$ 1.500,00", "200 R$") em centavos.
/// Nulo se o texto não for só um valor em reais.
int? centavosDoTexto(String texto) {
  final limpo = texto.replaceAll(RegExp(r'R\$|\s'), '');
  final valor =
      RegExp(r'^(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?$').firstMatch(limpo);
  if (valor == null) return null;
  final reais = int.parse(valor.group(1)!.replaceAll('.', ''));
  final centavos = int.parse((valor.group(2) ?? '0').padRight(2, '0'));
  final total = reais * 100 + centavos;
  return total > 0 && total <= LimitesCartaz.recompensaEmCentavos
      ? total
      : null;
}

enum TipoRecompensa { dinheiro, outra }

/// Recompensa oferecida: um valor em reais ou um texto livre ("um
/// vale-presente"). Os dois ficam guardados; [tipo] escolhe qual vai no
/// cartaz.
class Recompensa {
  const Recompensa({
    this.tipo = TipoRecompensa.dinheiro,
    this.centavos,
    this.texto = '',
  });

  final TipoRecompensa tipo;
  final int? centavos;
  final String texto;

  static const nenhuma = Recompensa();

  Recompensa comTipo(TipoRecompensa tipo) =>
      Recompensa(tipo: tipo, centavos: centavos, texto: texto);

  /// Nulo ou zero: sem valor.
  Recompensa comCentavos(int? centavos) => Recompensa(
        tipo: tipo,
        centavos: centavos == null || centavos <= 0
            ? null
            : centavos.clamp(1, LimitesCartaz.recompensaEmCentavos),
        texto: texto,
      );

  Recompensa comTexto(String texto) =>
      Recompensa(tipo: tipo, centavos: centavos, texto: texto);

  /// Vazio: o cartaz não tem a linha "Recompensa".
  String get noCartaz => switch (tipo) {
        TipoRecompensa.dinheiro =>
          centavos == null ? '' : formatarReais(centavos!),
        TipoRecompensa.outra => texto.trim(),
      };

  Map<String, Object?> toJson() =>
      {'tipo': tipo.name, 'centavos': centavos, 'texto': texto};

  static Recompensa fromJson(Object? json) {
    if (json is! Map) return nenhuma;
    final centavos = json['centavos'];
    final texto = json['texto'];
    return Recompensa(
      tipo: TipoRecompensa.values
              .where((t) => t.name == json['tipo'])
              .firstOrNull ??
          TipoRecompensa.dinheiro,
      texto:
          texto is String ? _cortar(texto, LimitesCartaz.recompensaTexto) : '',
    ).comCentavos(centavos is int ? centavos : null);
  }

  /// Recompensa da versão 1 do rascunho, que era um texto livre: vira um
  /// valor em reais quando dá para ler, senão continua como texto.
  static Recompensa doTextoAntigo(String texto) {
    if (texto.trim().isEmpty) return nenhuma;
    final centavos = centavosDoTexto(texto);
    return centavos != null
        ? Recompensa(centavos: centavos)
        : Recompensa(
            tipo: TipoRecompensa.outra,
            texto: _cortar(texto.trim(), LimitesCartaz.recompensaTexto));
  }

  @override
  bool operator ==(Object other) =>
      other is Recompensa &&
      other.tipo == tipo &&
      other.centavos == centavos &&
      other.texto == texto;

  @override
  int get hashCode => Object.hash(tipo, centavos, texto);
}

/// O que o tutor escolheu no editor. O telefone não fica aqui: é lido do
/// cadastro na hora de montar o cartaz. O consentimento também não é
/// salvo: vale só para a sessão do editor em que foi dado
/// ([telefoneAutorizado]).
class RascunhoCartaz {
  const RascunhoCartaz({
    this.espacos = const [
      EspacoDeFoto.vazio,
      EspacoDeFoto.vazio,
      EspacoDeFoto.vazio
    ],
    this.caracteristicas,
    this.vistoPorUltimo = VistoPorUltimo.vazio,
    this.observacoes = '',
    this.recompensa = Recompensa.nenhuma,
    this.cor = CorDoCartaz.preto,
    this.contato,
    this.telefoneAutorizado,
  });

  /// Sempre [LimitesCartaz.fotos] posições, na ordem do cartaz.
  final List<EspacoDeFoto> espacos;

  /// Nulo enquanto o tutor não mexeu no campo: o editor então sugere um
  /// texto a partir do cadastro (ver [sugerirCaracteristicas]).
  final String? caracteristicas;
  final VistoPorUltimo vistoPorUltimo;
  final String observacoes;
  final Recompensa recompensa;
  final CorDoCartaz cor;

  /// Nulo: ainda não escolhido (o editor usa o primeiro disponível).
  final OrigemDoContato? contato;

  /// O número (só dígitos) que o tutor autorizou a mostrar no cartaz. O
  /// consentimento vale para esse número: se o telefone escolhido mudar, o
  /// cartaz volta a pedir a confirmação.
  final String? telefoneAutorizado;

  int get fotosEscolhidas => espacos.where((e) => e.foto != null).length;

  bool get temFotoDoAparelho => espacos.any((e) => e.foto is FotoDoAparelho);

  RascunhoCartaz copyWith({
    List<EspacoDeFoto>? espacos,
    String? caracteristicas,
    VistoPorUltimo? vistoPorUltimo,
    String? observacoes,
    Recompensa? recompensa,
    CorDoCartaz? cor,
    OrigemDoContato? contato,
  }) =>
      RascunhoCartaz(
        espacos: espacos ?? this.espacos,
        caracteristicas: caracteristicas ?? this.caracteristicas,
        vistoPorUltimo: vistoPorUltimo ?? this.vistoPorUltimo,
        observacoes: observacoes ?? this.observacoes,
        recompensa: recompensa ?? this.recompensa,
        cor: cor ?? this.cor,
        contato: contato ?? this.contato,
        telefoneAutorizado: telefoneAutorizado,
      );

  /// Autoriza [digitos] (ou retira a autorização, com nulo).
  RascunhoCartaz autorizarTelefone(String? digitos) => RascunhoCartaz(
        espacos: espacos,
        caracteristicas: caracteristicas,
        vistoPorUltimo: vistoPorUltimo,
        observacoes: observacoes,
        recompensa: recompensa,
        cor: cor,
        contato: contato,
        telefoneAutorizado: digitos,
      );

  RascunhoCartaz comEspaco(int indice, EspacoDeFoto espaco) {
    final novos = [...espacos];
    novos[indice] = espaco;
    return copyWith(espacos: novos);
  }

  /// Troca duas posições, levando o enquadramento junto com a foto.
  RascunhoCartaz trocarEspacos(int a, int b) {
    final novos = [...espacos];
    final temp = novos[a];
    novos[a] = novos[b];
    novos[b] = temp;
    return copyWith(espacos: novos);
  }

  /// O que vai para o rascunho salvo no aparelho: textos, data, fotos que
  /// já estão no Cloudinary do pet, o enquadramento e a cor. Sem telefone,
  /// sem consentimento e sem fotos do celular.
  Map<String, Object?> toJson() => {
        'versao': 2,
        'espacos': [
          for (final espaco in espacos)
            switch (espaco.foto) {
              FotoDaGaleria(:final fotoId, :final url) => {
                  'tipo': 'galeria',
                  'fotoId': fotoId,
                  'url': url,
                  'enquadramento': espaco.enquadramento.toJson(),
                },
              FotoDoPerfil(:final url) => {
                  'tipo': 'perfil',
                  'url': url,
                  'enquadramento': espaco.enquadramento.toJson(),
                },
              FotoDoAparelho() || null => null,
            },
        ],
        'caracteristicas': caracteristicas,
        'vistoPorUltimo': vistoPorUltimo.toJson(),
        'observacoes': observacoes,
        'recompensa': recompensa.toJson(),
        'cor': cor.name,
        'contato': contato?.name,
      };

  /// Lê um rascunho salvo. Campos desconhecidos, tipos errados ou URLs que
  /// não são do Cloudinary viram vazio, em vez de erro: um rascunho
  /// corrompido nunca impede o tutor de abrir o editor.
  ///
  /// A versão 1 (antes de "Visto por último" virar um campo só) é
  /// convertida: o local vem de `vistoPorUltimoEm`, a recompensa em texto
  /// vira valor em reais quando dá, e `desapareceuEm`, um texto livre sem
  /// data, fica de fora.
  static RascunhoCartaz fromJson(Object? json) {
    if (json is! Map) return const RascunhoCartaz();
    final versao = json['versao'];
    if (versao != 1 && versao != 2) return const RascunhoCartaz();
    String texto(String chave, int limite) {
      final valor = json[chave];
      return valor is String ? _cortar(valor, limite) : '';
    }

    final lidos = json['espacos'];
    final espacos = <EspacoDeFoto>[
      for (var i = 0; i < LimitesCartaz.fotos; i++)
        lidos is List && i < lidos.length
            ? _espacoDoJson(lidos[i])
            : EspacoDeFoto.vazio,
    ];
    final caracteristicas = json['caracteristicas'];
    return RascunhoCartaz(
      espacos: espacos,
      caracteristicas: caracteristicas is String
          ? texto('caracteristicas', LimitesCartaz.caracteristicas)
          : null,
      vistoPorUltimo: versao == 1
          ? VistoPorUltimo(
              local: texto('vistoPorUltimoEm', LimitesCartaz.localVisto))
          : VistoPorUltimo.fromJson(json['vistoPorUltimo']),
      observacoes: texto('observacoes', LimitesCartaz.observacoes),
      recompensa: versao == 1
          ? Recompensa.doTextoAntigo(texto('recompensa', 100))
          : Recompensa.fromJson(json['recompensa']),
      cor: CorDoCartaz.values.where((c) => c.name == json['cor']).firstOrNull ??
          CorDoCartaz.preto,
      contato: OrigemDoContato.values
          .where((o) => o.name == json['contato'])
          .firstOrNull,
    );
  }

  static EspacoDeFoto _espacoDoJson(Object? json) {
    if (json is! Map) return EspacoDeFoto.vazio;
    final url = json['url'];
    if (url is! String || !urlDoCloudinary(url)) return EspacoDeFoto.vazio;
    final enquadramento = EnquadramentoFoto.fromJson(json['enquadramento']);
    return switch (json['tipo']) {
      'galeria' when json['fotoId'] is String => EspacoDeFoto(
          foto: FotoDaGaleria(fotoId: json['fotoId'] as String, url: url),
          enquadramento: enquadramento),
      'perfil' =>
        EspacoDeFoto(foto: FotoDoPerfil(url), enquadramento: enquadramento),
      _ => EspacoDeFoto.vazio,
    };
  }
}

/// Só URLs https do Cloudinary entram no cartaz (fotos da galeria e do
/// perfil). Protege o rascunho salvo contra um endereço qualquer.
bool urlDoCloudinary(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'res.cloudinary.com';
}

/// Sugestão de "Características" a partir do cadastro: sexo e porte. A
/// espécie já está no título do cartaz; raça e cor ficam de fora, a pedido
/// do proprietário, e o tutor pode escrevê-las aqui. Nunca vem de análise
/// de imagem; o tutor revisa.
String sugerirCaracteristicas(Pet pet) {
  final partes = <String>[
    if (pet.genero.trim().isNotEmpty) pet.genero.trim(),
    if (pet.porte.trim().isNotEmpty) 'porte ${pet.porte.trim().toLowerCase()}',
  ];
  return partes.join(', ');
}

/// Telefone brasileiro só com dígitos, sem o código do país: 10 (fixo) ou
/// 11 (celular) dígitos. Nulo se não for um telefone válido — o cartaz
/// nunca mostra um número incompleto ou inventado.
String? telefoneDoCartaz(String? bruto) {
  if (bruto == null) return null;
  // Número de outro país: o cartaz só sabe formatar e conferir os do Brasil.
  final texto = bruto.trim();
  if (texto.startsWith('+') && !texto.startsWith('+55')) return null;
  var digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
  if ((digitos.length == 12 || digitos.length == 13) &&
      digitos.startsWith('55')) {
    digitos = digitos.substring(2);
  }
  if (digitos.length != 10 && digitos.length != 11) return null;
  // DDD brasileiro: dois dígitos de 1 a 9.
  if (digitos[0] == '0' || digitos[1] == '0') return null;
  return digitos;
}

/// `(11) 98765-4321` ou `(11) 3456-7890`, a partir de [telefoneDoCartaz]
/// (mesmo formato da máscara do cadastro).
String formatarTelefoneDoCartaz(String digitos) {
  final ddd = digitos.substring(0, 2);
  final numero = digitos.substring(2);
  final meio = numero.length - 4;
  return '($ddd) ${numero.substring(0, meio)}-${numero.substring(meio)}';
}

/// Telefones que o tutor pode escolher, já validados. O do pet só aparece
/// se for diferente do do tutor.
Map<OrigemDoContato, String> contatosDisponiveis({
  required String telefoneDoTutor,
  required Pet pet,
}) {
  final doTutor = telefoneDoCartaz(telefoneDoTutor);
  final doPet = telefoneDoCartaz(pet.telefone);
  return {
    if (doTutor != null) OrigemDoContato.tutor: doTutor,
    if (doPet != null && doPet != doTutor) OrigemDoContato.pet: doPet,
  };
}

/// Origem efetiva do contato: a escolhida, se ainda disponível; senão a
/// primeira de [contatos] (o telefone do tutor, quando válido).
OrigemDoContato? origemEscolhida({
  required RascunhoCartaz rascunho,
  required Map<OrigemDoContato, String> contatos,
}) =>
    contatos.containsKey(rascunho.contato)
        ? rascunho.contato
        : contatos.keys.firstOrNull;

/// Número escolhido (só dígitos), ou nulo sem telefone válido.
String? telefoneEscolhido({
  required RascunhoCartaz rascunho,
  required Map<OrigemDoContato, String> contatos,
}) =>
    contatos[origemEscolhida(rascunho: rascunho, contatos: contatos)];

/// Por que o cartaz ainda não pode ser exportado.
enum ProblemaCartaz {
  faltamFotos,
  semTelefone,
  semConsentimento;

  String descricao(int fotosEscolhidas) => switch (this) {
        faltamFotos => fotosEscolhidas == 2
            ? 'Falta 1 foto: o cartaz usa 3.'
            : 'Faltam ${LimitesCartaz.fotos - fotosEscolhidas} fotos: o '
                'cartaz usa 3.',
        semTelefone => 'Cadastre um telefone válido, com DDD, em Editar '
            'perfil.',
        semConsentimento => 'Confirme que o telefone pode aparecer no cartaz.',
      };
}

/// Um campo opcional preenchido, na ordem do cartaz.
class CampoDoCartaz {
  const CampoDoCartaz(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  @override
  bool operator ==(Object other) =>
      other is CampoDoCartaz && other.rotulo == rotulo && other.valor == valor;

  @override
  int get hashCode => Object.hash(rotulo, valor);

  @override
  String toString() => '$rotulo: $valor';
}

/// Tudo o que o cartaz mostra, já resolvido. Campos vazios simplesmente
/// não entram na lista, então o cartaz nunca tem rótulo sem conteúdo nem
/// "null".
class ConteudoCartaz {
  const ConteudoCartaz({
    required this.titulo,
    required this.nome,
    required this.campos,
    this.observacoes = '',
    required this.espacos,
    required this.telefone,
    this.cor = CorDoCartaz.preto,
  });

  /// Monta o conteúdo. [telefone] é o número escolhido, só com dígitos, ou
  /// nulo quando ainda não há um válido (a prévia mostra o espaço vazio e a
  /// exportação fica bloqueada).
  factory ConteudoCartaz.de({
    required Pet pet,
    required RascunhoCartaz rascunho,
    required String? telefone,
  }) {
    String limpo(String texto) => texto.trim();
    final caracteristicas =
        limpo(rascunho.caracteristicas ?? sugerirCaracteristicas(pet));
    final visto = rascunho.vistoPorUltimo.texto;
    final recompensa = rascunho.recompensa.noCartaz;
    final campos = <CampoDoCartaz>[
      if (limpo(pet.nome).isNotEmpty) CampoDoCartaz('Nome', limpo(pet.nome)),
      if (caracteristicas.isNotEmpty)
        CampoDoCartaz('Características', caracteristicas),
      if (visto.isNotEmpty) CampoDoCartaz('Visto por último', visto),
      if (recompensa.isNotEmpty) CampoDoCartaz('Recompensa', recompensa),
    ];
    return ConteudoCartaz(
      titulo: TituloCartaz.daEspecie(pet.especie),
      nome: limpo(pet.nome).toUpperCase(),
      campos: campos,
      observacoes: limpo(rascunho.observacoes),
      espacos: rascunho.espacos,
      telefone: telefone == null ? null : formatarTelefoneDoCartaz(telefone),
      cor: rascunho.cor,
    );
  }

  final TituloCartaz titulo;
  final String nome;

  /// As linhas de dados, na ordem do cartaz.
  final List<CampoDoCartaz> campos;

  /// Em destaque, numa caixa própria abaixo dos dados. Vazio: sem caixa.
  final String observacoes;
  final List<EspacoDeFoto> espacos;

  /// Já formatado; nulo sem telefone válido.
  final String? telefone;
  final CorDoCartaz cor;

  /// O mesmo cartaz com os espaços de foto vazios: serve para medir o
  /// formato de cada espaço sem carregar as fotos (o tamanho deles depende
  /// só do texto).
  ConteudoCartaz get semFotos => ConteudoCartaz(
        titulo: titulo,
        nome: nome,
        campos: campos,
        observacoes: observacoes,
        espacos: const [
          EspacoDeFoto.vazio,
          EspacoDeFoto.vazio,
          EspacoDeFoto.vazio
        ],
        telefone: telefone,
        cor: cor,
      );
}

/// O que impede a exportação. Lista vazia: pode exportar. [telefone] é o
/// número escolhido, só com dígitos.
List<ProblemaCartaz> problemasDoCartaz({
  required RascunhoCartaz rascunho,
  required String? telefone,
}) =>
    [
      if (rascunho.fotosEscolhidas < LimitesCartaz.fotos)
        ProblemaCartaz.faltamFotos,
      if (telefone == null) ProblemaCartaz.semTelefone,
      if (telefone != null && rascunho.telefoneAutorizado != telefone)
        ProblemaCartaz.semConsentimento,
    ];
