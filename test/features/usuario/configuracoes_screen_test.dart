// Testa o novo padrão de menu das Configurações do Tutor (RF de
// tema/menus, 2026-09-13): sem subtítulos nos itens de navegação, ícone +
// título + chevron, linha inteira clicável, e o item novo "Tema do
// aplicativo" navegando de verdade.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/theme_providers.dart';
import 'package:pet_connect/features/usuario/domain/login_social.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/domain/usuario_repository.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';
import 'package:pet_connect/features/usuario/presentation/screens/configuracoes_screen.dart';
import 'package:pet_connect/features/usuario/presentation/screens/tema_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tutor = Usuario(
  id: 'uid-1',
  usuarioID: 'uid-1',
  nome: 'Ana',
  email: 'ana@teste.com',
  telefone: '',
  dataNascimento: '',
  genero: '',
);

class _FakeUsuarioRepository implements UsuarioRepository {
  bool signOutChamado = false;

  @override
  Stream<Usuario?> watchUsuario(String uid) => Stream.value(_tutor);

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signUp({
    required String nome,
    required String email,
    required String password,
    required String telefone,
    required String dataNascimento,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordReset({required String email}) =>
      throw UnimplementedError();

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
  Future<void> signOut() async => signOutChamado = true;

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

Future<Widget> _appPara(_FakeUsuarioRepository repo) async {
  // Só a navegação para "Tema do aplicativo" precisa disto de verdade, mas
  // não custa nada preparar em todos os testes.
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/configuracoes',
    routes: [
      GoRoute(
        path: '/configuracoes',
        builder: (context, state) => const ConfiguracoesScreen(),
      ),
      GoRoute(
        path: '/configuracoes/editar-perfil',
        builder: (context, state) =>
            const Scaffold(body: Text('Tela Editar Perfil')),
      ),
      GoRoute(
        path: '/configuracoes/tema',
        builder: (context, state) => const TemaScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      currentUsuarioProvider.overrideWith((ref) => Stream.value(_tutor)),
      usuarioRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  group('ConfiguracoesScreen — novo padrão de menu', () {
    testWidgets('mostra os itens esperados, sem subtítulos', (tester) async {
      await tester.pumpWidget(await _appPara(_FakeUsuarioRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.text('Tema do aplicativo'), findsOneWidget);
      expect(find.text('Sair da conta'), findsOneWidget);
      expect(find.text('Excluir conta'), findsOneWidget);

      // Subtítulos antigos não existem mais (seção 17 do briefing).
      expect(find.text('Nome, telefone e foto'), findsNothing);
      expect(find.text('Remove sua conta e todos os seus pets permanentemente'),
          findsNothing);
    });

    testWidgets('Editar perfil abre a tela de edição', (tester) async {
      await tester.pumpWidget(await _appPara(_FakeUsuarioRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Tela Editar Perfil'), findsOneWidget);
    });

    testWidgets('Tema do aplicativo abre o seletor de tema de verdade',
        (tester) async {
      await tester.pumpWidget(await _appPara(_FakeUsuarioRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tema do aplicativo'));
      await tester.pumpAndSettle();

      expect(find.byType(TemaScreen), findsOneWidget);
      expect(find.text('Padrão'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Escuro'), findsOneWidget);
    });

    testWidgets('Sair da conta pede confirmação e chama o repositório',
        (tester) async {
      final repo = _FakeUsuarioRepository();
      await tester.pumpWidget(await _appPara(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      expect(find.text('Tem certeza que deseja sair da sua conta?'),
          findsOneWidget);

      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(repo.signOutChamado, isTrue);
    });
  });
}
