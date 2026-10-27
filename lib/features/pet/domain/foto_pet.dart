import 'dart:typed_data';

import '../../../core/utils/cloudinary_url.dart';

/// Uma foto da galeria de um pet (docs/features/galeria-fotos-pet.md).
///
/// Gravada em `Pets/{petId}/fotos/{id}`. O arquivo fica no Cloudinary; aqui
/// só os metadados. [publicId] é o identificador do arquivo no Cloudinary,
/// guardado à parte da URL para a exclusão não depender de interpretar a
/// URL.
class FotoPet {
  const FotoPet({
    required this.id,
    required this.petId,
    required this.userId,
    required this.url,
    required this.publicId,
    this.largura,
    this.altura,
    this.legenda,
    this.criadoEm,
  });

  final String id;

  /// Pet dono da foto. Igual ao id do documento pai; repetido para as
  /// regras conferirem que a foto não foi gravada no pet errado.
  final String petId;

  /// Tutor que publicou (Auth UID), conferido pelas regras.
  final String userId;

  /// URL original do Cloudinary. A interface usa [miniaturaUrl] e
  /// [ampliadaUrl], não esta.
  final String url;
  final String publicId;
  final int? largura;
  final int? altura;
  final String? legenda;

  /// Horário do servidor. Nulo só enquanto a gravação local ainda não foi
  /// confirmada.
  final DateTime? criadoEm;

  String get miniaturaUrl => miniaturaCloudinary(url) ?? url;
  String get ampliadaUrl => ampliadaCloudinary(url) ?? url;
}

/// Limites da galeria. Documentados em docs/features/galeria-fotos-pet.md;
/// [tamanhoMaximoBytes] e [tamanhoMaximoLegenda] também são conferidos nas
/// regras do Firestore (legenda) e pelo Cloudinary (arquivo).
abstract final class LimitesGaleria {
  /// Fotos por envio. O seletor do sistema já para neste número.
  static const fotosPorEnvio = 10;

  /// Maior lado da imagem enviada, em px. O seletor redimensiona antes do
  /// envio, sem mexer no arquivo do aparelho.
  static const dimensaoMaxima = 2048.0;

  /// Qualidade JPEG usada pelo seletor ao redimensionar.
  static const qualidade = 85;

  /// Tamanho máximo por arquivo, depois de redimensionado (o limite de
  /// imagem do plano gratuito do Cloudinary é 10 MB).
  static const tamanhoMaximoBytes = 10 * 1024 * 1024;

  static const tamanhoMaximoLegenda = 300;

  /// Fotos por página da grade.
  static const porPagina = 30;
}

/// Formatos aceitos, reconhecidos pelo conteúdo do arquivo (assinatura dos
/// primeiros bytes), não pela extensão. O Cloudinary confere de novo no
/// envio, porque o upload vai para o endpoint de imagem.
enum FormatoImagem {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp'),
  heic('image/heic', 'heic');

  const FormatoImagem(this.mimeType, this.extensao);

  final String mimeType;
  final String extensao;

  static FormatoImagem? detectar(Uint8List bytes) {
    bool comeca(List<int> assinatura, [int inicio = 0]) {
      if (bytes.length < inicio + assinatura.length) return false;
      for (var i = 0; i < assinatura.length; i++) {
        if (bytes[inicio + i] != assinatura[i]) return false;
      }
      return true;
    }

    if (comeca(const [0xFF, 0xD8, 0xFF])) return jpeg;
    if (comeca(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return png;
    }
    // RIFF....WEBP
    if (comeca(const [0x52, 0x49, 0x46, 0x46]) &&
        comeca(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return webp;
    }
    // ....ftyp + marca HEIF/HEIC
    if (comeca(const [0x66, 0x74, 0x79, 0x70], 4) && bytes.length >= 12) {
      final marca = String.fromCharCodes(bytes.sublist(8, 12));
      const marcasHeif = {'heic', 'heix', 'hevc', 'heim', 'heis', 'mif1'};
      if (marcasHeif.contains(marca)) return heic;
    }
    return null;
  }
}

/// Por que uma imagem escolhida não pode ser enviada.
enum ProblemaImagem { formatoNaoSuportado, muitoGrande, vazia }

/// Confere uma imagem antes do envio. `null` quando está tudo certo.
ProblemaImagem? validarImagem(Uint8List bytes) {
  if (bytes.isEmpty) return ProblemaImagem.vazia;
  if (bytes.length > LimitesGaleria.tamanhoMaximoBytes) {
    return ProblemaImagem.muitoGrande;
  }
  if (FormatoImagem.detectar(bytes) == null) {
    return ProblemaImagem.formatoNaoSuportado;
  }
  return null;
}

String descreverProblemaImagem(ProblemaImagem problema) => switch (problema) {
      ProblemaImagem.formatoNaoSuportado =>
        'Formato não suportado. Use JPEG, PNG, WebP ou HEIC.',
      ProblemaImagem.muitoGrande => 'A imagem passa de 10 MB.',
      ProblemaImagem.vazia => 'Não foi possível ler a imagem.',
    };

/// Legenda pronta para gravar: sem espaços nas pontas e `null` se vazia.
String? normalizarLegenda(String? legenda) {
  final texto = legenda?.trim() ?? '';
  return texto.isEmpty ? null : texto;
}
