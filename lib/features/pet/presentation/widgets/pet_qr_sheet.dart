import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../data/exportacao_cartaz.dart';
import '../../data/exportacao_qr.dart';
import '../../domain/pet.dart';
import '../../domain/pet_qr_code.dart';
import '../../domain/pet_qr_repository.dart';
import '../providers/cartaz_providers.dart';
import '../providers/pet_providers.dart';
import 'pet_qr_code.dart';

enum _Exportacao { baixar, compartilhar, pdf }

/// Conteúdo do bottom sheet "QR Code do Pet": o QR atual, a exportação para
/// imprimir na coleira (docs/features/qr-exportacao.md) e, quando a API
/// está configurada, a opção de gerar um novo (RF19, issue #29).
///
/// Observa [petProvider] em vez de usar só o [pet] recebido: depois de
/// regenerar, o QR exibido troca sem fechar o sheet. As mensagens ficam no
/// próprio sheet (não em SnackBar, que apareceria atrás dele).
class PetQrSheet extends ConsumerStatefulWidget {
  const PetQrSheet({super.key, required this.pet});

  final Pet pet;

  @override
  ConsumerState<PetQrSheet> createState() => _PetQrSheetState();
}

class _PetQrSheetState extends ConsumerState<PetQrSheet> {
  bool _ocupado = false;
  String? _mensagem;
  bool _mensagemDeErro = false;
  bool _podeVerificar = false;
  _Exportacao? _exportando;

  bool get _algoEmAndamento => _ocupado || _exportando != null;

  @override
  void initState() {
    super.initState();
    // Corrige em silêncio um QR trocado em outro aparelho — e já acorda o
    // servidor gratuito, que pode levar até ~2 min na primeira chamada.
    final repo = ref.read(petQrRepositoryProvider);
    if (repo.suportaRegeneracao) {
      repo.sincronizar(widget.pet).catchError((_) {});
    }
  }

  Pet get _petAtual =>
      ref.read(petProvider(widget.pet.id)).valueOrNull ?? widget.pet;

  Future<void> _confirmarERegenerar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerar um novo QR code?'),
        content: Text(
          'O QR code atual de ${widget.pet.nome} deixa de funcionar na hora, '
          'inclusive em coleiras e etiquetas já impressas. Quem escanear o '
          'código antigo não vai encontrar o pet. Depois, imprima o novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Gerar novo',
                style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
    if (confirmou != true || _algoEmAndamento || !mounted) return;

    await _executar(
      () => ref.read(petQrRepositoryProvider).regenerar(_petAtual),
      sucesso: 'Novo QR code ativo. O anterior não funciona mais — '
          'lembre de trocar a etiqueta da coleira.',
    );
  }

  Future<void> _verificar() => _executar(
        () => ref.read(petQrRepositoryProvider).sincronizar(_petAtual),
        sucesso: 'Pronto: este é o QR code atual.',
      );

  Future<void> _executar(
    Future<Object?> Function() acao, {
    required String sucesso,
  }) async {
    setState(() {
      _ocupado = true;
      _mensagem = null;
      _podeVerificar = false;
    });
    String mensagem = sucesso;
    var erro = false;
    var podeVerificar = false;
    try {
      await acao();
    } on QrRegeneracaoException catch (e) {
      erro = e.falha != QrFalha.conflito;
      podeVerificar =
          e.falha == QrFalha.semConexao || e.falha == QrFalha.naoSalvo;
      mensagem = _mensagemDa(e.falha);
    } catch (_) {
      erro = true;
      mensagem = _mensagemDa(QrFalha.desconhecida);
    }
    // Pela API (USE_API_PETS) o pet não é um stream: recarrega para o QR
    // novo aparecer. No Firestore o stream já entrega a mudança.
    ref.invalidate(petProvider(widget.pet.id));
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _mensagem = mensagem;
      _mensagemDeErro = erro;
      _podeVerificar = podeVerificar;
    });
  }

  /// Gera o arquivo do QR exibido agora e o entrega ao sistema. Salvar na
  /// galeria confirma com mensagem; compartilhar, não, porque o sistema nem
  /// sempre informa se o tutor enviou.
  Future<void> _exportar(_Exportacao acao) async {
    if (_algoEmAndamento) return;
    final pet = _petAtual;
    setState(() {
      _exportando = acao;
      _mensagem = null;
      _podeVerificar = false;
    });
    final destino = ref.read(destinoDoCartazProvider);
    final dados = publicPetUrl(pet);
    final agora = DateTime.now();
    String nome(String extensao) => nomeDoArquivoDoQr(
        publicId: publicIdDoQr(pet), data: agora, extensao: extensao);
    String? mensagem;
    var erro = false;
    try {
      switch (acao) {
        case _Exportacao.baixar:
          final png = await gerarPngDoQr(dados);
          final arquivo = nome('png');
          await destino.salvarNaGaleria(
              png: png,
              nome: arquivo.substring(0, arquivo.length - '.png'.length));
          mensagem = 'QR code salvo na galeria de fotos.';
        case _Exportacao.compartilhar:
          await destino.compartilhar(
              bytes: await gerarPngDoQr(dados),
              nomeDoArquivo: nome('png'),
              mimeType: 'image/png');
        case _Exportacao.pdf:
          await destino.compartilhar(
              bytes: await gerarPdfDoQr(dados: dados, nomeDoPet: pet.nome),
              nomeDoArquivo: nome('pdf'),
              mimeType: 'application/pdf');
      }
    } on FalhaAoSalvarCartaz catch (e) {
      erro = true;
      mensagem = switch (e.motivo) {
        MotivoFalhaAoSalvar.semPermissao => 'Não foi possível salvar na '
            'galeria. Use "Compartilhar" e escolha onde salvar.',
        MotivoFalhaAoSalvar.semEspaco =>
          'Não há espaço livre no celular para salvar o QR code.',
        MotivoFalhaAoSalvar.outro =>
          'Não foi possível salvar o QR code. Tente de novo.',
      };
    } catch (_) {
      erro = true;
      mensagem = 'Não foi possível gerar o arquivo do QR code. Tente de novo.';
    }
    if (!mounted) return;
    setState(() {
      _exportando = null;
      if (mensagem != null) {
        _mensagem = mensagem;
        _mensagemDeErro = erro;
      }
    });
  }

  static String _mensagemDa(QrFalha falha) => switch (falha) {
        QrFalha.conflito => 'Este QR code já tinha sido trocado, talvez em '
            'outro aparelho. Agora aparece o QR code atual.',
        QrFalha.limite => 'Você já gerou muitos QR codes novos para este pet '
            'hoje. Tente novamente amanhã.',
        QrFalha.naoSincronizado => 'Este pet ainda não está disponível no '
            'serviço do QR code. Tente novamente mais tarde.',
        QrFalha.semConexao => 'Não conseguimos confirmar com o servidor. '
            'Verifique sua internet e toque em "Verificar de novo".',
        QrFalha.naoSalvo => 'O novo QR code foi criado, mas não conseguimos '
            'salvá-lo neste aparelho. Toque em "Verificar de novo".',
        QrFalha.indisponivel || QrFalha.desconhecida => 'Não foi possível '
            'gerar um novo QR code agora. O QR code atual continua valendo.',
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pet = ref.watch(petProvider(widget.pet.id)).valueOrNull ?? widget.pet;
    final suporta = ref.watch(petQrRepositoryProvider).suportaRegeneracao;

    Widget icone(_Exportacao acao, IconData simbolo) => _exportando == acao
        ? const SizedBox.square(
            dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(simbolo);
    VoidCallback? aoTocar(_Exportacao acao) =>
        _algoEmAndamento ? null : () => _exportar(acao);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PetQrCode(pet: pet),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('qr-baixar'),
            onPressed: aoTocar(_Exportacao.baixar),
            icon: icone(_Exportacao.baixar, Icons.download_outlined),
            label: const Text('Baixar QR Code'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('qr-compartilhar'),
                  onPressed: aoTocar(_Exportacao.compartilhar),
                  icon: icone(_Exportacao.compartilhar, Icons.share_outlined),
                  label: const Text('Compartilhar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('qr-pdf'),
                  onPressed: aoTocar(_Exportacao.pdf),
                  icon: icone(_Exportacao.pdf, Icons.picture_as_pdf_outlined),
                  label: const Text('PDF para imprimir'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Para a coleira: imprima em preto sobre branco, com pelo menos '
            '2 cm de lado, e teste a leitura com a câmera do celular antes '
            'de usar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          if (_mensagem != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _mensagem!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mensagemDeErro ? colors.error : colors.success,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          if (suporta) ...[
            const SizedBox(height: 4),
            if (_podeVerificar)
              TextButton(
                onPressed: _algoEmAndamento ? null : _verificar,
                child: const Text('Verificar de novo'),
              ),
            TextButton.icon(
              onPressed: _algoEmAndamento ? null : _confirmarERegenerar,
              icon: _ocupado
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.autorenew, color: colors.textPrimary),
              label: Text('Gerar novo QR code',
                  style: TextStyle(color: colors.textPrimary)),
            ),
          ],
        ],
      ),
    );
  }
}
