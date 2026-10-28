// Testes de widget do redesign da tela de Cadastro (seção 29 de
// prompt_redesign_tela_cadastro_petconnect.md).
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/features/auth/presentation/screens/cadastro_screen.dart';
import 'package:pet_connect/features/usuario/domain/login_social.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/domain/usuario_repository.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

import '../../helpers/fonte_roboto.dart';

class _FakeUsuarioRepository implements UsuarioRepository {
  _FakeUsuarioRepository({this.erroAoCadastrar, this.aguardarAntes});

  /// Se definido, `signUp` lança este erro em vez de completar.
  final Object? erroAoCadastrar;

  /// Se definido, `signUp` só resolve depois que este completer for
  /// completado — usado pra segurar o estado de loading tempo suficiente
  /// pra ser observado no teste (um fake que resolve na mesma sequência
  /// de microtasks do `pump()` some rápido demais pra ser visto).
  final Completer<void>? aguardarAntes;

  bool cadastrado = false;
  String? nomeRecebido;
  String? emailRecebido;
  String? telefoneRecebido;
  String? senhaRecebida;

  @override
  Future<void> signUp({
    required String nome,
    required String email,
    required String password,
    required String telefone,
    required String dataNascimento,
  }) async {
    if (aguardarAntes != null) await aguardarAntes!.future;
    if (erroAoCadastrar != null) throw erroAoCadastrar!;
    cadastrado = true;
    nomeRecebido = nome;
    emailRecebido = email;
    telefoneRecebido = telefone;
    senhaRecebida = password;
  }

  @override
  Stream<Usuario?> watchUsuario(String uid) => throw UnimplementedError();

  @override
  Future<void> signIn({required String email, required String password}) =>
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
    initialLocation: '/cadastro',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const Text('Login')),
      GoRoute(
        path: '/cadastro',
        builder: (context, state) => const CadastroScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [usuarioRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Abre a tela com uma altura de viewport realista — a viewport padrão de
/// teste do Flutter (800x600) é mais baixa que qualquer aparelho real
/// suportado (mesma convenção de pet_management_test.dart). O grupo
/// "responsividade" abaixo usa seu próprio tamanho (pequeno de propósito,
/// pra testar o limite), sem passar por este helper.
Future<void> _abrirTela(
    WidgetTester tester, _FakeUsuarioRepository repo) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_appPara(repo));
}

/// Preenche todos os campos com dados válidos, exceto os informados em
/// [exceto].
Future<void> _preencherTudoValido(
  WidgetTester tester, {
  String nome = 'Maria Silva',
  String email = 'maria@dominio.com',
  String telefone = '19997150817',
  String senha = 'PetConnect@9',
  String? confirmarSenha,
}) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome completo').first, nome);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail').first, email);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Telefone').first, telefone);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha').first, senha);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar senha').first,
      confirmarSenha ?? senha);
  await tester.pump();
}

void main() {
  // Roboto de verdade (não a fonte de teste, bem mais larga): os testes de
  // layout abaixo medem se a tela cabe sem rolagem em tamanhos reais.
  setUpAll(carregarRoboto);

  group('CadastroScreen — layout inicial', () {
    testWidgets(
        'mostra título, os 5 campos e o botão, sem exemplos redundantes',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      expect(find.text('Crie sua conta'), findsOneWidget);
      expect(find.text('Cadastre seus dados para começar.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(5));
      expect(
          find.widgetWithText(ElevatedButton, 'CRIAR CONTA'), findsOneWidget);

      // Exemplos redundantes removidos (seção 34 do briefing).
      expect(find.text('Ex: Maria Silva'), findsNothing);
      expect(find.text('seu@email.com'), findsNothing);
      expect(find.text('Repita a senha'), findsNothing);
    });

    testWidgets('botão CRIAR CONTA começa desabilitado', (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      final botao = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      expect(botao.onPressed, isNull);
    });
  });

  group('CadastroScreen — telefone', () {
    testWidgets('aplica máscara automaticamente enquanto digita',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Telefone').first, '19997150817');
      await tester.pump();

      expect(find.text('(19) 99715-0817'), findsOneWidget);
    });

    testWidgets('não aceita mais que 11 dígitos, mesmo colando um texto maior',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Telefone').first,
          '199971508171234567');
      await tester.pump();

      expect(find.text('(19) 99715-0817'), findsOneWidget);
    });
  });

  group('CadastroScreen — validação ao perder o foco', () {
    testWidgets('não mostra erro de e-mail antes de qualquer interação',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      expect(find.text('Informe um e-mail válido.'), findsNothing);
    });

    testWidgets('mostra "Informe um e-mail válido." só depois de sair do campo',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'E-mail').first, 'invalido');
      await tester.pump();
      expect(find.text('Informe um e-mail válido.'), findsNothing,
          reason: 'ainda não perdeu o foco');

      // Move o foco para o próximo campo — dispara a validação.
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Telefone').first, '');
      await tester.pump();

      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    });
  });

  group('CadastroScreen — checklist de senha', () {
    testWidgets(
        'já aparece antes de qualquer interação (senha vazia nunca atende aos requisitos)',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      expect(find.text('9 ou mais caracteres'), findsOneWidget);
      expect(find.text('Letra maiúscula'), findsOneWidget);
      expect(find.text('Caractere especial'), findsOneWidget);
    });

    testWidgets(
        'permanece visível mesmo sem foco enquanto a senha não atender aos requisitos',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha').first, '123');
      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail').first,
          ''); // tira o foco
      await tester.pump();

      expect(find.text('9 ou mais caracteres'), findsOneWidget);
    });

    testWidgets(
        'continua visível (altura fixa) quando a senha atende a tudo e perde o foco',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();
      final confirmarAntes = tester.getRect(_campo('Confirmar senha'));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha').first, 'PetConnect@9');
      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail').first,
          ''); // tira o foco
      await tester.pump();

      expect(find.text('9 ou mais caracteres'), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNothing,
          reason: 'todos os requisitos marcados como atendidos');
      expect(tester.getRect(_campo('Confirmar senha')), confirmarAntes,
          reason: 'atender aos requisitos não pode deslocar os campos');
    });
  });

  group('CadastroScreen — confirmar senha', () {
    testWidgets('não mostra erro no primeiro caractere digitado',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha').first, 'PetConnect@9');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar senha').first, 'P');
      await tester.pump();

      expect(find.text('As senhas não coincidem.'), findsNothing);
    });

    testWidgets('mostra "As senhas não coincidem." quando diferentes',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha').first, 'PetConnect@9');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar senha').first,
          'PetConnect@8');
      await tester.pump();

      expect(find.text('As senhas não coincidem.'), findsOneWidget);
    });

    testWidgets('erro some assim que a confirmação é corrigida',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha').first, 'PetConnect@9');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar senha').first,
          'PetConnect@8');
      await tester.pump();
      expect(find.text('As senhas não coincidem.'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar senha').first,
          'PetConnect@9');
      await tester.pump();

      expect(find.text('As senhas não coincidem.'), findsNothing);
      // Dentro do campo: a checklist de senha (sempre visível) também usa
      // check_circle para cada requisito atendido.
      expect(
          find.descendant(
              of: _campo('Confirmar senha'),
              matching: find.byIcon(Icons.check_circle)),
          findsOneWidget);
    });
  });

  group('CadastroScreen — botão CRIAR CONTA', () {
    testWidgets('habilita quando todos os campos estão válidos',
        (tester) async {
      await _abrirTela(tester, _FakeUsuarioRepository());
      await tester.pumpAndSettle();

      await _preencherTudoValido(tester);

      final botao = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      expect(botao.onPressed, isNotNull);
    });

    testWidgets('chama signUp com os dados preenchidos e navega ao concluir',
        (tester) async {
      final repo = _FakeUsuarioRepository();
      await _abrirTela(tester, repo);
      await tester.pumpAndSettle();

      await _preencherTudoValido(tester,
          nome: 'Maria Silva', email: 'maria@dominio.com');
      await tester.tap(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      await tester.pumpAndSettle();

      expect(repo.cadastrado, isTrue);
      expect(repo.nomeRecebido, 'Maria Silva');
      expect(repo.emailRecebido, 'maria@dominio.com');
      expect(repo.senhaRecebida, 'PetConnect@9');
    });

    testWidgets('mostra indicador de carregamento durante o cadastro',
        (tester) async {
      final gate = Completer<void>();
      final repo = _FakeUsuarioRepository(aguardarAntes: gate);
      await _abrirTela(tester, repo);
      await tester.pumpAndSettle();

      await _preencherTudoValido(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      await tester.pump(); // um frame: signUp ainda preso no gate

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('mostra mensagem amigável quando o e-mail já existe',
        (tester) async {
      final repo = _FakeUsuarioRepository(
        erroAoCadastrar: FirebaseAuthException(code: 'email-already-in-use'),
      );
      await _abrirTela(tester, repo);
      await tester.pumpAndSettle();

      await _preencherTudoValido(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      await tester.pumpAndSettle();

      expect(find.text('Já existe uma conta com este e-mail.'), findsOneWidget);
      expect(find.text('Login'), findsNothing,
          reason: 'erro não deveria navegar pra lugar nenhum');
    });

    testWidgets('mostra mensagem genérica para erro inesperado',
        (tester) async {
      final repo = _FakeUsuarioRepository(erroAoCadastrar: Exception('boom'));
      await _abrirTela(tester, repo);
      await tester.pumpAndSettle();

      await _preencherTudoValido(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      await tester.pumpAndSettle();

      expect(
          find.text('Não foi possível completar a operação. Tente novamente.'),
          findsOneWidget);
    });
  });

  // --- Correção de 2026-10-24 (docs/features/cadastro-layout-estatico.md) --

  group('CadastroScreen — layout estático e sobreposição', () {
    for (final tamanho in const [
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
    ]) {
      testWidgets('$tamanho: tudo visível, sem nenhuma rolagem',
          (tester) async {
        await _abrirEmAparelho(tester, tamanho);

        expect(tester.takeException(), isNull);
        _esperarSemRolagem();
        _esperarTudoDentroDaAreaUtil(tester, tamanho);
      });
    }

    testWidgets('412x915 com fonte do sistema em 1.3: continua sem rolagem',
        (tester) async {
      await _abrirEmAparelho(tester, const Size(412, 915), escala: 1.3);

      expect(tester.takeException(), isNull);
      _esperarSemRolagem();
      _esperarTudoDentroDaAreaUtil(tester, const Size(412, 915));
    });

    testWidgets('painel invade a base do cabeçalho e fica na frente dele',
        (tester) async {
      await _abrirEmAparelho(tester, const Size(360, 800));

      final cabecalho = tester.getRect(_cabecalho);
      final painel = tester.getRect(_painel);
      expect(painel.top, lessThan(cabecalho.bottom - 24),
          reason: 'o painel deveria invadir a área marrom');
      expect(painel.left, greaterThan(cabecalho.left));
      expect(painel.right, lessThan(cabecalho.right));

      // Na faixa em comum, quem está na frente recebe o toque (a ordem do
      // teste de toque é a inversa da ordem de pintura): tem que ser o
      // painel, e o cabeçalho nem chega a ser consultado.
      final pontoNaFaixaComum =
          Offset(painel.center.dx, (painel.top + cabecalho.bottom) / 2);
      final alvos = tester
          .hitTestOnBinding(pontoNaFaixaComum)
          .path
          .map((entrada) => entrada.target)
          .toList();
      expect(alvos, contains(tester.renderObject(_painel)));
      expect(alvos, isNot(contains(tester.renderObject(_cabecalho))));
    });

    testWidgets('logo nunca sobrepõe o botão Voltar', (tester) async {
      await _abrirEmAparelho(tester, const Size(412, 915));

      final voltar = tester.getRect(find.byTooltip('Voltar'));
      final logo = tester.getRect(find.byType(Image));
      expect(voltar.overlaps(logo), isFalse);
      expect(voltar.width, greaterThanOrEqualTo(48));
      expect(voltar.height, greaterThanOrEqualTo(48));
    });
  });

  group('CadastroScreen — nada se mexe sozinho', () {
    testWidgets('focar um campo (sem teclado) não move nada', (tester) async {
      await _abrirEmAparelho(tester, const Size(360, 800));
      final antes = _retrato(tester);

      for (final rotulo in _rotulos) {
        await tester.tap(_campo(rotulo));
        await tester.pumpAndSettle();
        expect(_retrato(tester), antes, reason: 'focar "$rotulo" moveu a tela');
      }
    });

    testWidgets('mostrar/ocultar senha não move nada', (tester) async {
      await _abrirEmAparelho(tester, const Size(360, 800));
      final antes = _retrato(tester);

      await tester.tap(find.byTooltip('Mostrar senha').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ocultar senha'), findsOneWidget);
      expect(_retrato(tester), antes);

      await tester.tap(find.byTooltip('Ocultar senha'));
      await tester.pumpAndSettle();
      expect(_retrato(tester), antes);
    });

    testWidgets('erros de validação aparecem sem deslocar os campos',
        (tester) async {
      await _abrirEmAparelho(tester, const Size(360, 800));
      final antes = _retrato(tester);

      await tester.enterText(_campo('E-mail'), 'invalido');
      await tester.enterText(_campo('Telefone'), '123');
      await tester.enterText(_campo('Senha'), 'abc');
      await tester.enterText(_campo('Confirmar senha'), 'x');
      await tester.enterText(_campo('Nome completo'), '');
      await tester.pumpAndSettle();

      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      expect(find.text('Informe um telefone válido.'), findsOneWidget);
      expect(find.text('Sua senha ainda não atende aos requisitos.'),
          findsOneWidget);
      expect(_retrato(tester), antes);
      expect(tester.takeException(), isNull);
    });

    testWidgets('erro geral do cadastro não desloca o botão', (tester) async {
      await _abrirEmAparelho(tester, const Size(360, 800),
          repo: _FakeUsuarioRepository(
            erroAoCadastrar:
                FirebaseAuthException(code: 'email-already-in-use'),
          ));
      await _preencherTudoValido(tester);
      await tester.pumpAndSettle();
      final antes = _retrato(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      await tester.pumpAndSettle();

      expect(find.text('Já existe uma conta com este e-mail.'), findsOneWidget);
      expect(_retrato(tester), antes);
    });

    testWidgets('loading não desloca o botão', (tester) async {
      final gate = Completer<void>();
      await _abrirEmAparelho(tester, const Size(360, 800),
          repo: _FakeUsuarioRepository(aguardarAntes: gate));
      await _preencherTudoValido(tester);
      await tester.pumpAndSettle();
      final antes = _retrato(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_retrato(tester), antes);

      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  group('CadastroScreen — teclado', () {
    testWidgets(
        'cada campo focado continua visível e com foco; fechar o teclado '
        'restaura exatamente o layout', (tester) async {
      await _abrirEmAparelho(tester, const Size(360, 800));
      final antes = _retrato(tester);
      const alturaTeclado = 300.0;

      for (final rotulo in _rotulos) {
        await tester.tap(_campo(rotulo));
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: alturaTeclado);
        await tester.pumpAndSettle();

        expect(_temFoco(tester, rotulo), isTrue,
            reason: 'abrir o teclado tirou o foco de "$rotulo"');
        final campo = tester.getRect(_campo(rotulo));
        expect(campo.top, greaterThanOrEqualTo(_barraStatus),
            reason: '"$rotulo" ficou atrás da status bar');
        expect(campo.bottom, lessThanOrEqualTo(800 - alturaTeclado),
            reason: '"$rotulo" ficou atrás do teclado');
        expect(tester.getSize(_cabecalho).height, antes['cabecalho']!.height,
            reason: 'o cabeçalho não deveria encolher com o teclado');
        expect(tester.takeException(), isNull);

        tester.view.resetViewInsets();
        await tester.pumpAndSettle();

        expect(find.byType(SingleChildScrollView), findsNothing,
            reason: 'sem teclado, a rolagem temporária tem que sumir');
        expect(_retrato(tester), antes,
            reason: 'fechar o teclado deveria restaurar o layout exato');
      }
    });
  });

  group('CadastroScreen — exceções documentadas (aparelho muito baixo)', () {
    for (final caso in const [
      (Size(320, 568), 1.0),
      (Size(360, 800), 1.3),
      (Size(320, 480), 1.6),
    ]) {
      testWidgets(
          '${caso.$1} com fonte ${caso.$2}: sem overflow e todos os campos '
          'alcançáveis', (tester) async {
        await _abrirEmAparelho(tester, caso.$1, escala: caso.$2);
        expect(tester.takeException(), isNull);

        for (final rotulo in _rotulos) {
          await tester.ensureVisible(_campo(rotulo));
          await tester.pumpAndSettle();
          await tester.tap(_campo(rotulo));
          await tester.pumpAndSettle();
          expect(_temFoco(tester, rotulo), isTrue);
        }
        await tester
            .ensureVisible(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'tela pequena com teclado aberto e checklist visível: sem overflow',
        (tester) async {
      await _abrirEmAparelho(tester, const Size(320, 480));

      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();

      await tester.ensureVisible(_campo('Senha'));
      await tester.pumpAndSettle();
      await tester.tap(_campo('Senha'));
      await tester.pumpAndSettle();

      expect(find.text('9 ou mais caracteres'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CadastroScreen — navegação', () {
    testWidgets('Voltar retorna para a tela anterior', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
              path: '/login', builder: (context, state) => const Text('Login')),
          GoRoute(
              path: '/cadastro',
              builder: (context, state) => const CadastroScreen()),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          usuarioRepositoryProvider.overrideWithValue(_FakeUsuarioRepository())
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      router.push('/cadastro');
      await tester.pumpAndSettle();
      expect(find.byType(CadastroScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(CadastroScreen), findsNothing);
      expect(find.text('Login'), findsOneWidget);
    });
  });
}

// --- Apoio aos testes de layout ---------------------------------------------

/// Barras do sistema de um Android comum: status bar + navegação por 3
/// botões (a mais alta das duas opções de navegação).
const _barraStatus = 24.0;
const _barraNavegacao = 48.0;

const _rotulos = [
  'Nome completo',
  'E-mail',
  'Telefone',
  'Senha',
  'Confirmar senha',
];

final _cabecalho = find.byKey(const ValueKey('cadastro-cabecalho'));
final _painel = find.byKey(const ValueKey('cadastro-painel'));

Finder _campo(String rotulo) =>
    find.widgetWithText(TextFormField, rotulo).first;

Future<void> _abrirEmAparelho(
  WidgetTester tester,
  Size tamanho, {
  double escala = 1.0,
  _FakeUsuarioRepository? repo,
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding =
      const FakeViewPadding(top: _barraStatus, bottom: _barraNavegacao);
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(_appPara(repo ?? _FakeUsuarioRepository()));
  await tester.pumpAndSettle();
}

/// Posição de tudo que o usuário enxerga como "estrutura" da tela — se
/// qualquer um destes mudar, a tela se mexeu.
Map<String, Rect> _retrato(WidgetTester tester) => {
      'cabecalho': tester.getRect(_cabecalho),
      'painel': tester.getRect(_painel),
      'logo': tester.getRect(find.byType(Image)),
      'titulo': tester.getRect(find.text('Crie sua conta')),
      for (final rotulo in _rotulos) rotulo: tester.getRect(_campo(rotulo)),
      'checklist': tester.getRect(find.text('Caractere especial')),
      'botao': tester.getRect(find.byType(ElevatedButton)),
    };

bool _temFoco(WidgetTester tester, String rotulo) => tester
    .widget<EditableText>(find.descendant(
        of: _campo(rotulo), matching: find.byType(EditableText)))
    .focusNode
    .hasFocus;

void _esperarSemRolagem() {
  expect(find.byType(SingleChildScrollView), findsNothing);
  expect(find.byType(ListView), findsNothing);
  expect(find.byType(CustomScrollView), findsNothing);
}

void _esperarTudoDentroDaAreaUtil(WidgetTester tester, Size tamanho) {
  final limiteInferior = tamanho.height - _barraNavegacao;
  final alvos = {
    'título': find.text('Crie sua conta'),
    'subtítulo': find.text('Cadastre seus dados para começar.'),
    for (final rotulo in _rotulos) rotulo: _campo(rotulo),
    'checklist': find.text('Caractere especial'),
    'botão': find.widgetWithText(ElevatedButton, 'CRIAR CONTA'),
    'painel': _painel,
  };
  for (final MapEntry(key: nome, value: alvo) in alvos.entries) {
    final r = tester.getRect(alvo);
    expect(r.top, greaterThanOrEqualTo(_barraStatus),
        reason: '$nome atrás da status bar');
    expect(r.bottom, lessThanOrEqualTo(limiteInferior),
        reason: '$nome atrás da barra de navegação');
    expect(r.left, greaterThanOrEqualTo(0), reason: '$nome cortado');
    expect(r.right, lessThanOrEqualTo(tamanho.width), reason: '$nome cortado');
  }
}
