// A sessão do Firebase Auth fica guardada no aparelho: reabrir o app volta
// direto para a Home, e só "Sair da conta" encerra a sessão (decisão do
// proprietário de 2026-11-04, que substitui o login a cada abertura). O
// primeiro acesso de cada instalação pede login.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_connect/core/theme/app_colors.dart';
import 'package:pet_connect/features/auth/application/primeiro_acesso.dart';
import 'package:pet_connect/features/auth/presentation/screens/splash_screen.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

class _UsuarioFalso extends Fake implements User {}

/// O primeiro acesso já passou: a splash só lê a sessão.
class _AcessoJaFeito extends Fake implements PrimeiroAcesso {
  @override
  Future<void> exigirLoginSeForOPrimeiro() async {}
}

Widget _appComSplash({
  required Stream<User?> authStateChanges,
  PrimeiroAcesso? primeiroAcesso,
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
      authStateChangesProvider.overrideWith((ref) => authStateChanges),
      primeiroAcessoProvider
          .overrideWithValue(primeiroAcesso ?? _AcessoJaFeito()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('SplashScreen — primeiro acesso da instalação', () {
    testWidgets(
        'com uma sessão que veio de antes (ex.: versão anterior), encerra e '
        'vai para o login', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      User? sessao = _UsuarioFalso();

      await tester.pumpWidget(_appComSplash(
        // Lida depois do primeiro acesso, como o authStateChanges real.
        authStateChanges: Stream.multi((c) => c
          ..add(sessao)
          ..close()),
        primeiroAcesso: PrimeiroAcesso(
          prefs: prefs,
          encerrarSessao: () async => sessao = null,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(prefs.getBool(PrimeiroAcesso.chave), isTrue);
    });

    testWidgets('depois do primeiro acesso, a sessão guardada vai para a Home',
        (tester) async {
      SharedPreferences.setMockInitialValues({PrimeiroAcesso.chave: true});
      final prefs = await SharedPreferences.getInstance();
      var encerrou = false;

      await tester.pumpWidget(_appComSplash(
        authStateChanges: Stream.value(_UsuarioFalso()),
        primeiroAcesso: PrimeiroAcesso(
          prefs: prefs,
          encerrarSessao: () async => encerrou = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(encerrou, isFalse);
    });
  });

  group('SplashScreen — sessão guardada no aparelho', () {
    testWidgets('com sessão guardada, vai direto para a Home', (tester) async {
      await tester.pumpWidget(
          _appComSplash(authStateChanges: Stream.value(_UsuarioFalso())));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Login'), findsNothing);
    });

    testWidgets('sem sessão, vai para o login sem tempo mínimo artificial',
        (tester) async {
      await tester
          .pumpWidget(_appComSplash(authStateChanges: Stream.value(null)));

      // Só a transição de página (sem os 2,5s fixos de antes).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Login'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('não navega antes de saber se há sessão', (tester) async {
      final sessao = StreamController<User?>();
      addTearDown(sessao.close);
      await tester.pumpWidget(_appComSplash(authStateChanges: sessao.stream));

      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(SplashScreen), findsOneWidget);

      sessao.add(_UsuarioFalso());
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets(
        'mesma aparência da splash nativa: fundo da marca, só o logo, '
        'ícones claros na status bar', (tester) async {
      final sessao = StreamController<User?>();
      addTearDown(sessao.close);
      await tester.pumpWidget(_appComSplash(authStateChanges: sessao.stream));
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

      sessao.add(null);
      await tester.pumpAndSettle();
    });
  });
}
