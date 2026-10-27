import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Para telas que podem ficar na base da pilha: abertas por link direto,
/// com o app reaberto ou depois de um `go` (como ao restaurar um perfil do
/// Memorial). Sem tela anterior, o Voltar do sistema fecharia o app; aqui
/// ele leva à Home, e a AppBar ganha a seta de voltar com o mesmo destino
/// (docs/features/memorial-retorno-navegacao.md).
///
/// Com histórico, nada muda: o Voltar volta para a tela anterior.
class VoltarParaHome extends StatelessWidget {
  const VoltarParaHome({super.key, required this.child});

  final Widget child;

  /// Se esta tela é a única da pilha. Lido do [ModalRoute], que reconstrói
  /// a tela quando a pilha abaixo dela muda.
  static bool semHistorico(BuildContext context) =>
      !(ModalRoute.of(context)?.canPop ?? true);

  /// Seta para a AppBar quando não há tela anterior; nula quando há (a
  /// AppBar já mostra a dela).
  static Widget? seta(BuildContext context) => semHistorico(context)
      ? BackButton(onPressed: () => context.go('/home'))
      : null;

  @override
  Widget build(BuildContext context) {
    final semHistorico = VoltarParaHome.semHistorico(context);
    return PopScope(
      canPop: !semHistorico,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: child,
    );
  }
}
