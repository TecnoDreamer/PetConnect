import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/settings_menu_tile.dart';

/// Ações secundárias do perfil do pet — Localização/avistamento (RF31-32) e
/// Configurações **do pet** (nunca do tutor — bug corrigido em
/// prompt_correcao_configuracoes_perfil_pet.md, 2026-09-13: antes este
/// botão abria as configurações da conta). O briefing de layout original
/// sugeria também "Ajuda" e "Acessibilidade", mas nenhuma das duas tem uma
/// tela real no app ainda; criar um item que não leva a lugar nenhum seria
/// uma feature falsa, então ficam de fora por ora (ver sugestão de roadmap
/// no relatório da PR).
///
/// Reaproveita [SettingsMenuTile] (mesmo componente dos menus de
/// configurações) — mesmo padrão visual em todo o app.
class PetSecondaryActions extends StatelessWidget {
  const PetSecondaryActions(
      {super.key, required this.petId, this.mostrarFotos = false});

  final String petId;

  /// Galeria de fotos do pet (docs/features/galeria-fotos-pet.md).
  final bool mostrarFotos;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          // Cartaz "Procura-se" (docs/features/cartaz-pet-desaparecido.md).
          SettingsMenuTile(
            icon: Icons.campaign_outlined,
            title: 'Pet desaparecido',
            onTap: () => context.push('/pet/$petId/cartaz'),
          ),
          Divider(
              height: 1,
              indent: 56,
              endIndent: 16,
              color: context.colors.divider),
          if (mostrarFotos) ...[
            SettingsMenuTile(
              icon: Icons.photo_library_outlined,
              title: 'Fotos',
              onTap: () => context.push('/pet/$petId/fotos'),
            ),
            Divider(
                height: 1,
                indent: 56,
                endIndent: 16,
                color: context.colors.divider),
          ],
          SettingsMenuTile(
            icon: Icons.location_on_outlined,
            title: 'Localização',
            onTap: () => context.push('/pet/$petId/localizacao'),
          ),
          Divider(
              height: 1,
              indent: 56,
              endIndent: 16,
              color: context.colors.divider),
          SettingsMenuTile(
            icon: Icons.settings_outlined,
            title: 'Configurações',
            onTap: () => context.push('/pet/$petId/configuracoes'),
          ),
        ],
      ),
    );
  }
}
