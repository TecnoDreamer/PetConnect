import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../providers/galeria_providers.dart';
import '../providers/pet_providers.dart';
import '../widgets/pet_feature_grid.dart';
import '../widgets/pet_profile_header.dart';
import '../widgets/pet_secondary_actions.dart';

/// Perfil de um único pet (RF15). Só mostra dados se o pet pertencer ao
/// tutor autenticado — RF12, reforçado aqui além das regras de segurança
/// do Firestore.
///
/// Layout em cards (ver docs/next-stage e prompt_claude_perfil_pet_layout.md,
/// 2026-09-12): identidade do pet em destaque no topo, as 4 funcionalidades
/// principais em [PetFeatureGrid], ações secundárias em
/// [PetSecondaryActions]. Editar e excluir **não ficam mais aqui** —
/// moveram para [PetSettingsScreen] (correção de 2026-09-13): a tela
/// principal é só visualização, administração fica nas configurações do
/// pet, sem misturar as duas coisas.
class PetDetailScreen extends ConsumerWidget {
  const PetDetailScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petAsync = ref.watch(petProvider(petId));
    final uid = ref.watch(currentUsuarioProvider).valueOrNull?.id;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(),
      body: SafeArea(
        child: petAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('Não foi possível carregar este pet.',
                style: TextStyle(color: colors.error)),
          ),
          data: (pet) {
            if (pet == null || pet.userId != uid) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Pet não encontrado.',
                    style: TextStyle(color: colors.textMuted),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PetProfileHeader(pet: pet),
                  const SizedBox(height: 28),
                  PetFeatureGrid(pet: pet),
                  const SizedBox(height: 20),
                  PetSecondaryActions(
                    petId: pet.id,
                    mostrarFotos: ref.watch(galeriaDisponivelProvider),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
