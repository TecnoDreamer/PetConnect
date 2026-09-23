// Testes de regressão do layout da tela de Login (seção 25 de
// prompt_correcao_layout_login_estatico.md, 2026-09-14): o card branco
// tinha overflow real de rolagem em aparelhos comuns, o que fazia o card
// "descolar" do cabeçalho marrom ao arrastar — a tela precisa ser
// visualmente estática, com o card sempre sobreposto na frente.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/widgets/auth_header.dart';
import 'package:pet_connect/features/auth/presentation/screens/login_screen.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/domain/usuario_repository.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

class _FakeUsuarioRepository implements UsuarioRepository {
  _FakeUsuarioRepository({this.erroAoLogar, this.aguardarAntes});

  /// Se definido, `signIn` lança este erro em vez de completar.
  final Object? erroAoLogar;

  /// Se definido, `signIn` só resolve depois que este completer for
  /// completado — segura o estado de loading tempo suficiente pra ser
  /// observado no teste.
  final Completer<void>? aguardarAntes;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (aguardarAntes != null) await aguardarAntes!.future;
    if (erroAoLogar != null) throw erroAoLogar!;
  }

  @override
  Stream<Usuario?> watchUsuario(String uid) => throw UnimplementedError();

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
  Future<void> signOut() => throw UnimplementedError();

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

Widget _appPara(_FakeUsuarioRepository repo) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/esqueci-senha',
        builder: (context, state) =>
            const Scaffold(body: Text('Tela Esqueci Senha')),
      ),
      GoRoute(
        path: '/cadastro',
        builder: (context, state) =>
            const Scaffold(body: Text('Tela Cadastro')),
      ),
      GoRoute(path: '/home', builder: (context, state) => const Text('Home')),
    ],
  );

  return ProviderScope(
    overrides: [usuarioRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Abre a tela com uma altura de viewport realista (mesma convenção de
/// cadastro_screen_test.dart — a viewport padrão de teste do Flutter,
/// 800x600, é mais baixa que qualquer aparelho real suportado).
Future<void> _abrirTela(
    WidgetTester tester, _FakeUsuarioRepository repo) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_appPara(repo));
}

void main() {
  group('LoginScreen — layout estático (sem rolagem)', () {
    // Os 3 tamanhos listados na seção 22 do documento-fonte em que é
    // realista exigir zero rolagem — em 320x568 (o 4º tamanho da lista,
    // um aparelho muito antigo/pequeno) o logo de 160px sozinho já ocupa
    // ~28% da altura da tela, e o documento proíbe explicitamente alterar
    // o logo (seção 3) — ver a exceção documentada no teste seguinte.
    for (final tamanho in [
      const Size(360, 800), // Android muito comum
      const Size(390, 844), // iPhone 12/13/14
      const Size(412, 915), // Pixel comum
    ]) {
      testWidgets(
          'não tem nenhuma extensão de rolagem em ${tamanho.width.toInt()}x${tamanho.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = tamanho;
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(top: 30, bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);

        await tester.pumpWidget(_appPara(_FakeUsuarioRepository()));
        await tester.pumpAndSettle();

        final posicao = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        expect(posicao.maxScrollExtent, 0,
            reason: 'a tela não deveria depender de rolagem neste tamanho');
      });
    }

    testWidgets(
        'a tela nunca é arrastável, mesmo em 320x568 (aparelho muito pequeno, limitação aceita e documentada)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_appPara(_FakeUsuarioRepository()));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final physics = tester.widget<Scrollable>(scrollable).physics;
      expect(physics, isA<NeverScrollableScrollPhysics>(),
          reason: 'mesmo sem caber 100%, a tela nunca pode virar arrastável');
    });
  });

  group('LoginScreen — sobreposição', () {
    testWidgets('o card branco cobre visualmente a base do cabeçalho marrom',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      final baseCabecalho = tester.getBottomLeft(find.byType(AuthHeader)).dy;
      final topoCard = tester.getTopLeft(find.text('Login')).dy;

      expect(topoCard, lessThan(baseCabecalho),
          reason: 'o título "Login" do card deveria aparecer acima da base do '
              'cabeçalho — prova de que o card está sobreposto na frente, '
              'não abaixo/atrás dele');
      expect(tester.takeException(), isNull);
    });
  });

  group('LoginScreen — teclado', () {
    testWidgets('foco no e-mail mantém os campos acessíveis', (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextField, 'E-mail:'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'E-mail:'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Senha:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('foco na senha mantém os campos acessíveis', (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextField, 'Senha:'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'E-mail:'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Senha:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'fechar o teclado restaura exatamente a posição original do card',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      final posicaoOriginal = tester.getTopLeft(find.text('Login'));

      await tester.tap(find.widgetWithText(TextField, 'E-mail:'));
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final posicaoDepois = tester.getTopLeft(find.text('Login'));
      expect(posicaoDepois, posicaoOriginal,
          reason: 'o card deveria voltar exatamente à posição original '
              'depois de fechar o teclado');
    });
  });

  group('LoginScreen — estados não movem o card indevidamente', () {
    testWidgets('renderização normal mostra todos os elementos na ordem',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      expect(find.byType(AuthHeader), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'E-mail:'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Senha:'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'ENTRAR'), findsOneWidget);
      expect(find.text('Esqueceu a senha?'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('Cadastre-se'), findsOneWidget);

      final ordemY = [
        tester.getTopLeft(find.byType(AuthHeader)).dy,
        tester.getTopLeft(find.text('Login')).dy,
        tester.getTopLeft(find.widgetWithText(ElevatedButton, 'ENTRAR')).dy,
        tester.getTopLeft(find.text('Google')).dy,
        tester.getTopLeft(find.text('Cadastre-se')).dy,
      ];
      for (var i = 1; i < ordemY.length; i++) {
        expect(ordemY[i], greaterThanOrEqualTo(ordemY[i - 1]),
            reason: 'a ordem vertical dos elementos deveria ser sempre '
                'cabeçalho → Login → Entrar → Google → Cadastre-se');
      }
    });

    testWidgets('mostrar/ocultar senha não move o card', (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      final posicaoAntes = tester.getTopLeft(find.text('Login'));

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      final posicaoDepois = tester.getTopLeft(find.text('Login'));
      expect(posicaoDepois, posicaoAntes,
          reason: 'alternar a visibilidade da senha não deveria mover o '
              'card — o campo só troca o ícone, não o tamanho');
    });

    testWidgets('estado de carregamento mostra o spinner sem mover o card',
        (tester) async {
      final gate = Completer<void>();
      final repo = _FakeUsuarioRepository(aguardarAntes: gate);
      await _abrirTela(tester, repo);
      await tester.pumpAndSettle();

      final posicaoAntes = tester.getTopLeft(find.text('Login'));

      await tester.enterText(
          find.widgetWithText(TextField, 'E-mail:'), 'ana@teste.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Senha:'), 'qualquer');
      await tester.tap(find.widgetWithText(ElevatedButton, 'ENTRAR'));
      await tester.pump(); // um frame: signIn ainda preso no gate

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final posicaoDepois = tester.getTopLeft(find.text('Login'));
      expect(posicaoDepois, posicaoAntes,
          reason: 'o loading não deveria reposicionar a tela');

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'erro de login mostra a mensagem sem causar salto excessivo de layout',
        (tester) async {
      final repo = _FakeUsuarioRepository(
        erroAoLogar: FirebaseAuthException(code: 'wrong-password'),
      );
      await _abrirTela(tester, repo);
      await tester.pumpAndSettle();

      final posicaoAntes = tester.getTopLeft(find.text('Login'));

      await tester.enterText(
          find.widgetWithText(TextField, 'E-mail:'), 'ana@teste.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Senha:'), 'senhaErrada');
      await tester.tap(find.widgetWithText(ElevatedButton, 'ENTRAR'));
      await tester.pumpAndSettle();

      expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);

      final posicaoDepois = tester.getTopLeft(find.text('Login'));
      // O título "Login" fica ACIMA da mensagem de erro — não deveria se
      // mexer nada com o erro aparecendo abaixo dele.
      expect(posicaoDepois, posicaoAntes,
          reason: 'o título do card não deveria se mover com o erro');
    });
  });
}
