import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Exportação do cartaz de pet desaparecido
/// (docs/features/cartaz-pet-desaparecido.md, "Exportação").
///
/// O PNG é gerado na tela a partir do mesmo widget da prévia. Aqui ficam o
/// PDF (a mesma imagem numa página A4), o nome dos arquivos e a saída para
/// fora do app: folha de compartilhamento do sistema ou galeria de fotos.
/// Nada é enviado a servidor do PetConnect.

/// Nome seguro: sem nome do pet, telefone ou id interno. O identificador é
/// um resumo (SHA-256) do id do pet, para arquivos de pets diferentes não
/// se confundirem.
String nomeDoArquivoDoCartaz({
  required String petId,
  required DateTime data,
  required String extensao,
}) {
  final resumo = sha256.convert(utf8.encode(petId)).toString().substring(0, 8);
  String dois(int n) => n.toString().padLeft(2, '0');
  final dia = '${data.year}${dois(data.month)}${dois(data.day)}';
  return 'petconnect_procura-se_${resumo}_$dia.$extensao';
}

/// Página A4 em pé com o PNG do cartaz inteiro, centralizado, com margem.
/// Usar a mesma imagem garante que o PDF mostra exatamente a prévia. Em 2×
/// (2110 × 2982 px), dá cerca de 250 dpi na folha.
Future<Uint8List> gerarPdfDoCartaz(Uint8List png) async {
  final documento = pw.Document(title: 'Procura-se', creator: 'PetConnect');
  final imagem = pw.MemoryImage(png);
  documento.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(24),
    build: (_) => pw.Center(child: pw.Image(imagem, fit: pw.BoxFit.contain)),
  ));
  return documento.save();
}

/// Por que salvar na galeria não deu certo.
enum MotivoFalhaAoSalvar {
  /// Sem acesso à galeria. No Android 9 ou anterior o app não pede essa
  /// permissão (escrita no armazenamento); o tutor usa "Compartilhar".
  semPermissao,
  semEspaco,
  outro,
}

class FalhaAoSalvarCartaz implements Exception {
  const FalhaAoSalvarCartaz(this.motivo);

  final MotivoFalhaAoSalvar motivo;

  @override
  String toString() => 'FalhaAoSalvarCartaz($motivo)';
}

/// Para onde o cartaz vai. Trocável nos testes.
abstract class DestinoDoCartaz {
  /// Abre a folha de compartilhamento do sistema com o arquivo. `true` se o
  /// tutor escolheu um destino (ou o sistema não informa), `false` se ele
  /// fechou a folha.
  Future<bool> compartilhar({
    required Uint8List bytes,
    required String nomeDoArquivo,
    required String mimeType,
  });

  /// Salva o PNG na galeria de fotos do aparelho.
  Future<void> salvarNaGaleria({required Uint8List png, required String nome});
}

class DestinoDoCartazNoAparelho implements DestinoDoCartaz {
  const DestinoDoCartazNoAparelho();

  @override
  Future<bool> compartilhar({
    required Uint8List bytes,
    required String nomeDoArquivo,
    required String mimeType,
  }) async {
    // Arquivo próprio no cache, apagado logo depois: o share_plus copia para
    // a pasta dele (limpa a cada compartilhamento) antes de abrir a folha,
    // e a cópia original não fica esquecida no aparelho.
    final pasta = Directory(
        '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}'
        'cartaz');
    await pasta.create(recursive: true);
    final arquivo =
        File('${pasta.path}${Platform.pathSeparator}$nomeDoArquivo');
    try {
      await arquivo.writeAsBytes(bytes, flush: true);
      final resultado = await SharePlus.instance.share(ShareParams(
        files: [XFile(arquivo.path, mimeType: mimeType, name: nomeDoArquivo)],
      ));
      return resultado.status != ShareResultStatus.dismissed;
    } finally {
      if (await arquivo.exists()) await arquivo.delete();
    }
  }

  @override
  Future<void> salvarNaGaleria({
    required Uint8List png,
    required String nome,
  }) async {
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        throw const FalhaAoSalvarCartaz(MotivoFalhaAoSalvar.semPermissao);
      }
      await Gal.putImageBytes(png, name: nome);
    } on GalException catch (e) {
      throw FalhaAoSalvarCartaz(switch (e.type) {
        GalExceptionType.accessDenied => MotivoFalhaAoSalvar.semPermissao,
        GalExceptionType.notEnoughSpace => MotivoFalhaAoSalvar.semEspaco,
        _ => MotivoFalhaAoSalvar.outro,
      });
    }
  }
}
