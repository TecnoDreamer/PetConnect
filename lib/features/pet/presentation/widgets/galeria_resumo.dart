import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/pet.dart';
import '../providers/galeria_providers.dart';
import '../screens/galeria_viewer_screen.dart';
import '../screens/publicar_fotos_screen.dart';
import 'foto_miniatura.dart';

/// A galeria dentro do Memorial: as fotos mais recentes e os atalhos para
/// ver todas e adicionar novas. Pet falecido continua recebendo fotos; só
/// os recursos clínicos ficam ocultos.
class GaleriaResumo extends ConsumerWidget {
  const GaleriaResumo({super.key, required this.pet});

  final Pet pet;

  static const _maximo = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final estado = ref.watch(galeriaControllerProvider(pet.id));
    final fotos = estado.fotos.take(_maximo).toList();

    final Widget conteudo;
    if (estado.carregando && fotos.isEmpty) {
      conteudo = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (estado.erro && fotos.isEmpty) {
      conteudo = Text('Não foi possível carregar as fotos.',
          style: TextStyle(color: colors.textMuted));
    } else if (fotos.isEmpty) {
      conteudo = Text('Guarde aqui as lembranças de ${pet.nome}.',
          style: TextStyle(color: colors.textMuted));
    } else {
      conteudo = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final (indice, foto) in fotos.indexed)
              FotoMiniatura(
                key: ValueKey(foto.id),
                foto: foto,
                descricao: 'Foto ${indice + 1} de ${pet.nome}',
                aoTocar: () => GaleriaViewerScreen.abrir(
                  context,
                  petId: pet.id,
                  indiceInicial: indice,
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Fotos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (estado.fotos.isNotEmpty)
              TextButton(
                onPressed: () => context.push('/pet/${pet.id}/fotos'),
                child: const Text('Ver todas'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        conteudo,
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => adicionarFotosAoPet(context, pet),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(estado.fotos.isEmpty
              ? 'Adicionar primeira foto'
              : 'Adicionar fotos'),
        ),
      ],
    );
  }
}
