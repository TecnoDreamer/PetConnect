import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../pet/presentation/providers/pet_providers.dart';
import '../../../pet/presentation/widgets/pet_card.dart';
import '../../domain/usuario.dart';
import '../providers/auth_providers.dart';

/// Home do tutor: lista os pets vinculados à conta (RF11), com atalho para
/// cadastrar um novo (RF10) e acessar configurações.
///
/// A Home é a raiz da navegação autenticada — o botão físico/gesto de
/// voltar não fecha o app: encerra a sessão (com confirmação) e volta ao
/// login, mesmo fluxo do ícone de logout em Configurações.
///
/// Redesign de 2026-09-13 (ver docs/features/tutor-home.md): a página não
/// tem mais um "card mestre" branco flutuando sobre o fundo — o próprio
/// fundo da página (`colors.homeBackdrop`) aparece diretamente, com
/// cabeçalho, título da seção e lista de pets soltos sobre ele.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _handleSair(BuildContext context, WidgetRef ref) async {
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
    if (confirmou == true) await ref.read(usuarioRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioAsync = ref.watch(currentUsuarioProvider);
    final petsAsync = ref.watch(petsAtivosProvider);
    final quantidadeNoMemorial =
        ref.watch(petsFalecidosProvider).valueOrNull?.length ?? 0;
    final colors = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleSair(context, ref);
      },
      child: Scaffold(
        backgroundColor: colors.homeBackdrop,
        body: SafeArea(
          child: usuarioAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Text(
                'Não foi possível carregar seus dados.',
                style: TextStyle(color: colors.error),
              ),
            ),
            data: (usuario) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _Cabecalho(usuario: usuario),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Meus Pets',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _AdicionarPetButton(
                          onTap: () => context.push('/pet/novo')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: petsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Center(
                      child: Text(
                        'Não foi possível carregar seus pets.',
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                    data: (pets) {
                      Future<void> atualizar() async {
                        ref.invalidate(petsProvider);
                        await ref.read(petsProvider.future);
                      }

                      if (pets.isEmpty) {
                        return RefreshIndicator(
                          onRefresh: atualizar,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  quantidadeNoMemorial > 0
                                      ? 'Nenhum pet ativo no momento.\nToque em "Adicionar pet" para cadastrar.'
                                      : 'Você ainda não cadastrou nenhum pet.\nToque em "Adicionar pet" para começar.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: atualizar,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          itemCount: pets.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final pet = pets[index];
                            return PetCard(
                              pet: pet,
                              colorIndex: index,
                              onTap: () => context.push('/pet/${pet.id}'),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (quantidadeNoMemorial > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _EntradaMemorial(
                      quantidade: quantidadeNoMemorial,
                      onTap: () => context.push('/memorial'),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _RodapeInfo(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.usuario});

  final Usuario? usuario;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final primeiroNome = usuario != null && usuario!.nome.isNotEmpty
        ? usuario!.nome.trim().split(' ').first
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label:
              primeiroNome != null ? 'Foto de $primeiroNome' : 'Foto do tutor',
          child: ExcludeSemantics(
            child: CircleAvatar(
              radius: 28,
              backgroundColor: colors.background,
              backgroundImage:
                  usuario?.foto != null ? NetworkImage(usuario!.foto!) : null,
              child: usuario?.foto == null
                  ? Icon(Icons.person, size: 28, color: colors.brandMedium)
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primeiroNome != null ? 'Olá, $primeiroNome!' : 'Olá!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecione um pet para acessar o perfil',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        _BotaoCircular(
          icon: Icons.more_vert,
          tooltip: 'Configurações',
          onTap: () => context.push('/configuracoes'),
        ),
      ],
    );
  }
}

class _BotaoCircular extends StatelessWidget {
  const _BotaoCircular(
      {required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.cardBackground,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: colors.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Botão em formato de pílula na mesma linha do título "Meus Pets" —
/// substitui o antigo card grande de CTA (redesign de 2026-09-13).
class _AdicionarPetButton extends StatelessWidget {
  const _AdicionarPetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Índice 2 da paleta cíclica é sempre o tom "verde" em qualquer modo —
    // reaproveita em vez de fixar uma cor própria só pra este botão.
    final fundo = colors.petCardBackgrounds[2];

    return Semantics(
      button: true,
      label: 'Adicionar pet',
      child: Material(
        color: fundo,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: colors.success, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Adicionar pet',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.success,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RodapeInfo extends StatelessWidget {
  const _RodapeInfo();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Antes do redesign o fundo da página era um card branco e este
    // rodapé usava `homeBackdrop` pra se destacar dele. Agora o próprio
    // fundo da página É `homeBackdrop`, então o rodapé passa a usar
    // `surface` pra continuar se destacando (2026-09-13).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: colors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Seus pets, cuidados e momentos especiais, todos em um só lugar.',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
          Icon(Icons.favorite, color: colors.success, size: 18),
        ],
      ),
    );
  }
}

/// Entrada discreta para a seção Memorial (pets falecidos). Só aparece
/// quando há pelo menos um pet no Memorial.
class _EntradaMemorial extends StatelessWidget {
  const _EntradaMemorial({required this.quantidade, required this.onTap});

  final int quantidade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'Memorial, $quantidade ${quantidade == 1 ? 'pet' : 'pets'}',
      child: ExcludeSemantics(
        child: Material(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.local_florist_outlined, color: colors.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Memorial',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text('$quantidade',
                      style: TextStyle(color: colors.textMuted)),
                  Icon(Icons.chevron_right, color: colors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
