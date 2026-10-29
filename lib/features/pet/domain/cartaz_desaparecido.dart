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

/// Posição e zoom de uma foto dentro do espaço dela no cartaz. A foto
/// original não é alterada: o recorte é só de exibição.
class EnquadramentoFoto {
  const EnquadramentoFoto({this.x = 0, this.y = 0, this.zoom = 1});

  /// Ponto de ancoragem, de -1 (esquerda/topo) a 1 (direita/base), na escala
  /// de `Alignment`.
  final double x;
  final double y;

  /// De 1 (a foto só cobre o espaço) a [zoomMaximo].
  final double zoom;

  static const zoomMaximo = 3.0;
  static const centralizado = EnquadramentoFoto();

  EnquadramentoFoto ajustado({double? x, double? y, double? zoom}) =>
      EnquadramentoFoto(
        x: (x ?? this.x).clamp(-1.0, 1.0),
        y: (y ?? this.y).clamp(-1.0, 1.0),
        zoom: (zoom ?? this.zoom).clamp(1.0, zoomMaximo),
      );

  Map<String, Object> toJson() => {'x': x, 'y': y, 'zoom': zoom};

  static EnquadramentoFoto fromJson(Object? json) {
    if (json is! Map) return centralizado;
    double ler(String chave, double padrao) =>
        (json[chave] as num?)?.toDouble() ?? padrao;
    return centralizado.ajustado(
        x: ler('x', 0), y: ler('y', 0), zoom: ler('zoom', 1));
  }

  @override
  bool operator ==(Object other) =>
      other is EnquadramentoFoto &&
      other.x == x &&
      other.y == y &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(x, y, zoom);
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
  static const vistoPorUltimoEm = 50;
  static const desapareceuEm = 30;
  static const recompensa = 30;
  static const observacoes = 100;

  static const fotos = 3;
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
    this.vistoPorUltimoEm = '',
    this.desapareceuEm = '',
    this.recompensa = '',
    this.observacoes = '',
    this.contato,
    this.telefoneAutorizado,
  });

  /// Sempre [LimitesCartaz.fotos] posições, na ordem do cartaz.
  final List<EspacoDeFoto> espacos;

  /// Nulo enquanto o tutor não mexeu no campo: o editor então sugere um
  /// texto a partir do cadastro (ver [sugerirCaracteristicas]).
  final String? caracteristicas;
  final String vistoPorUltimoEm;
  final String desapareceuEm;
  final String recompensa;
  final String observacoes;

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
    String? vistoPorUltimoEm,
    String? desapareceuEm,
    String? recompensa,
    String? observacoes,
    OrigemDoContato? contato,
  }) =>
      RascunhoCartaz(
        espacos: espacos ?? this.espacos,
        caracteristicas: caracteristicas ?? this.caracteristicas,
        vistoPorUltimoEm: vistoPorUltimoEm ?? this.vistoPorUltimoEm,
        desapareceuEm: desapareceuEm ?? this.desapareceuEm,
        recompensa: recompensa ?? this.recompensa,
        observacoes: observacoes ?? this.observacoes,
        contato: contato ?? this.contato,
        telefoneAutorizado: telefoneAutorizado,
      );

  /// Autoriza [digitos] (ou retira a autorização, com nulo).
  RascunhoCartaz autorizarTelefone(String? digitos) => RascunhoCartaz(
        espacos: espacos,
        caracteristicas: caracteristicas,
        vistoPorUltimoEm: vistoPorUltimoEm,
        desapareceuEm: desapareceuEm,
        recompensa: recompensa,
        observacoes: observacoes,
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

  /// O que vai para o rascunho salvo no aparelho: textos, fotos que já
  /// estão no Cloudinary do pet e o enquadramento. Sem telefone, sem
  /// consentimento e sem fotos do celular.
  Map<String, Object?> toJson() => {
        'versao': 1,
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
        'vistoPorUltimoEm': vistoPorUltimoEm,
        'desapareceuEm': desapareceuEm,
        'recompensa': recompensa,
        'observacoes': observacoes,
        'contato': contato?.name,
      };

  /// Lê um rascunho salvo. Campos desconhecidos, tipos errados ou URLs que
  /// não são do Cloudinary viram vazio, em vez de erro: um rascunho
  /// corrompido nunca impede o tutor de abrir o editor.
  static RascunhoCartaz fromJson(Object? json) {
    if (json is! Map || json['versao'] != 1) return const RascunhoCartaz();
    String texto(String chave, int limite) {
      final valor = json[chave];
      if (valor is! String) return '';
      return valor.length > limite ? valor.substring(0, limite) : valor;
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
      vistoPorUltimoEm:
          texto('vistoPorUltimoEm', LimitesCartaz.vistoPorUltimoEm),
      desapareceuEm: texto('desapareceuEm', LimitesCartaz.desapareceuEm),
      recompensa: texto('recompensa', LimitesCartaz.recompensa),
      observacoes: texto('observacoes', LimitesCartaz.observacoes),
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

/// Sugestão de "Características" a partir do cadastro: sexo e porte, os
/// únicos dados físicos do pet além de espécie, raça e cor (que já têm
/// linha própria). Nunca vem de análise de imagem; o tutor revisa.
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
    required this.espacos,
    required this.telefone,
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
    final especieRaca = [pet.especie, pet.raca]
        .map(limpo)
        .where((s) => s.isNotEmpty)
        .join(' / ');
    final caracteristicas =
        limpo(rascunho.caracteristicas ?? sugerirCaracteristicas(pet));
    final campos = <CampoDoCartaz>[
      if (limpo(pet.nome).isNotEmpty) CampoDoCartaz('Nome', limpo(pet.nome)),
      if (especieRaca.isNotEmpty) CampoDoCartaz('Espécie/Raça', especieRaca),
      if (limpo(pet.cor).isNotEmpty) CampoDoCartaz('Cor', limpo(pet.cor)),
      if (caracteristicas.isNotEmpty)
        CampoDoCartaz('Características', caracteristicas),
      if (limpo(rascunho.vistoPorUltimoEm).isNotEmpty)
        CampoDoCartaz('Visto por último em', limpo(rascunho.vistoPorUltimoEm)),
      if (limpo(rascunho.desapareceuEm).isNotEmpty)
        CampoDoCartaz('Desapareceu em', limpo(rascunho.desapareceuEm)),
      if (limpo(rascunho.observacoes).isNotEmpty)
        CampoDoCartaz('Observações', limpo(rascunho.observacoes)),
      if (limpo(rascunho.recompensa).isNotEmpty)
        CampoDoCartaz('Recompensa', limpo(rascunho.recompensa)),
    ];
    return ConteudoCartaz(
      titulo: TituloCartaz.daEspecie(pet.especie),
      nome: limpo(pet.nome).toUpperCase(),
      campos: campos,
      espacos: rascunho.espacos,
      telefone: telefone == null ? null : formatarTelefoneDoCartaz(telefone),
    );
  }

  final TituloCartaz titulo;
  final String nome;
  final List<CampoDoCartaz> campos;
  final List<EspacoDeFoto> espacos;

  /// Já formatado; nulo sem telefone válido.
  final String? telefone;
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
