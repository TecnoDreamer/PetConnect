import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/pet.dart';
import '../../domain/pet_qr_repository.dart';
import '../providers/pet_providers.dart';
import 'pet_qr_code.dart';

/// Conteúdo do bottom sheet "QR Code do Pet": o QR atual e, quando a API
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
    if (confirmou != true || _ocupado || !mounted) return;

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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PetQrCode(pet: pet),
          if (suporta) ...[
            const SizedBox(height: 12),
            if (_mensagem != null)
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
            if (_podeVerificar)
              TextButton(
                onPressed: _ocupado ? null : _verificar,
                child: const Text('Verificar de novo'),
              ),
            TextButton.icon(
              onPressed: _ocupado ? null : _confirmarERegenerar,
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
