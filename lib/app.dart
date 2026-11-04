import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/idioma.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode.dart';
import 'core/theme/theme_providers.dart';
import 'routing/app_router.dart';

class PetConnectApp extends ConsumerWidget {
  const PetConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final modo = ref.watch(themeModeProvider);

    // Cobre telas sem AppBar (Home, por exemplo) — o AppBarTheme (em
    // AppTheme.build) já cuida das que têm.
    final overlayDaStatusBar = modo == AppThemeMode.escuro
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayDaStatusBar,
      child: MaterialApp.router(
        title: 'PetConnect',
        debugShowCheckedModeBanner: false,
        // Um único `theme:`, dinâmico pelo modo atual — não
        // `theme`/`darkTheme`/`themeMode` do Flutter, porque existem três
        // modos (Padrão/Claro/Escuro), não dois (ver seção 13 do briefing
        // de tema). Trocar o modo só reconstrói a árvore visual — nenhuma
        // chamada de API, login ou navegação é refeita (o router e as
        // instâncias de repository não dependem do tema).
        theme: AppTheme.build(modo),
        locale: IdiomaDoApp.locale,
        supportedLocales: IdiomaDoApp.suportados,
        localizationsDelegates: IdiomaDoApp.delegates,
        routerConfig: router,
      ),
    );
  }
}
