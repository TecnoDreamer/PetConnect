import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../providers/pet_providers.dart';
import '../widgets/pet_avatar.dart';

/// Seção Memorial: pets falecidos do tutor (ver
/// docs/features/memorial-pet.md). Mesma consulta da lista de pets da Home,
/// filtrada pela situação — não busca nada a mais.
class MemorialListScreen extends ConsumerWidget {
  const MemorialListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final falecidos = ref.watch(petsFalecidosProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Memorial')),
      body: SafeArea(
        child: falecidos.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('Não foi possível carregar o Memorial.',
                style: TextStyle(color: colors.error)),
          ),
          data: (pets) {
            if (pets.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Nenhum pet no Memorial.',
                      style: TextStyle(color: colors.textMuted)),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: pets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final pet = pets[index];
                final detalhes = [pet.especie, pet.raca]
                    .where((s) => s.isNotEmpty)
                    .join(' · ');
                return Material(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.push('/memorial/${pet.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: PetAvatar(
                                fotoUrl: pet.foto,
                                radius: 28,
                                nomeDoPet: pet.nome),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pet.nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                if (detalhes.isNotEmpty)
                                  Text(
                                    detalhes,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: colors.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: colors.textMuted),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
