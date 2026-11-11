import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../usuario/presentation/providers/auth_providers.dart';
import 'providers/limpeza_providers.dart';

/// Repete, a cada login ou abertura do app com sessão, os pedidos de limpeza
/// na API que ficaram guardados porque a API estava fora quando o tutor
/// excluiu um pet (`LimpezaNaApi.retomarPendentes`). Fica acima das telas
/// (no `builder` do MaterialApp) e não desenha nada.
class RetomadaDaLimpezaNaApi extends ConsumerStatefulWidget {
  const RetomadaDaLimpezaNaApi({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RetomadaDaLimpezaNaApi> createState() => _RetomadaState();
}

class _RetomadaState extends ConsumerState<RetomadaDaLimpezaNaApi> {
  StreamSubscription<Object?>? _sessao;

  @override
  void initState() {
    super.initState();
    final limpeza = ref.read(limpezaNaApiProvider);
    if (limpeza == null) return;
    _sessao = ref
        .read(firebaseAuthProvider)
        .authStateChanges()
        .map((u) => u?.uid)
        .distinct()
        .listen((uid) {
      if (uid == null) return;
      unawaited(limpeza.retomarPendentes().catchError((Object _) {}));
    });
  }

  @override
  void dispose() {
    _sessao?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
