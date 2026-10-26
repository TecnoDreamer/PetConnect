// Cobre a correção pós-validação física: o app deve sempre exigir login de
// novo ao ser reaberto, mesmo com uma sessão do Firebase Auth persistida.
//
// Não dá pra simular "sessão persistida" com um `User` de verdade sem uma
// biblioteca de mocks do Firebase (não usada no projeto — ver auditoria em
// docs/audit/post-device-validation-fixes.md) — `FirebaseAuth`/`User` são
// classes concretas do SDK, sem interface própria aqui. O que este teste
// prova é o mecanismo real da correção: a splash só decide o destino
// **depois** que [sessionBootstrapProvider] (o `signOut()` de bootstrap)
// termina — nunca antes. A cobertura de que o `signOut()` de fato limpa uma
// sessão persistida do Firebase é o próprio `auth_flow_test.dart` (e2e) +
// validação manual no aparelho físico (ver checklist da PR).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_colors.dart';
import 'package:pet_connect/features/auth/presentation/screens/splash_screen.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

Widget _appComSplash({
  required Future<void> Function() bootstrap,
  required Stream<dynamic> authStateChanges,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const Text('Login')),
      GoRoute(path: '/home', builder: (context, state) => const Text('Home')),
    ],
  );

  return ProviderScope(
    overrides: [
      sessionBootstrapProvider.overrideWith((ref) => bootstrap()),
      authStateChangesProvider.overrideWith((ref) => authStateChanges.cast()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('SplashScreen — login sempre exigido ao reabrir o app', () {
    testWidgets(
        'não navega enquanto o bootstrap de sessão (signOut) não terminar',
        (tester) async {
      final bootstrapCompleter = Completer<void>();

      await tester.pumpWidget(_appComSplash(
        bootstrap: () => bootstrapCompleter.future,
        authStateChanges: Stream.value(null),
      ));

      // Bem mais que o necessário para navegar — se a splash não esperasse
      // o bootstrap, já teria saído daqui.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(SplashScreen), findsOneWidget,
          reason: 'ainda deveria estar na splash, esperando o signOut');
      expect(find.text('Login'), findsNothing);
      expect(find.text('Home'), findsNothing);

      bootstrapCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget,
          reason: 'só navega depois que o bootstrap de sessão termina');
    });

    testWidgets(
        'com o bootstrap concluído e sem sessão, vai para o login sem '
        'tempo mínimo artificial', (tester) async {
      await tester.pumpWidget(_appComSplash(
        bootstrap: () async {},
        authStateChanges: Stream.value(null),
      ));

      // Só a transição de página (sem os 2,5s fixos de antes).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Login'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets(
        'mesma aparência da splash nativa: fundo da marca, só o logo, '
        'ícones claros na status bar', (tester) async {
      final bootstrap = Completer<void>();
      await tester.pumpWidget(_appComSplash(
        bootstrap: () => bootstrap.future,
        authStateChanges: Stream.value(null),
      ));
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.descendant(
          of: find.byType(SplashScreen), matching: find.byType(Scaffold)));
      expect(scaffold.backgroundColor, AppColors.brandMedium,
          reason: 'tem que bater com @color/splash_fundo do Android');
      expect(find.text('PetConnect'), findsNothing,
          reason: 'sem segunda "tela de abertura" com texto');
      expect(find.bySemanticsLabel('PetConnect, carregando'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is AnnotatedRegion<SystemUiOverlayStyle> &&
            w.value == SystemUiOverlayStyle.light),
        findsOneWidget,
      );

      bootstrap.complete();
      await tester.pumpAndSettle();
    });

    // O try/catch dentro de sessionBootstrapProvider (auth_providers.dart)
    // garante que um signOut() com falha nunca propaga como erro pra quem
    // aguarda `sessionBootstrapProvider.future` — não dá pra testar isso
    // via override (substituiria o próprio catch que se quer verificar) sem
    // uma forma de fazer o `FirebaseAuth.signOut()` real falhar, que exigiria
    // uma biblioteca de mocks do Firebase não usada no projeto.
  });
}
