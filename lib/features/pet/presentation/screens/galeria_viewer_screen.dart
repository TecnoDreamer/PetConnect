import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/br_date.dart';
import '../../domain/foto_pet.dart';
import '../providers/galeria_providers.dart';
import '../providers/pet_providers.dart';

/// Visualizador da galeria: uma foto por vez em tela cheia, deslizando para
/// os lados, com zoom por pinça. Lê a mesma lista da grade
/// ([galeriaControllerProvider]) e pede a próxima página ao chegar perto
/// do fim. Rota comum do [Navigator], como o [FullscreenImageViewer]: o
/// voltar do sistema fecha.
class GaleriaViewerScreen extends ConsumerStatefulWidget {
  const GaleriaViewerScreen({
    super.key,
    required this.petId,
    required this.indiceInicial,
  });

  final String petId;
  final int indiceInicial;

  static Future<void> abrir(
    BuildContext context, {
    required String petId,
    required int indiceInicial,
  }) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          GaleriaViewerScreen(petId: petId, indiceInicial: indiceInicial),
    ));
  }

  @override
  ConsumerState<GaleriaViewerScreen> createState() =>
      _GaleriaViewerScreenState();
}

class _GaleriaViewerScreenState extends ConsumerState<GaleriaViewerScreen> {
  late final PageController _paginas =
      PageController(initialPage: widget.indiceInicial);
  late int _indice = widget.indiceInicial;
  bool _comZoom = false;
  bool _excluindo = false;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _aoMudarDePagina(int indice, int total) {
    setState(() {
      _indice = indice;
      _comZoom = false;
    });
    if (indice >= total - 3) {
      ref.read(galeriaControllerProvider(widget.petId).notifier).carregarMais();
    }
  }

  Future<void> _excluir(FotoPet foto, String nomeDoPet) async {
    final colors = context.colors;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir esta foto?'),
        content: Text('A foto sai da galeria de $nomeDoPet e não pode ser '
            'recuperada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Excluir', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (confirmou != true || _excluindo || !mounted) return;

    setState(() => _excluindo = true);
    final mensageiro = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    try {
      await ref
          .read(galeriaControllerProvider(widget.petId).notifier)
          .excluir(foto);
      mensageiro.showSnackBar(const SnackBar(content: Text('Foto excluída.')));
      if (!mounted) return;
      final restantes =
          ref.read(galeriaControllerProvider(widget.petId)).fotos.length;
      if (restantes == 0) {
        navegador.pop();
      } else if (_indice >= restantes) {
        setState(() => _indice = restantes - 1);
      }
    } catch (_) {
      mensageiro.showSnackBar(const SnackBar(
        content: Text('Não foi possível excluir a foto. Verifique sua conexão '
            'e tente novamente.'),
      ));
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(galeriaControllerProvider(widget.petId));
    final nomeDoPet =
        ref.watch(petProvider(widget.petId)).valueOrNull?.nome ?? 'seu pet';
    final fotos = estado.fotos;
    final indice = fotos.isEmpty ? 0 : _indice.clamp(0, fotos.length - 1);
    final atual = fotos.isEmpty ? null : fotos[indice];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: fotos.isEmpty
            ? null
            : Text('${indice + 1} de ${fotos.length}'
                '${estado.temMais ? '+' : ''}'),
        actions: [
          if (atual != null)
            _excluindo
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    tooltip: 'Excluir foto',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _excluir(atual, nomeDoPet),
                  ),
        ],
      ),
      body: fotos.isEmpty
          ? const SizedBox.shrink()
          : Stack(
              children: [
                PageView.builder(
                  controller: _paginas,
                  physics: _comZoom
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: fotos.length,
                  onPageChanged: (i) => _aoMudarDePagina(i, fotos.length),
                  itemBuilder: (context, i) => _FotoAmpliada(
                    key: ValueKey(fotos[i].id),
                    foto: fotos[i],
                    descricao: 'Foto ${i + 1} de $nomeDoPet',
                    aoMudarZoom: (comZoom) {
                      if (comZoom != _comZoom) {
                        setState(() => _comZoom = comZoom);
                      }
                    },
                  ),
                ),
                if (atual != null) _Detalhes(foto: atual),
              ],
            ),
    );
  }
}

class _FotoAmpliada extends StatefulWidget {
  const _FotoAmpliada({
    super.key,
    required this.foto,
    required this.descricao,
    required this.aoMudarZoom,
  });

  final FotoPet foto;
  final String descricao;
  final ValueChanged<bool> aoMudarZoom;

  @override
  State<_FotoAmpliada> createState() => _FotoAmpliadaState();
}

class _FotoAmpliadaState extends State<_FotoAmpliada> {
  final _transformacao = TransformationController();
  // Muda para tentar carregar de novo depois de um erro.
  int _tentativa = 0;

  @override
  void dispose() {
    _transformacao.dispose();
    super.dispose();
  }

  void _aoTerminarGesto(ScaleEndDetails _) {
    widget.aoMudarZoom(_transformacao.value.getMaxScaleOnAxis() > 1.01);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: [
        widget.descricao,
        if (widget.foto.legenda != null) widget.foto.legenda!,
      ].join('. '),
      child: InteractiveViewer(
        transformationController: _transformacao,
        minScale: 1,
        maxScale: 4,
        onInteractionEnd: _aoTerminarGesto,
        child: Center(
          child: CachedNetworkImage(
            key: ValueKey('${widget.foto.id}-$_tentativa'),
            imageUrl: widget.foto.ampliadaUrl,
            fit: BoxFit.contain,
            // A miniatura já está no cache: aparece na hora, sem tela preta,
            // enquanto a versão maior carrega.
            placeholder: (context, _) => CachedNetworkImage(
              imageUrl: widget.foto.miniaturaUrl,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            errorWidget: (context, _, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 64),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await CachedNetworkImage.evictFromCache(
                        widget.foto.ampliadaUrl);
                    if (mounted) setState(() => _tentativa++);
                  },
                  child: const Text('Tentar de novo',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Detalhes extends StatelessWidget {
  const _Detalhes({required this.foto});

  final FotoPet foto;

  @override
  Widget build(BuildContext context) {
    final data = foto.criadoEm;
    final legenda = foto.legenda;
    if (data == null && legenda == null) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          color: Colors.black54,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (legenda != null)
                  Text(legenda,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15)),
                if (data != null) ...[
                  if (legenda != null) const SizedBox(height: 4),
                  Text('Publicada em ${formatBrDate(data.toLocal())}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
