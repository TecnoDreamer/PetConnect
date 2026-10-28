// Telas de autenticação imunes ao tema do tutor (docs/features/auth-theme.md).
// Usa as rotas reais de autenticação (buildAuthRoutes) — as mesmas que o
// app registra em app_router.dart.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_palette.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';
import 'package:pet_connect/core/theme/theme_providers.dart';
import 'package:pet_connect/features/usuario/domain/login_social.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/domain/usuario_repository.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';
import 'package:pet_connect/routing/auth_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUsuarioRepository implements UsuarioRepository {
  @override
  Future<void> signIn(
      {required String email, required String password}) async {}

  @override
  Future<void> signUp({
    required String nome,
    required String email,
    required String password,
    required String telefone,
    required String dataNascimento,
  }) async {}

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  @override
  Stream<Usuario?> watchUsuario(String uid) => throw UnimplementedError();

  @override
  Future<void> entrarComProvedor(ProvedorSocial provedor) =>
      throw UnimplementedError();

  @override
  Future<void> entrarComSenhaEVincular({
    required String email,
    required String senha,
    required ContaExisteComOutroMetodo pendente,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> entrarComProvedorEVincular(
    ProvedorSocial provedor,
    ContaExisteComOutroMetodo pendente,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> updateUsuario({
    required String nome,
    required String sobrenome,
    required String telefone,
    required String dataNascimento,
    required String genero,
    String? foto,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount() => throw UnimplementedError();
}

/// Tela autenticada mínima: um campo que herda o tema do app, como os
/// formulários reais da área logada.
class _HomeFalsa extends StatelessWidget {
  const _HomeFalsa();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: TextField(key: Key('campo-home'))));
}

class _App {
  _App(this.router, this.container);

  final GoRouter router;
  final ProviderContainer container;
}

Future<_App> _abrir(
  WidgetTester tester, {
  required AppThemeMode preferenciaSalva,
  String rotaInicial = '/login',
  Size tamanho = const Size(412, 915),
  double escala = 1.0,
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  SharedPreferences.setMockInitialValues({'tema_app': preferenciaSalva.name});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: rotaInicial,
    routes: [
      ...buildAuthRoutes(),
      GoRoute(path: '/home', builder: (context, state) => const _HomeFalsa()),
    ],
  );
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    usuarioRepositoryProvider.overrideWithValue(_FakeUsuarioRepository()),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: Consumer(
      // Mesmo arranjo de app.dart: um único `theme:` dinâmico pelo modo.
      builder: (context, ref, _) => MaterialApp.router(
        theme: AppTheme.build(ref.watch(themeModeProvider)),
        routerConfig: router,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return _App(router, container);
}

/// Campos claros, texto escuro e paleta original — o que o tutor vê na
/// identidade aprovada, independentemente do tema global.
void _esperarIdentidadeOriginal(WidgetTester tester) {
  final campo = find.byType(EditableText).first;
  final tema = Theme.of(tester.element(campo));
  expect(tema.brightness, Brightness.light);
  expect(tema.extension<AppPalette>(), same(AppPalette.padrao));

  final fundoDoCampo =
      tester.widget<InputDecorator>(find.byType(InputDecorator).first);
  expect(
      fundoDoCampo.decoration.fillColor!.computeLuminance(), greaterThan(0.7),
      reason: 'fundo do campo deveria ser claro');

  final texto = tester.widget<EditableText>(campo).style.color!;
  expect(texto.computeLuminance(), lessThan(0.2),
      reason: 'texto digitado deveria ser escuro');

  expect(
    find.byWidgetPredicate((w) =>
        w is AnnotatedRegion<SystemUiOverlayStyle> &&
        w.value == SystemUiOverlayStyle.dark),
    findsOneWidget,
    reason: 'ícones da status bar escuros sobre o fundo claro',
  );
}

void main() {
  group('Telas de autenticação ignoram o tema do tutor', () {
    for (final modo in AppThemeMode.values) {
      for (final rota in authRoutePaths) {
        testWidgets('$rota com preferência ${modo.name}', (tester) async {
          await _abrir(tester, preferenciaSalva: modo, rotaInicial: rota);

          _esperarIdentidadeOriginal(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Tema escuro → logout → login', () {
    testWidgets(
        'login abre claro, a preferência continua Escuro e a área logada '
        'volta a usá-la ao entrar de novo', (tester) async {
      final app = await _abrir(tester,
          preferenciaSalva: AppThemeMode.escuro, rotaInicial: '/home');

      final temaHome =
          Theme.of(tester.element(find.byKey(const Key('campo-home'))));
      expect(temaHome.extension<AppPalette>(), same(AppPalette.escuro));

      // Logout: o redirect do app_router leva para /login.
      app.router.go('/login');
      await tester.pumpAndSettle();
      _esperarIdentidadeOriginal(tester);

      final prefs = app.container.read(sharedPreferencesProvider);
      expect(prefs.getString('tema_app'), AppThemeMode.escuro.name,
          reason: 'o logout não pode apagar a preferência de tema');
      expect(app.container.read(themeModeProvider), AppThemeMode.escuro);

      // Login de novo.
      app.router.go('/home');
      await tester.pumpAndSettle();
      final temaHomeDepois =
          Theme.of(tester.element(find.byKey(const Key('campo-home'))));
      expect(temaHomeDepois.extension<AppPalette>(), same(AppPalette.escuro));
    });

    testWidgets('trocar o tema repetidamente não altera o login',
        (tester) async {
      final app = await _abrir(tester, preferenciaSalva: AppThemeMode.escuro);
      final controller = app.container.read(themeModeProvider.notifier);

      for (final modo in [
        AppThemeMode.claro,
        AppThemeMode.escuro,
        AppThemeMode.padrao,
        AppThemeMode.escuro,
      ]) {
        await controller.definir(modo);
        await tester.pumpAndSettle();
        _esperarIdentidadeOriginal(tester);
      }
    });

    testWidgets('alternar entre login, cadastro e esqueci senha no escuro',
        (tester) async {
      final app = await _abrir(tester, preferenciaSalva: AppThemeMode.escuro);

      for (final rota in ['/cadastro', '/login', '/esqueci-senha', '/login']) {
        app.router.go(rota);
        await tester.pumpAndSettle();
        _esperarIdentidadeOriginal(tester);
      }
    });
  });

  group('Tema escuro: sem overflow nas telas de autenticação', () {
    for (final tamanho in const [
      Size(320, 568),
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
    ]) {
      for (final escala in const [1.0, 1.3]) {
        testWidgets('$tamanho, fonte $escala', (tester) async {
          final app = await _abrir(tester,
              preferenciaSalva: AppThemeMode.escuro,
              tamanho: tamanho,
              escala: escala);

          for (final rota in authRoutePaths) {
            app.router.go(rota);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: rota);

            // Teclado aberto e fechado.
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$rota + teclado');
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
            _esperarIdentidadeOriginal(tester);
          }
        });
      }
    }
  });
}
