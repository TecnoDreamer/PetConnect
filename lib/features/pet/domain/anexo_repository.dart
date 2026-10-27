import 'dart:typed_data';

/// Upload de anexos (RF24) ao Firebase Storage. Abstraído por bytes em vez
/// de `File`/`XFile` do image_picker para não acoplar a camada domain a um
/// plugin específico (ver docs/arquitetura.md) e continuar funcionando na
/// Web, onde `dart:io File` não existe.
abstract class AnexoRepository {
  /// Envia [bytes] para [path] no Storage e retorna a URL pública de
  /// download. Validação de tamanho/tipo é feita antes de chamar isto (ver
  /// docs/seguranca.md — "Validação de entrada").
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  });

  /// Remove um anexo pela URL de download (usado ao excluir um registro de
  /// histórico ou remover um anexo individual antes de salvar).
  Future<void> delete(String url);

  /// Envia uma imagem da galeria do pet. Diferente de [upload], vai para o
  /// endpoint de **imagem** do Cloudinary (que recusa o que não for imagem)
  /// e devolve também o `public_id` e as dimensões.
  ///
  /// [aoProgredir] recebe a fração enviada (0 a 1). Quando [cancelar]
  /// completa, o envio é interrompido e lança [EnvioCancelado].
  Future<ImagemEnviada> enviarImagem({
    required String nomeArquivo,
    required Uint8List bytes,
    void Function(double fracao)? aoProgredir,
    Future<void>? cancelar,
  });
}

/// Resultado de [AnexoRepository.enviarImagem].
class ImagemEnviada {
  const ImagemEnviada({
    required this.url,
    required this.publicId,
    this.largura,
    this.altura,
  });

  final String url;
  final String publicId;
  final int? largura;
  final int? altura;
}

/// O envio foi interrompido pelo tutor.
class EnvioCancelado implements Exception {
  const EnvioCancelado();
}
