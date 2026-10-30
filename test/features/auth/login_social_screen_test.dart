// Botão "Entrar com Google" da tela de Login (docs/features/login-social.md):
// carregamento, proteção contra toque repetido, mensagens em português e
// vinculação de conta existente. Repositório falso, sem SDK.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/features/auth/presentation/screens/login_screen.dart';
import 'package:pet_connect/features/usuario/domain/login_social.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/domain/usuario_repository.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

class _FakeRepo implements UsuarioRepository {
  /// Erro de `entrarComProvedor`; nulo = entra.
  Object? erroSocial;

  /// Segura `entrarComProvedor` até completar, para ver o carregamento.
  Completer<void>? segurar;
  Object? erroAoVincular;

  final entradas = <ProvedorSocial>[];
  final vinculosComSenha = <({String email, String senha})>[];
  int loginsComSenha = 0;

  @override
  Future<void> entrarComProvedor(ProvedorSocial provedor) async {
    entradas.add(provedor);
    if (segurar != null) await segurar!.future;
    if (erroSocial != null) throw erroSocial!;
  }

  @override
  Future<void> entrarComSenhaEVincular({
    required String email,
    required String senha,
    required ContaExisteComOutroMetodo pendente,
  }) async {
    vinculosComSenha.add((email: email, senha: senha));
    if (erroAoVincular != null) throw erroAoVincular!;
  }

  @override
  Future<void> signIn(
          {required String email, required String password}) async =>
      loginsComSenha++;

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

final _google = find.widgetWithText(OutlinedButton, 'Entrar com Google');
final _entrar = find.widgetWithText(ElevatedButton, 'ENTRAR');

bool _habilitado(WidgetTester tester, Finder botao) =>
    tester.widget<ButtonStyleButton>(botao).onPressed != null;

Future<void> _abrir(WidgetTester tester, _FakeRepo repo) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [usuarioRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

const _pendente = ContaExisteComOutroMetodo(
  provedor: ProvedorSocial.google,
  email: 'ana@teste.com',
  credencialPendente: 'credencial-teste',
);

void main() {
  testWidgets('não há mais botão do Facebook', (tester) async {
    await _abrir(tester, _FakeRepo());

    expect(find.textContaining('Facebook'), findsNothing);
    expect(_google, findsOneWidget);
  });

  group('carregamento e toques repetidos', () {
    testWidgets('Google em andamento: carregamento no botão e ENTRAR bloqueado',
        (tester) async {
      final repo = _FakeRepo()..segurar = Completer<void>();
      await _abrir(tester, repo);

      await tester.tap(_google);
      await tester.pump();

      expect(
          find.descendant(
              of: _google, matching: find.byType(CircularProgressIndicator)),
          findsOneWidget);
      expect(_habilitado(tester, _google), isFalse);
      expect(_habilitado(tester, _entrar), isFalse);

      repo.segurar!.complete();
      await tester.pumpAndSettle();
      expect(_habilitado(tester, _google), isTrue);
      expect(_habilitado(tester, _entrar), isTrue);
    });

    testWidgets('toque duplo no Google faz um só login', (tester) async {
      final repo = _FakeRepo()..segurar = Completer<void>();
      await _abrir(tester, repo);

      await tester.tap(_google);
      await tester.tap(_google, warnIfMissed: false);
      await tester.tap(_entrar, warnIfMissed: false);
      await tester.pump();
      repo.segurar!.complete();
      await tester.pumpAndSettle();

      expect(repo.entradas, [ProvedorSocial.google]);
      expect(repo.loginsComSenha, 0);
    });
  });

  group('mensagens', () {
    testWidgets('cancelado pelo tutor: nenhuma mensagem', (tester) async {
      final repo = _FakeRepo()
        ..erroSocial = const LoginSocialCancelado(ProvedorSocial.google);
      await _abrir(tester, repo);

      await tester.tap(_google);
      await tester.pumpAndSettle();

      expect(find.textContaining('Google'), findsOneWidget,
          reason: 'só o rótulo do botão');
      expect(_habilitado(tester, _google), isTrue);
    });

    final casos = <String, (Object, String)>{
      'sem configuração': (
        const LoginSocialIndisponivel(ProvedorSocial.google),
        'Entrar com o Google ainda não está disponível nesta versão.',
      ),
      'falha do provedor': (
        const LoginSocialFalhou(ProvedorSocial.google),
        'Não foi possível entrar com o Google. Tente novamente.',
      ),
      'token expirado ou revogado': (
        FirebaseAuthException(code: 'invalid-credential'),
        'O Google não confirmou o login. Tente novamente.',
      ),
      'sem internet': (
        FirebaseAuthException(code: 'network-request-failed'),
        'Falha de conexão. Verifique sua internet.',
      ),
      'conta desativada': (
        FirebaseAuthException(code: 'user-disabled'),
        'Esta conta está desativada.',
      ),
    };
    casos.forEach((nome, caso) {
      final (erro, mensagem) = caso;
      testWidgets('$nome: "$mensagem"', (tester) async {
        final repo = _FakeRepo()..erroSocial = erro;
        await _abrir(tester, repo);
        final tituloAntes = tester.getTopLeft(find.text('Entrar'));

        await tester.tap(_google);
        await tester.pumpAndSettle();

        expect(find.text(mensagem), findsOneWidget);
        expect(tester.getTopLeft(find.text('Entrar')), tituloAntes,
            reason: 'a mensagem usa o espaço reservado no card');
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('conta existente por e-mail e senha', () {
    testWidgets('senha da conta existente: vincula o Google a ela',
        (tester) async {
      final repo = _FakeRepo()..erroSocial = _pendente;
      await _abrir(tester, repo);

      await tester.tap(_google);
      await tester.pumpAndSettle();

      expect(find.text('Você já tem uma conta'), findsOneWidget);
      expect(find.textContaining('ana@teste.com'), findsOneWidget);
      final confirmar =
          find.widgetWithText(FilledButton, 'Entrar com senha e ligar');
      expect(_habilitado(tester, confirmar), isFalse,
          reason: 'sem senha não confirma');

      await tester.enterText(
          find.widgetWithText(TextField, 'Senha da conta'), 'minha-senha');
      await tester.pump();
      await tester.tap(confirmar);
      await tester.pumpAndSettle();

      expect(repo.vinculosComSenha.single,
          (email: 'ana@teste.com', senha: 'minha-senha'));
      expect(find.text('Você já tem uma conta'), findsNothing);
    });

    testWidgets('senha errada: avisa sem revelar mais nada', (tester) async {
      final repo = _FakeRepo()
        ..erroSocial = _pendente
        ..erroAoVincular = FirebaseAuthException(code: 'wrong-password');
      await _abrir(tester, repo);

      await tester.tap(_google);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Senha da conta'), 'errada');
      await tester.pump();
      await tester
          .tap(find.widgetWithText(FilledButton, 'Entrar com senha e ligar'));
      await tester.pumpAndSettle();

      expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
    });

    testWidgets('cancelar: nada é vinculado nem mostrado', (tester) async {
      final repo = _FakeRepo()..erroSocial = _pendente;
      await _abrir(tester, repo);

      await tester.tap(_google);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.vinculosComSenha, isEmpty);
      expect(_habilitado(tester, _google), isTrue);
    });
  });

  testWidgets('login por e-mail continua igual e não dispara o Google',
      (tester) async {
    final repo = _FakeRepo();
    await _abrir(tester, repo);

    await tester.enterText(
        find.widgetWithText(TextField, 'E-mail:'), 'ana@teste.com');
    await tester.enterText(find.widgetWithText(TextField, 'Senha:'), '123456');
    await tester.tap(_entrar);
    await tester.pumpAndSettle();

    expect(repo.loginsComSenha, 1);
    expect(repo.entradas, isEmpty);
  });
}
