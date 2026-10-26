import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';

/// Continuação visual da splash nativa do Android enquanto a sessão é
/// resolvida — não é uma segunda tela de abertura. Mesma cor
/// (`@color/splash_fundo` = [AppColors.brandMedium]) e mesmo logo, no mesmo
/// tamanho e posição de `android/app/src/main/res` (ver
/// docs/branding/icone-e-splash-android.md), então a troca da splash nativa
/// para o Flutter não pisca.
///
/// Fica na tela só o tempo de [sessionBootstrapProvider] (o `signOut()` que
/// exige login a cada abertura) e da primeira leitura do estado de
/// autenticação — sem tempo mínimo artificial (antes: 2,5s fixos). O
/// destino é sempre `/login` na prática, já que o bootstrap encerra
/// qualquer sessão persistida.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  /// Altura do logo na splash nativa: metade do quadro de 288dp
  /// (`ALTURA_LOGO_SPLASH` em tool/branding/gerar_icones_android.py). O
  /// asset tem uma pequena margem transparente acima do desenho, por isso
  /// a imagem é um pouco maior que isso.
  static const alturaDoDesenho = 144.0;
  static const _proporcaoDoDesenhoNoAsset = 405 / 423;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decidirDestino();
  }

  Future<void> _decidirDestino() async {
    // Sempre exige login de novo nesta abertura do app, mesmo com sessão
    // persistida — precisa terminar antes da linha abaixo (ver
    // sessionBootstrapProvider).
    await ref.read(sessionBootstrapProvider.future);
    final usuario = await ref.read(authStateChangesProvider.future);

    if (!mounted) return;
    context.go(usuario != null ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Fundo marrom: ícones da status bar claros, como na splash nativa.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.brandMedium,
        body: Center(
          child: Semantics(
            label: 'PetConnect, carregando',
            child: Image.asset(
              'assets/images/logo.png',
              height: SplashScreen.alturaDoDesenho /
                  SplashScreen._proporcaoDoDesenhoNoAsset,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
