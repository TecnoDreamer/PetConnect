import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/settings_menu_tile.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/alteracao_situacao.dart';
import '../providers/pet_providers.dart';

/// Configurações restritas do memorial: só a correção de um falecimento
/// registrado por engano (ver docs/features/memorial-pet.md). Edição de
/// perfil, capa e exclusão ficam nas configurações do pet ativo.
class MemorialSettingsScreen extends ConsumerStatefulWidget {
  const MemorialSettingsScreen({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<MemorialSettingsScreen> createState() =>
      _MemorialSettingsScreenState();
}

class _MemorialSettingsScreenState
    extends ConsumerState<MemorialSettingsScreen> {
  bool _restaurando = false;

  Future<void> _corrigir(String nome) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Corrigir informação de falecimento'),
        content: Text(
          'Use esta opção se o falecimento de $nome foi registrado por '
          'engano. O perfil volta a ficar ativo, com vacinas, consultas e '
          'histórico exatamente como estavam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restaurar perfil'),
          ),
        ],
      ),
    );
    if (confirmou != true || _restaurando || !mounted) return;

    final atorId = ref.read(currentUsuarioProvider).valueOrNull?.id;
    if (atorId == null) return;

    // Mesmo cuidado de RegistrarFalecimentoScreen: o guard troca a tela
    // quando o pet volta a ficar ativo.
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _restaurando = true);
    try {
      await container.read(petRepositoryProvider).alterarSituacao(
            widget.petId,
            AlteracaoDeSituacao.corrigirMarcacao(),
            atorId: atorId,
          );
      container.invalidate(petsProvider);
      container.invalidate(petProvider(widget.petId));
      router.go('/pet/${widget.petId}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _restaurando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Não foi possível restaurar agora. Nada foi alterado. Tente '
                  'novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pet = ref.watch(petProvider(widget.petId)).valueOrNull;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Configurações do memorial')),
      body: SafeArea(
        child: pet == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  const SettingsSectionHeader(
                      title: 'Informação de falecimento'),
                  SettingsMenuTile(
                    icon: Icons.restore,
                    title: 'Corrigir informação de falecimento',
                    isEnabled: !_restaurando,
                    trailing: _restaurando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: () => _corrigir(pet.nome),
                  ),
                ],
              ),
      ),
    );
  }
}
