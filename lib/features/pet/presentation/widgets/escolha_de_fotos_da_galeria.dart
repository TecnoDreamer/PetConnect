import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/compartilhamento_publico.dart';
import '../../domain/foto_pet.dart';

/// Grade para escolher as duas fotos da galeria que aparecem na página do QR
/// depois da foto de perfil (issue #103). A ordem do toque é a ordem do
/// carrossel: a primeira escolhida é a foto 2, a segunda é a foto 3.
///
/// Com as duas escolhidas, tocar numa terceira não faz nada: o tutor tira
/// uma antes de trocar.
class EscolhaDeFotosDaGaleria extends StatelessWidget {
  const EscolhaDeFotosDaGaleria({
    super.key,
    required this.fotos,
    required this.escolhidas,
    required this.aoAlternar,
    this.habilitada = true,
  });

  final List<FotoPet> fotos;

  /// Ids escolhidos, na ordem do carrossel.
  final List<String> escolhidas;
  final ValueChanged<String> aoAlternar;
  final bool habilitada;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final completas = escolhidas.length >= fotosDaGaleriaNaPagina;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Escolha $fotosDaGaleriaNaPagina fotos: '
          '${escolhidas.length} de $fotosDaGaleriaNaPagina',
          key: const ValueKey('contagem-fotos-galeria'),
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final (i, foto) in fotos.indexed)
              _Miniatura(
                key: ValueKey('foto-galeria-${foto.id}'),
                foto: foto,
                descricao: 'Foto ${i + 1} da galeria',
                posicao: escolhidas.contains(foto.id)
                    ? escolhidas.indexOf(foto.id) + 2
                    : null,
                aoTocar:
                    habilitada && (escolhidas.contains(foto.id) || !completas)
                        ? () => aoAlternar(foto.id)
                        : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({
    super.key,
    required this.foto,
    required this.descricao,
    required this.posicao,
    required this.aoTocar,
  });

  final FotoPet foto;
  final String descricao;

  /// Posição no carrossel (2 ou 3), ou nulo se não foi escolhida.
  final int? posicao;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final escolhida = posicao != null;
    return Semantics(
      button: true,
      selected: escolhida,
      enabled: aoTocar != null,
      label: escolhida ? '$descricao, foto $posicao da página' : descricao,
      excludeSemantics: true,
      child: GestureDetector(
        // Recebe o toque mesmo antes de a miniatura carregar.
        behavior: HitTestBehavior.opaque,
        onTap: aoTocar,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: foto.miniaturaUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => ColoredBox(
                  color: colors.cardBackground,
                  child: Icon(Icons.broken_image_outlined,
                      color: colors.textMuted),
                ),
              ),
              if (escolhida)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.brandDark, width: 3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              if (escolhida)
                Positioned(
                  top: 4,
                  right: 4,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: colors.brandDark,
                    child: Text('$posicao',
                        style: TextStyle(
                            color: colors.textOnBrand,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              if (!escolhida && aoTocar == null)
                const ColoredBox(color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
