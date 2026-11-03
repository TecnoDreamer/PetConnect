import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../pet/presentation/providers/localizacao_providers.dart';
import '../../usuario/presentation/providers/auth_providers.dart';
import '../domain/aviso_do_qr.dart';
import 'avisos_providers.dart';

/// Põe os avisos do QR para funcionar no app inteiro (issue #36). Fica
/// acima das telas (no `builder` do MaterialApp) e não desenha nada.
///
/// - Toque na notificação: vai para a Home e abre a aba Localização do pet.
///   Se o toque abriu o app, espera o login e a chegada à Home.
/// - Aviso com o app aberto: mostra uma faixa com "Ver" em [mensageiro].
class EscutaDeAvisosDoQr extends ConsumerStatefulWidget {
  const EscutaDeAvisosDoQr({
    super.key,
    required this.router,
    required this.mensageiro,
    required this.child,
  });

  final GoRouter router;
  final GlobalKey<ScaffoldMessengerState> mensageiro;
  final Widget child;

  @override
  ConsumerState<EscutaDeAvisosDoQr> createState() => _EscutaState();
}

class _EscutaState extends ConsumerState<EscutaDeAvisosDoQr> {
  @override
  void initState() {
    super.initState();
    final avisos = ref.read(avisosDoQrProvider);
    if (avisos == null) return;

    final auth = ref.read(firebaseAuthProvider);
    avisos.iniciar(
      logado: auth.authStateChanges().map((u) => u != null),
      abrir: (rota) {
        widget.router.go('/home');
        widget.router.push(rota);
      },
      mostrar: _mostrar,
      atualizar: (petId) => ref.invalidate(atividadeDoQrProvider(petId)),
    );
    widget.router.routerDelegate.addListener(_navegou);
  }

  void _navegou() {
    final caminho = widget.router.routerDelegate.currentConfiguration.uri.path;
    if (caminho != '/home') return;
    // Fora do aviso de navegação: navegar dentro dele atrapalharia a troca
    // de tela em andamento.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(avisosDoQrProvider)?.abrirQuandoPossivel();
    });
  }

  void _mostrar(AvisoDoQr aviso, String? titulo) {
    final texto = titulo ??
        (aviso.tipo == TipoDeAvisoDoQr.avistamento
            ? 'Novo avistamento pelo QR Code'
            : 'O QR Code foi acessado');
    widget.mensageiro.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => widget.router.push(aviso.rota),
        ),
      ));
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_navegou);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
