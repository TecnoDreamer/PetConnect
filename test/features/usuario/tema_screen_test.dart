// Testa a tela de seleção de tema (RF de aparência, 2026-09-13): mostra
// as 3 opções, indica a selecionada sem depender só de cor, e trocar
// aplica de verdade (via themeModeProvider).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';
import 'package:pet_connect/core/theme/theme_providers.dart';
import 'package:pet_connect/features/usuario/presentation/screens/tema_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(theme: AppTheme.light(), home: const TemaScreen()),
  );
}

/// Igual a [_app], mas expõe o [ProviderContainer] usado por dentro — pra
/// testes que precisam ler o estado do provider diretamente, sem precisar
/// de um `BuildContext` descendente do `ProviderScope`.
Future<(Widget, ProviderContainer)> _appComContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  final app = UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light(), home: const TemaScreen()),
  );
  return (app, container);
}

void main() {
  group('TemaScreen', () {
    testWidgets('mostra as 3 opções de tema', (tester) async {
      await tester.pumpWidget(await _app());

      expect(find.text('Padrão'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Escuro'), findsOneWidget);
    });

    testWidgets('sem preferência salva, Claro vem selecionado (Semantics)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(await _app());

      expect(find.bySemanticsLabel('Tema Claro, selecionado'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tocar em Escuro troca o tema de verdade', (tester) async {
      final (app, container) = await _appComContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Escuro'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), AppThemeMode.escuro);
    });

    testWidgets(
        'depois de trocar, o novo modo aparece marcado como selecionado',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(await _app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Tema Claro, selecionado'), findsOneWidget);
      expect(find.bySemanticsLabel('Tema Padrão, selecionado'), findsNothing);
      handle.dispose();
    });
  });
}
