import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Avatar circular com um botão de câmera sobreposto — usado para escolher a
/// foto do pet e a foto do tutor, reaproveitando o mesmo tratamento visual.
///
/// [fotoLocal] é a foto que acabou de ser escolhida: aparece na hora,
/// enquanto o envio acontece, e tem prioridade sobre [fotoUrl].
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.fotoUrl,
    required this.onTap,
    this.fotoLocal,
    this.enviando = false,
    this.placeholderIcon = Icons.pets,
    this.radius = 56,
  });

  final String? fotoUrl;
  final Uint8List? fotoLocal;
  final VoidCallback onTap;
  final bool enviando;
  final IconData placeholderIcon;
  final double radius;

  ImageProvider? get _imagem {
    if (fotoLocal != null) return MemoryImage(fotoLocal!);
    if (fotoUrl != null) return CachedNetworkImageProvider(fotoUrl!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final imagem = _imagem;
    return GestureDetector(
      onTap: enviando ? null : onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: colors.surface,
            backgroundImage: imagem,
            child: imagem == null
                ? Icon(placeholderIcon,
                    size: radius * 0.85, color: colors.brandMedium)
                : null,
          ),
          if (enviando)
            Positioned.fill(
              child: CircleAvatar(
                backgroundColor: Colors.black38,
                child: SizedBox(
                  width: radius * 0.6,
                  height: radius * 0.6,
                  child: const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              ),
            )
          else
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                radius: radius * 0.32,
                backgroundColor: colors.brandDark,
                child: Icon(Icons.camera_alt,
                    size: radius * 0.32, color: colors.textOnBrand),
              ),
            ),
        ],
      ),
    );
  }
}
