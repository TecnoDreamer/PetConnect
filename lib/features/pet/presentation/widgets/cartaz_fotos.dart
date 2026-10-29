import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/cloudinary_url.dart';
import '../../domain/cartaz_desaparecido.dart';
import '../../domain/foto_pet.dart';
import '../../domain/pet.dart';
import '../providers/galeria_providers.dart';
import 'cartaz_procura_se.dart';

/// Escolha e enquadramento das fotos do cartaz de pet desaparecido
/// (docs/features/cartaz-pet-desaparecido.md, "Fotos").

/// Miniatura de uma foto do cartaz, decodificada em [lado] px.
ImageProvider miniaturaDoCartaz(FotoDoCartaz foto, int lado) {
  final ImageProvider original = switch (foto) {
    FotoDaGaleria(:final url) ||
    FotoDoPerfil(:final url) =>
      CachedNetworkImageProvider(miniaturaCloudinary(url) ?? url),
    FotoDoAparelho(:final bytes) => MemoryImage(bytes),
  };
  return ResizeImage(original, width: lado, policy: ResizeImagePolicy.fit);
}

/// Abre a escolha de uma foto: galeria do pet (se ligada), foto do perfil
/// ou uma foto do celular. Fotos em [emUso] (já em outra posição) aparecem
/// marcadas e não podem ser escolhidas de novo. Nulo se o tutor fechar.
Future<FotoDoCartaz?> escolherFotoDoCartaz(
  BuildContext context, {
  required Pet pet,
  required Set<FotoDoCartaz> emUso,
}) =>
    showModalBottomSheet<FotoDoCartaz>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _SeletorDeFoto(pet: pet, emUso: emUso),
    );

class _SeletorDeFoto extends ConsumerStatefulWidget {
  const _SeletorDeFoto({required this.pet, required this.emUso});

  final Pet pet;
  final Set<FotoDoCartaz> emUso;

  @override
  ConsumerState<_SeletorDeFoto> createState() => _SeletorDeFotoState();
}

class _SeletorDeFotoState extends ConsumerState<_SeletorDeFoto> {
  String? _erro;
  bool _abrindoCelular = false;

  /// Usa o seletor do sistema, que não pede acesso a todas as fotos. Ele
  /// devolve uma cópia redimensionada e recomprimida (orientação corrigida,
  /// sem os metadados do original); o arquivo do aparelho não muda.
  Future<void> _escolherDoCelular() async {
    setState(() {
      _abrindoCelular = true;
      _erro = null;
    });
    try {
      final arquivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: LimitesGaleria.dimensaoMaxima,
        maxHeight: LimitesGaleria.dimensaoMaxima,
        imageQuality: LimitesGaleria.qualidade,
        requestFullMetadata: false,
      );
      if (arquivo == null || !mounted) return;
      final bytes = await arquivo.readAsBytes();
      final problema = validarImagem(bytes);
      if (!mounted) return;
      if (problema != null) {
        setState(() => _erro = descreverProblemaImagem(problema));
        return;
      }
      Navigator.of(context).pop(FotoDoAparelho(bytes));
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível abrir suas fotos. Confira '
            'se o PetConnect pode acessar as fotos do celular.');
      }
    } finally {
      if (mounted) setState(() => _abrindoCelular = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pet = widget.pet;
    final galeriaLigada = ref.watch(galeriaDisponivelProvider);
    final foto = pet.foto;
    final fotoDoPerfil =
        foto != null && urlDoCloudinary(foto) ? FotoDoPerfil(foto) : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, rolagem) => CustomScrollView(
        controller: rolagem,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            sliver: SliverList.list(children: [
              Text('Escolher foto',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _abrindoCelular ? null : _escolherDoCelular,
                icon: _abrindoCelular
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.smartphone_outlined),
                label: const Text('Escolher do celular'),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 8),
                Text(_erro!,
                    key: const ValueKey('cartaz-erro-foto'),
                    style: TextStyle(color: colors.error)),
              ],
              Text(
                'A foto do celular fica só neste aparelho e não é enviada '
                'ao PetConnect.',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
              if (fotoDoPerfil != null) ...[
                const SizedBox(height: 20),
                Text('Foto do perfil',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox.square(
                    dimension: 104,
                    child: _OpcaoDeFoto(
                      foto: fotoDoPerfil,
                      descricao: 'Foto do perfil de ${pet.nome}',
                      emUso: widget.emUso.contains(fotoDoPerfil),
                    ),
                  ),
                ),
              ],
              if (galeriaLigada) ...[
                const SizedBox(height: 20),
                Text('Galeria de ${pet.nome}',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
              ],
            ]),
          ),
          if (galeriaLigada) _GradeDaGaleria(pet: pet, emUso: widget.emUso),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _GradeDaGaleria extends ConsumerWidget {
  const _GradeDaGaleria({required this.pet, required this.emUso});

  final Pet pet;
  final Set<FotoDoCartaz> emUso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final estado = ref.watch(galeriaControllerProvider(pet.id));
    final controller = ref.read(galeriaControllerProvider(pet.id).notifier);

    Widget aviso(Widget filho) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(child: filho),
        );

    if (estado.carregando) {
      return aviso(const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ));
    }
    if (estado.fotos.isEmpty) {
      return aviso(estado.erro
          ? Row(children: [
              Expanded(
                child: Text('Não foi possível carregar as fotos.',
                    style: TextStyle(color: colors.error)),
              ),
              TextButton(
                  onPressed: controller.recarregar,
                  child: const Text('Tentar de novo')),
            ])
          : Text('A galeria de ${pet.nome} ainda não tem fotos.',
              style: TextStyle(color: colors.textMuted)));
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverMainAxisGroup(slivers: [
        SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4),
          itemCount: estado.fotos.length,
          itemBuilder: (context, i) {
            final foto = FotoDaGaleria.de(estado.fotos[i]);
            return _OpcaoDeFoto(
              foto: foto,
              descricao: 'Foto ${i + 1} de ${pet.nome}',
              emUso: emUso.contains(foto),
            );
          },
        ),
        if (estado.temMais || estado.erro)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: estado.carregandoMais
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: controller.carregarMais,
                        child: Text(estado.erro
                            ? 'Não carregou. Tentar de novo'
                            : 'Carregar mais fotos'),
                      ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _OpcaoDeFoto extends StatelessWidget {
  const _OpcaoDeFoto({
    required this.foto,
    required this.descricao,
    required this.emUso,
  });

  final FotoDoCartaz foto;
  final String descricao;
  final bool emUso;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lado = (120 * MediaQuery.devicePixelRatioOf(context)).round();
    return Semantics(
      button: true,
      enabled: !emUso,
      label: emUso ? '$descricao. Já está no cartaz.' : descricao,
      excludeSemantics: true,
      child: Material(
        color: colors.cardBackground,
        child: InkWell(
          onTap: emUso ? null : () => Navigator.of(context).pop(foto),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: miniaturaDoCartaz(foto, lado),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.broken_image_outlined, color: colors.textMuted),
              ),
              if (emUso)
                ColoredBox(
                  color: Colors.black54,
                  child: Icon(Icons.check_circle,
                      color: colors.textOnBrand, size: 32),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ajuste de uma foto do cartaz. O tutor escolhe se ela preenche o espaço
/// (as sobras são cortadas) ou aparece inteira. Preenchendo, toca (ou
/// arrasta) no ponto de foco, que fica no centro do espaço, e pode dar
/// zoom. A prévia tem o formato exato do espaço no cartaz como ele está
/// agora; os controles deslizantes fazem o mesmo sem gesto (leitor de tela,
/// teclado).
class EnquadramentoScreen extends StatefulWidget {
  const EnquadramentoScreen({
    super.key,
    required this.foto,
    required this.inicial,
    required this.indice,
    required this.cartaz,
  });

  final FotoDoCartaz foto;
  final EnquadramentoFoto inicial;

  /// Posição da foto no cartaz (ver [nomesDosEspacos]).
  final int indice;

  /// O cartaz atual, para medir o espaço da foto: o formato dele muda com
  /// o texto dos dados.
  final ConteudoCartaz cartaz;

  @override
  State<EnquadramentoScreen> createState() => _EnquadramentoScreenState();
}

class _EnquadramentoScreenState extends State<EnquadramentoScreen> {
  late EnquadramentoFoto _atual = widget.inicial;
  late final ImageProvider _imagem = imagemDoCartaz(widget.foto);
  Size? _espaco;

  void _aoMedir(Size mosaico) {
    final espaco = CartazProcuraSe.espacosDoMosaico(mosaico)[widget.indice];
    if (mounted && espaco != _espaco) setState(() => _espaco = espaco);
  }

  void _focar(Offset ponto, Size foto) => setState(() => _atual = _atual
      .ajustado(focoX: ponto.dx / foto.width, focoY: ponto.dy / foto.height));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inteira = _atual.inteira;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Ajustar ${nomesDosEspacos[widget.indice]}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_atual),
            child: const Text('Pronto'),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // O cartaz atual, sem fotos e fora da tela, só para medir o
          // espaço desta foto.
          Offstage(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: CartazProcuraSe.largura,
              maxWidth: CartazProcuraSe.largura,
              minHeight: CartazProcuraSe.altura,
              maxHeight: CartazProcuraSe.altura,
              child: CartazProcuraSe(
                conteudo: widget.cartaz.semFotos,
                aoMedirMosaico: _aoMedir,
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SegmentedButton<bool>(
                  key: const ValueKey('cartaz-modo-da-foto'),
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.crop),
                      label: Text('Preencher'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.fit_screen_outlined),
                      label: Text('Foto inteira'),
                    ),
                  ],
                  selected: {inteira},
                  onSelectionChanged: (escolha) => setState(
                      () => _atual = _atual.ajustado(inteira: escolha.first)),
                ),
                const SizedBox(height: 8),
                Text(
                  inteira
                      ? 'A foto aparece inteira, sem cortes. O resto do '
                          'espaço fica com um fundo desfocado da própria foto.'
                      : 'A foto preenche o espaço e as sobras são cortadas. '
                          'Toque na foto (ou arraste) no ponto que deve ficar '
                          'no centro, como o rosto do pet. A parte clara é o '
                          'que aparece no cartaz.',
                  style: TextStyle(color: colors.textMuted),
                ),
                const SizedBox(height: 16),
                if (!inteira) ...[
                  _EscolhaDoFoco(
                    imagem: _imagem,
                    enquadramento: _atual,
                    espaco: _espaco,
                    aoFocar: _focar,
                  ),
                  const SizedBox(height: 20),
                ],
                Text('Como fica no cartaz',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _PreviaDoEspaco(
                    imagem: _imagem, enquadramento: _atual, espaco: _espaco),
                if (!inteira) ...[
                  const SizedBox(height: 16),
                  _Controle(
                    rotulo: 'Zoom',
                    valor: _atual.zoom,
                    minimo: 1,
                    maximo: EnquadramentoFoto.zoomMaximo,
                    aoMudar: (v) =>
                        setState(() => _atual = _atual.ajustado(zoom: v)),
                  ),
                  _Controle(
                    rotulo: 'Foco horizontal',
                    valor: _atual.focoX,
                    minimo: 0,
                    maximo: 1,
                    aoMudar: (v) =>
                        setState(() => _atual = _atual.ajustado(focoX: v)),
                  ),
                  _Controle(
                    rotulo: 'Foco vertical',
                    valor: _atual.focoY,
                    minimo: 0,
                    maximo: 1,
                    aoMudar: (v) =>
                        setState(() => _atual = _atual.ajustado(focoY: v)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(
                          () => _atual = EnquadramentoFoto.centralizado),
                      icon: const Icon(Icons.center_focus_strong_outlined),
                      label: const Text('Centralizar'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A foto inteira, com o ponto de foco marcado e, fora da parte que
/// aparece no cartaz, um véu escuro. Tocar ou arrastar move o foco; o
/// toque é da foto, não da rolagem da tela.
class _EscolhaDoFoco extends StatelessWidget {
  const _EscolhaDoFoco({
    required this.imagem,
    required this.enquadramento,
    required this.espaco,
    required this.aoFocar,
  });

  final ImageProvider imagem;
  final EnquadramentoFoto enquadramento;
  final Size? espaco;
  final void Function(Offset ponto, Size foto) aoFocar;

  static const alturaMaxima = 360.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TamanhoDaImagem(
      imagem: imagem,
      builder: (context, tamanho, erro) {
        if (erro) {
          return Text('Não foi possível carregar a foto.',
              style: TextStyle(color: colors.error));
        }
        if (tamanho == null || tamanho.isEmpty) {
          return const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator()));
        }
        final proporcao = tamanho.width / tamanho.height;
        return LayoutBuilder(builder: (context, restricoes) {
          var largura = restricoes.maxWidth;
          var altura = largura / proporcao;
          if (altura > alturaMaxima) {
            altura = alturaMaxima;
            largura = altura * proporcao;
          }
          final foto = Size(largura, altura);
          final espaco = this.espaco;
          final area = espaco == null
              ? null
              : enquadramento.areaVisivel(
                  proporcaoDaFoto: proporcao,
                  proporcaoDoEspaco: espaco.width / espaco.height);
          void tocar(Offset ponto) => aoFocar(ponto, foto);
          return Center(
            child: Semantics(
              image: true,
              label: 'Foto inteira. Toque no ponto que deve ficar no centro '
                  'do espaço.',
              child: RawGestureDetector(
                gestures: {
                  EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                          EagerGestureRecognizer>(
                      EagerGestureRecognizer.new, (_) {}),
                },
                child: Listener(
                  key: const ValueKey('cartaz-escolha-do-foco'),
                  onPointerDown: (e) => tocar(e.localPosition),
                  onPointerMove: (e) => tocar(e.localPosition),
                  child: SizedBox.fromSize(
                    size: foto,
                    child: CustomPaint(
                      foregroundPainter: _PintorDoFoco(
                        area: area,
                        focoX: enquadramento.focoX,
                        focoY: enquadramento.focoY,
                      ),
                      child: Image(image: imagem, fit: BoxFit.fill),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

class _PintorDoFoco extends CustomPainter {
  _PintorDoFoco({
    required this.area,
    required this.focoX,
    required this.focoY,
  });

  final AreaVisivel? area;
  final double focoX;
  final double focoY;

  @override
  void paint(Canvas canvas, Size size) {
    final area = this.area;
    if (area != null) {
      final visivel = Rect.fromLTWH(
        area.esquerda * size.width,
        area.topo * size.height,
        area.largura * size.width,
        area.altura * size.height,
      );
      canvas.drawPath(
        Path.combine(PathOperation.difference,
            Path()..addRect(Offset.zero & size), Path()..addRect(visivel)),
        Paint()..color = Colors.black.withValues(alpha: 0.55),
      );
      canvas.drawRect(
        visivel.deflate(1),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final foco = Offset(focoX * size.width, focoY * size.height);
    final contorno = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final traco = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final pincel in [contorno, traco]) {
      canvas
        ..drawCircle(foco, 14, pincel)
        ..drawLine(foco.translate(-22, 0), foco.translate(-8, 0), pincel)
        ..drawLine(foco.translate(8, 0), foco.translate(22, 0), pincel)
        ..drawLine(foco.translate(0, -22), foco.translate(0, -8), pincel)
        ..drawLine(foco.translate(0, 8), foco.translate(0, 22), pincel);
    }
  }

  @override
  bool shouldRepaint(_PintorDoFoco antigo) =>
      antigo.area != area || antigo.focoX != focoX || antigo.focoY != focoY;
}

/// A foto no formato exato do espaço dela no cartaz.
class _PreviaDoEspaco extends StatelessWidget {
  const _PreviaDoEspaco({
    required this.imagem,
    required this.enquadramento,
    required this.espaco,
  });

  final ImageProvider imagem;
  final EnquadramentoFoto enquadramento;
  final Size? espaco;

  static const alturaMaxima = 240.0;

  @override
  Widget build(BuildContext context) {
    final espaco = this.espaco;
    if (espaco == null || espaco.isEmpty) {
      return const SizedBox(
          height: 160, child: Center(child: CircularProgressIndicator()));
    }
    final proporcao = espaco.width / espaco.height;
    return LayoutBuilder(builder: (context, restricoes) {
      final largura = restricoes.maxWidth < alturaMaxima * proporcao
          ? restricoes.maxWidth
          : alturaMaxima * proporcao;
      return Center(
        child: SizedBox(
          width: largura,
          child: AspectRatio(
            aspectRatio: proporcao,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Semantics(
                image: true,
                label: 'Foto como vai aparecer no cartaz',
                child: FotoEnquadrada(
                    imagem: imagem, enquadramento: enquadramento),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _Controle extends StatelessWidget {
  const _Controle({
    required this.rotulo,
    required this.valor,
    required this.minimo,
    required this.maximo,
    required this.aoMudar,
  });

  final String rotulo;
  final double valor;
  final double minimo;
  final double maximo;
  final ValueChanged<double> aoMudar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(rotulo)),
        Expanded(
          child: Slider(
            value: valor,
            min: minimo,
            max: maximo,
            label: rotulo,
            semanticFormatterCallback: (v) => '$rotulo ${v.toStringAsFixed(1)}',
            onChanged: aoMudar,
          ),
        ),
      ],
    );
  }
}
