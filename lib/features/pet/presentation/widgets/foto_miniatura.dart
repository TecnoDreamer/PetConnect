import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/foto_pet.dart';

/// Miniatura quadrada de uma foto da galeria. Carrega a versão reduzida do
/// Cloudinary (nunca o original) e decodifica no tamanho exibido, para a
/// grade não ocupar memória com imagens grandes.
class FotoMiniatura extends StatelessWidget {
  const FotoMiniatura({
    super.key,
    required this.foto,
    required this.descricao,
    required this.aoTocar,
  });

  final FotoPet foto;

  /// Lida pelo leitor de tela (ex.: "Foto 3 de Rex").
  final String descricao;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pixels = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      button: true,
      image: true,
      label: '$descricao. Toque para ampliar.',
      excludeSemantics: true,
      child: Material(
        color: colors.cardBackground,
        child: InkWell(
          onTap: aoTocar,
          child: LayoutBuilder(
            builder: (context, constraints) => CachedNetworkImage(
              imageUrl: foto.miniaturaUrl,
              fit: BoxFit.cover,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              memCacheWidth: constraints.maxWidth.isFinite
                  ? (constraints.maxWidth * pixels).round()
                  : null,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, __) => ColoredBox(color: colors.cardBackground),
              errorWidget: (_, __, ___) => Center(
                child:
                    Icon(Icons.broken_image_outlined, color: colors.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
