/// URLs derivadas de uma imagem do Cloudinary (miniatura, versão ampliada).
///
/// Só transforma URLs que o próprio app grava: `https://res.cloudinary.com/
/// <conta>/image/upload/v<n>/<public_id>.<ext>`, sem transformação. Qualquer
/// outra URL volta `null` — quem chama decide o fallback —, para nunca
/// montar uma transformação sobre um endereço arbitrário.
///
/// A imagem entregue com transformação sai sem os metadados do arquivo
/// (EXIF, inclusive GPS): o Cloudinary os remove por padrão nas versões
/// transformadas. Por isso a galeria só exibe URLs derivadas.
library;

final _padrao = RegExp(
    r'^https://res\.cloudinary\.com/[A-Za-z0-9_-]+/image/upload/v\d+/[^?#]+$');

/// Insere [transformacao] logo depois de `/image/upload/`.
String? transformarImagemCloudinary(String url, String transformacao) {
  if (!_padrao.hasMatch(url)) return null;
  return url.replaceFirst('/image/upload/', '/image/upload/$transformacao/');
}

/// Quadrado para a grade, recortado no centro, no formato e qualidade
/// automáticos do Cloudinary (WebP/AVIF quando o aparelho aceita).
String? miniaturaCloudinary(String url, {int lado = 360}) =>
    transformarImagemCloudinary(url, 'c_fill,w_$lado,h_$lado,q_auto,f_auto');

/// Versão para o visualizador: no máximo [lado] px no maior eixo, sem
/// ampliar imagens menores (`c_limit`).
String? ampliadaCloudinary(String url, {int lado = 1600}) =>
    transformarImagemCloudinary(url, 'c_limit,w_$lado,h_$lado,q_auto,f_auto');
