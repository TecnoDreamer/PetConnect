import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/cadastro_screen.dart';
import '../features/auth/presentation/screens/esqueci_senha_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/widgets/auth_theme_scope.dart';

const authRoutePaths = ['/login', '/cadastro', '/esqueci-senha'];

/// Rotas de autenticação, todas sob [AuthThemeScope]: a aparência delas não
/// depende do tema escolhido pelo tutor (inclusive logo após o logout, com
/// a preferência ainda em Escuro).
List<GoRoute> buildAuthRoutes() => [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthThemeScope(child: LoginScreen()),
      ),
      GoRoute(
        path: '/cadastro',
        builder: (context, state) =>
            const AuthThemeScope(child: CadastroScreen()),
      ),
      GoRoute(
        path: '/esqueci-senha',
        builder: (context, state) =>
            const AuthThemeScope(child: EsqueciSenhaScreen()),
      ),
    ];
