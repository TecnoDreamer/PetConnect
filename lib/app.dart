import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/idioma.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_mode.dart';
import 'core/theme/theme_providers.dart';
import 'core/widgets/ao_voltar_ao_primeiro_plano.dart';
import 'features/avisos/presentation/escuta_de_avisos_do_qr.dart';
import 'features/pet/presentation/retomada_da_limpeza_na_api.dart';
import 'features/usuario/presentation/providers/auth_providers.dart';
import 'routing/app_router.dart';

/// Para mostrar avisos de fora das telas (aviso do QR com o app aberto).
final mensageiroDoApp = GlobalKey<ScaffoldMessengerState>();

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
        scaffoldMessengerKey: mensageiroDoApp,
        builder: (context, child) => AoVoltarAoPrimeiroPlano(
          // A rede do app cai em segundo plano e as conexões abertas morrem:
          // recomeçar com conexões novas evita o "Sem conexão" na volta.
          aoVoltar: () =>
              ref.read(apiClientProvider).descartarConexoesAntigas(),
          child: EscutaDeAvisosDoQr(
            router: router,
            mensageiro: mensageiroDoApp,
            child: RetomadaDaLimpezaNaApi(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
