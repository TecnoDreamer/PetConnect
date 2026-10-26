import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/pet.dart';
import '../providers/pet_providers.dart';

/// Protege uma rota de pet pela situação dele (Memorial do Pet).
///
/// - Rotas operacionais (perfil, vacinas, consultas, histórico,
///   localização, edição, configurações): exigem [SituacaoPet.ativo].
/// - Rotas do memorial: exigem [SituacaoPet.falecido].
///
/// Aplicado no router (app_router.dart), então vale também para links
/// antigos e navegação direta, não só para os botões visíveis. Também
/// confere se o pet é do tutor autenticado (RF12).
class PetSituacaoGuard extends ConsumerWidget {
  const PetSituacaoGuard({
    super.key,
    required this.petId,
    required this.exige,
    required this.child,
  });

  final String petId;
  final SituacaoPet exige;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petAsync = ref.watch(petProvider(petId));
    final uid = ref.watch(currentUsuarioProvider).valueOrNull?.id;

    return petAsync.when(
      loading: () =>
          const _Moldura(child: Center(child: CircularProgressIndicator())),
      // Erros de carregamento ficam com a própria tela, que já tem sua
      // mensagem — o guard só bloqueia quando sabe a situação.
      error: (_, __) => child,
      data: (pet) {
        if (pet == null || pet.userId != uid) {
          return const _Moldura(child: _Aviso(mensagem: 'Pet não encontrado.'));
        }
        if (pet.situacao == exige) return child;
        return _Moldura(
          child: pet.falecido
              ? _Aviso(
                  mensagem: '${pet.nome} está no Memorial. Vacinas, '
                      'consultas e histórico ficam ocultos, mas continuam '
                      'guardados.',
                  acao: 'Abrir memorial',
                  aoTocar: () => context.go('/memorial/${pet.id}'),
                )
              : _Aviso(
                  mensagem: '${pet.nome} não está no Memorial.',
                  acao: 'Abrir perfil',
                  aoTocar: () => context.go('/pet/${pet.id}'),
                ),
        );
      },
    );
  }
}

class _Moldura extends StatelessWidget {
  const _Moldura({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(),
      body: SafeArea(child: child),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.mensagem, this.acao, this.aoTocar});

  final String mensagem;
  final String? acao;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted, fontSize: 15),
            ),
            if (acao != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: aoTocar, child: Text(acao!)),
            ],
          ],
        ),
      ),
    );
  }
}
