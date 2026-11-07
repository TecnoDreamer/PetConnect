import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/settings_menu_tile.dart';
import '../../../avisos/presentation/avisos_providers.dart';
import '../providers/auth_providers.dart';

/// Configurações do tutor: editar perfil (RF08), tema do aplicativo e
/// excluir conta (RF09). Menu padronizado (ícone + título + chevron, sem
/// subtítulo) — ver docs/features/theme-and-settings-menu.md.
class ConfiguracoesScreen extends ConsumerStatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  ConsumerState<ConfiguracoesScreen> createState() =>
      _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends ConsumerState<ConfiguracoesScreen> {
  bool _excluindo = false;

  Future<void> _handleSair() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza que deseja sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    // Antes do signOut: depois dele não há mais login para falar com a API.
    await ref.read(avisosDoQrProvider)?.esquecerAparelho();
    await ref.read(usuarioRepositoryProvider).signOut();
  }

  Future<void> _confirmarExclusaoConta() async {
    final colors = context.colors;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Tem certeza que deseja excluir sua conta? Todos os seus pets e os dados associados a '
          'eles (vacinas, histórico médico) serão apagados permanentemente. Esta ação não pode ser '
          'desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Excluir conta', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    setState(() => _excluindo = true);

    try {
      await ref.read(usuarioRepositoryProvider).deleteAccount();
      // Após a exclusão, o redirect do go_router leva de volta ao login
      // assim que authStateChangesProvider emitir null.
    } catch (_) {
      if (mounted) {
        setState(() => _excluindo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Não foi possível excluir a conta. Tente novamente.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAsync = ref.watch(currentUsuarioProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Configurações')),
      body: SafeArea(
        child: usuarioAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('Não foi possível carregar seus dados.',
                style: TextStyle(color: colors.error)),
          ),
          data: (usuario) {
            if (usuario == null) return const SizedBox.shrink();

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const SettingsSectionHeader(title: 'Perfil'),
                SettingsMenuTile(
                  icon: Icons.person_outline,
                  title: 'Editar perfil',
                  onTap: () => context.push('/configuracoes/editar-perfil',
                      extra: usuario),
                ),
                const SettingsSectionHeader(title: 'Aplicativo'),
                SettingsMenuTile(
                  icon: Icons.palette_outlined,
                  title: 'Tema do aplicativo',
                  onTap: () => context.push('/configuracoes/tema'),
                ),
                const SettingsSectionHeader(title: 'Conta'),
                SettingsMenuTile(
                  icon: Icons.logout,
                  title: 'Sair da conta',
                  onTap: _handleSair,
                ),
                SettingsMenuTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Excluir conta',
                  isDestructive: true,
                  isEnabled: !_excluindo,
                  trailing: _excluindo
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: colors.error),
                        )
                      : null,
                  onTap: _confirmarExclusaoConta,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
