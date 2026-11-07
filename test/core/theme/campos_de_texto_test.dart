// Campos de texto com a aparência da tela Entrar, nos três temas
// (docs/features/padronizacao-campos.md).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/core/theme/app_palette.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';
import 'package:pet_connect/features/auth/presentation/screens/esqueci_senha_screen.dart';
import 'package:pet_connect/features/auth/presentation/screens/login_screen.dart';
import 'package:pet_connect/features/auth/presentation/widgets/auth_theme_scope.dart';

import '../../helpers/fonte_roboto.dart';

AppPalette _paleta(AppThemeMode modo) =>
    AppTheme.build(modo).extension<AppPalette>()!;

/// A borda que o `InputDecorator` está desenhando agora.
OutlineInputBorder _bordaDesenhada(WidgetTester tester, Finder campo) {
  final decorador = tester.widget<InputDecorator>(
      find.descendant(of: campo, matching: find.byType(InputDecorator)));
  final d = decorador.decoration;
  final InputBorder? borda;
  if (d.enabled == false) {
    borda = d.disabledBorder;
  } else if (decorador.isFocused) {
    borda = d.errorText != null ? d.focusedErrorBorder : d.focusedBorder;
  } else {
    borda = d.errorText != null ? d.errorBorder : d.enabledBorder;
  }
  return (borda ?? d.border)! as OutlineInputBorder;
}

void main() {
  setUpAll(carregarRoboto);

  for (final modo in AppThemeMode.values) {
    test('tema ${modo.name}: borda, raio e foco iguais aos da tela Entrar', () {
      final paleta = _paleta(modo);
      final tema = AppTheme.build(modo).inputDecorationTheme;
      final normal = tema.enabledBorder! as OutlineInputBorder;
      final foco = tema.focusedBorder! as OutlineInputBorder;

      expect(normal.borderRadius, BorderRadius.circular(16));
      expect(
          normal.borderSide.color, paleta.brandLight.withValues(alpha: 0.45));
      expect(normal.borderSide.width, 1);
      expect(foco.borderRadius, BorderRadius.circular(16));
      expect(foco.borderSide.color, paleta.brandDark);
      expect(foco.borderSide.width, 1.5);
      expect(tema.border, normal, reason: 'erro parte da mesma borda');
      expect(tema.filled, isTrue);
      expect(tema.fillColor, paleta.surface);
      expect(tema.hintStyle!.color, paleta.textMuted);
    });

    testWidgets(
        'tema ${modo.name}: repouso, foco, erro e desabilitado num '
        'formulário interno', (tester) async {
      final paleta = _paleta(modo);
      final validar = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(modo),
        home: Scaffold(
          body: Form(
            key: validar,
            child: Column(children: [
              TextFormField(
                key: const ValueKey('nome'),
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v ?? '').isEmpty ? 'Obrigatório' : null,
              ),
              const TextField(
                key: ValueKey('desligado'),
                enabled: false,
                decoration: InputDecoration(labelText: 'Desligado'),
              ),
            ]),
          ),
        ),
      ));

      final nome = find.byKey(const ValueKey('nome'));
      final repouso = _bordaDesenhada(tester, nome);
      expect(
          repouso.borderSide.color, paleta.brandLight.withValues(alpha: 0.45));

      await tester.tap(nome);
      await tester.pump();
      final foco = _bordaDesenhada(tester, nome);
      expect(foco.borderSide.color, paleta.brandDark);
      expect(foco.borderSide.width, 1.5);

      // O erro aparece embaixo, com a validação de antes, e o texto
      // digitado continua.
      validar.currentState!.validate();
      await tester.pump();
      expect(find.text('Obrigatório'), findsOneWidget);
      await tester.enterText(nome, 'Rex');
      expect(validar.currentState!.validate(), isTrue);
      expect(find.text('Rex'), findsOneWidget);

      final desligado =
          _bordaDesenhada(tester, find.byKey(const ValueKey('desligado')));
      expect(
          desligado.borderSide.color, paleta.brandLight.withValues(alpha: 0.2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      '"Esqueceu sua senha?": o campo tem a borda e a altura do e-mail da '
      'tela Entrar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<OutlineInputBorder> abrir(Widget tela, String dica) async {
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => AuthThemeScope(child: tela)),
      ]);
      await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      return _bordaDesenhada(tester, find.widgetWithText(TextField, dica));
    }

    final bordaDoLogin = await abrir(const LoginScreen(), 'E-mail:');
    final alturaDoLogin =
        tester.getSize(find.widgetWithText(TextField, 'E-mail:')).height;

    final bordaDaRecuperacao =
        await abrir(const EsqueciSenhaScreen(), 'E-mail:');
    final alturaDaRecuperacao =
        tester.getSize(find.widgetWithText(TextField, 'E-mail:')).height;

    expect(bordaDaRecuperacao.borderSide, bordaDoLogin.borderSide);
    expect(bordaDaRecuperacao.borderRadius, bordaDoLogin.borderRadius);
    expect(alturaDaRecuperacao, alturaDoLogin);
  });
}
