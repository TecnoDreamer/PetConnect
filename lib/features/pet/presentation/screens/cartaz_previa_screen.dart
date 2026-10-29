import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/exportacao_cartaz.dart';
import '../../domain/cartaz_desaparecido.dart';
import '../../domain/pet.dart';
import '../providers/cartaz_providers.dart';
import '../providers/pet_providers.dart';
import '../widgets/cartaz_procura_se.dart';

/// Prévia do cartaz de pet desaparecido e exportação
/// (docs/features/cartaz-pet-desaparecido.md). A prévia é o próprio widget
/// do cartaz, reduzido; o PNG é a captura desse mesmo widget em 2×, e o PDF
/// é esse PNG numa página A4. Nada sai do aparelho sem um toque do tutor.
class CartazPreviaScreen extends ConsumerWidget {
  const CartazPreviaScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final pet = ref.watch(petProvider(petId)).valueOrNull;
    final usuario = ref.watch(currentUsuarioProvider).valueOrNull;
    if (pet == null || usuario == null || pet.userId != usuario.id) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return _Previa(pet: pet, telefoneDoTutor: usuario.telefone);
  }
}

enum _Acao { compartilharImagem, salvarImagem, compartilharPdf }

class _Previa extends ConsumerStatefulWidget {
  const _Previa({required this.pet, required this.telefoneDoTutor});

  final Pet pet;
  final String telefoneDoTutor;

  @override
  ConsumerState<_Previa> createState() => _PreviaState();
}

class _PreviaState extends ConsumerState<_Previa> {
  final _cartaz = GlobalKey();
  _Acao? _exportando;

  /// Escala da captura: 1055 × 1491 lógicos viram 2110 × 2982 px.
  static const escalaDoPng = 2.0;

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  /// Espera as três fotos carregarem. Falso se alguma não carregar (sem
  /// internet, foto apagada da galeria): o cartaz nunca sai com um buraco.
  Future<bool> _carregarFotos(RascunhoCartaz rascunho) async {
    var todas = true;
    for (final espaco in rascunho.espacos) {
      final foto = espaco.foto;
      if (foto == null) return false;
      await precacheImage(imagemDoCartaz(foto), context,
          onError: (_, __) => todas = false);
      if (!mounted) return false;
    }
    return todas;
  }

  Future<Uint8List> _capturarPng() async {
    // Uma volta de quadro para as fotos recém-carregadas serem pintadas.
    await WidgetsBinding.instance.endOfFrame;
    final limite =
        _cartaz.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagem = await limite.toImage(pixelRatio: escalaDoPng);
    try {
      final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
      return dados!.buffer.asUint8List();
    } finally {
      imagem.dispose();
    }
  }

  Future<void> _exportar(_Acao acao, RascunhoCartaz rascunho) async {
    if (_exportando != null) return;
    setState(() => _exportando = acao);
    final destino = ref.read(destinoDoCartazProvider);
    final agora = DateTime.now();
    String nome(String extensao) => nomeDoArquivoDoCartaz(
        petId: widget.pet.id, data: agora, extensao: extensao);
    try {
      if (!await _carregarFotos(rascunho)) {
        if (mounted) {
          _avisar('Uma das fotos não carregou. Confira a internet ou troque '
              'a foto no editor.');
        }
        return;
      }
      if (!mounted) return;
      final png = await _capturarPng();
      switch (acao) {
        case _Acao.compartilharImagem:
          await destino.compartilhar(
              bytes: png, nomeDoArquivo: nome('png'), mimeType: 'image/png');
        case _Acao.compartilharPdf:
          final pdf = await gerarPdfDoCartaz(png);
          await destino.compartilhar(
              bytes: pdf,
              nomeDoArquivo: nome('pdf'),
              mimeType: 'application/pdf');
        case _Acao.salvarImagem:
          final arquivo = nome('png');
          await destino.salvarNaGaleria(
              png: png,
              nome: arquivo.substring(0, arquivo.length - '.png'.length));
          if (mounted) _avisar('Cartaz salvo na galeria de fotos.');
      }
    } on FalhaAoSalvarCartaz catch (e) {
      if (mounted) {
        _avisar(switch (e.motivo) {
          MotivoFalhaAoSalvar.semPermissao => 'Não foi possível salvar na '
              'galeria. Use "Compartilhar imagem" e escolha onde salvar.',
          MotivoFalhaAoSalvar.semEspaco =>
            'Não há espaço livre no celular para salvar o cartaz.',
          MotivoFalhaAoSalvar.outro =>
            'Não foi possível salvar o cartaz. Tente de novo.',
        });
      }
    } catch (_) {
      if (mounted) _avisar('Não foi possível gerar o cartaz. Tente de novo.');
    } finally {
      if (mounted) setState(() => _exportando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pet = widget.pet;
    final rascunho = ref.watch(cartazControllerProvider(pet.id));
    final telefone = telefoneEscolhido(
      rascunho: rascunho,
      contatos: contatosDisponiveis(
          telefoneDoTutor: widget.telefoneDoTutor, pet: pet),
    );
    final problemas = problemasDoCartaz(rascunho: rascunho, telefone: telefone);
    // O número só entra no cartaz depois de autorizado.
    final conteudo = ConteudoCartaz.de(
      pet: pet,
      rascunho: rascunho,
      telefone:
          problemas.contains(ProblemaCartaz.semConsentimento) ? null : telefone,
    );
    final pronto = problemas.isEmpty;

    Widget botao(_Acao acao, IconData icone, String rotulo,
        {bool principal = false}) {
      final carregando = _exportando == acao;
      final aoTocar = pronto && _exportando == null
          ? () => _exportar(acao, rascunho)
          : null;
      final icon = carregando
          ? const SizedBox.square(
              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icone);
      return principal
          ? FilledButton.icon(
              onPressed: aoTocar, icon: icon, label: Text(rotulo))
          : OutlinedButton.icon(
              onPressed: aoTocar, icon: icon, label: Text(rotulo));
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Prévia do cartaz')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Semantics(
                label: 'Prévia do cartaz Procura-se de ${pet.nome}. Use dois '
                    'dedos para ampliar.',
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FittedBox(
                        child: DecoratedBox(
                          decoration: BoxDecoration(boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 24),
                          ]),
                          child: RepaintBoundary(
                            key: _cartaz,
                            child: CartazProcuraSe(conteudo: conteudo),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!pronto) ...[
                    for (final problema in problemas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          problema.descricao(rascunho.fotosEscolhidas),
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Voltar e corrigir'),
                    ),
                  ] else
                    Text(
                      'Ao compartilhar, o cartaz sai do app e pode continuar '
                      'circulando: não dá para recolhê-lo depois.',
                      style: TextStyle(color: colors.textMuted, fontSize: 13),
                    ),
                  const SizedBox(height: 8),
                  botao(_Acao.compartilharImagem, Icons.share_outlined,
                      'Compartilhar imagem',
                      principal: true),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: botao(_Acao.salvarImagem,
                            Icons.download_outlined, 'Salvar imagem'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: botao(_Acao.compartilharPdf,
                            Icons.picture_as_pdf_outlined, 'Gerar PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
