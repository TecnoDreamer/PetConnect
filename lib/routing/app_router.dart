import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/usuario/domain/usuario.dart';
import '../features/usuario/presentation/providers/auth_providers.dart';
import '../features/usuario/presentation/screens/configuracoes_screen.dart';
import '../features/usuario/presentation/screens/tema_screen.dart';
import '../features/usuario/presentation/screens/editar_perfil_screen.dart';
import '../features/usuario/presentation/screens/home_screen.dart';
import 'auth_routes.dart';
import 'pet_routes.dart';

/// Transforma o stream de autenticação num `Listenable`, para o GoRouter
/// reavaliar `redirect` quando a sessão mudar — sem precisar recriar o
/// router inteiro (ver [appRouterProvider]).
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Uma única instância de GoRouter para o app inteiro — criada uma vez só.
/// Antes, este provider observava `authStateChangesProvider` diretamente e
/// recriava o GoRouter a cada mudança de sessão; como o GoRouter volta para
/// `initialLocation` ao ser recriado, isso fazia a splash (RF06) reaparecer
/// logo após o login, e não só na abertura do app. `refreshListenable`
/// resolve isso: o `redirect` é reavaliado com a sessão atual, mas a
/// navegação em andamento não é resetada.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(firebaseAuthProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (context, state) {
      // A splash cuida da própria navegação (aguarda a sessão resolver +
      // tempo mínimo de exibição) — o redirect não deve interferir nela, e
      // só deve rodar uma vez, na abertura do app (ver SplashScreen).
      if (state.matchedLocation == '/') return null;

      final isLoggedIn = auth.currentUser != null;
      final isAuthRoute = authRoutePaths.contains(state.matchedLocation);

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      ...buildAuthRoutes(),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      ...buildPetRoutes(),
      GoRoute(
        path: '/configuracoes',
        builder: (context, state) => const ConfiguracoesScreen(),
      ),
      GoRoute(
        path: '/configuracoes/editar-perfil',
        builder: (context, state) =>
            EditarPerfilScreen(usuario: state.extra as Usuario),
      ),
      GoRoute(
        path: '/configuracoes/tema',
        builder: (context, state) => const TemaScreen(),
      ),
    ],
  );
});
