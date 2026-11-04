// O app em português do Brasil: textos do Flutter, calendário e relógio
// (docs/features/idioma-portugues.md).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_connect/app.dart';
import 'package:pet_connect/core/config/idioma.dart';
import 'package:pet_connect/core/theme/theme_providers.dart';
import 'package:pet_connect/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O app de verdade (`PetConnectApp`), com uma rota simples no lugar do
/// roteador, que depende do Firebase.
Future<void> _abrirApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        appBar: AppBar(),
        body: const SizedBox(),
      ),
    ),
    GoRoute(
      path: '/tela',
      builder: (context, _) =>
          Scaffold(appBar: AppBar(title: const Text('Tela'))),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appRouterProvider.overrideWithValue(router),
    ],
    child: const PetConnectApp(),
  ));
  await tester.pumpAndSettle();
}

BuildContext _contexto(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).last);

void main() {
  testWidgets('o app usa português do Brasil, qualquer que seja o celular',
      (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await _abrirApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, IdiomaDoApp.locale);
    expect(Localizations.localeOf(_contexto(tester)), IdiomaDoApp.locale);

    final textos = MaterialLocalizations.of(_contexto(tester));
    expect(textos.cancelButtonLabel, 'Cancelar');
    expect(textos.backButtonTooltip, 'Voltar');
    expect(textos.copyButtonLabel, 'Copiar');
    expect(textos.pasteButtonLabel, 'Colar');

    // A dica do botão de voltar já aparece em português.
    GoRouter.of(_contexto(tester)).push('/tela');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Voltar'), findsOneWidget);
  });

  testWidgets('calendário no modelo brasileiro', (tester) async {
    await _abrirApp(tester);
    final contexto = _contexto(tester);
    final textos = MaterialLocalizations.of(contexto);
    // Semana começando no domingo e data digitada como dd/mm/aaaa.
    expect(textos.firstDayOfWeekIndex, 0);
    expect(textos.dateHelpText, 'dd/mm/aaaa');
    expect(textos.formatCompactDate(DateTime(2026, 10, 29)), '29/10/2026');
    expect(textos.parseCompactDate('05/03/2026'), DateTime(2026, 3, 5));

    showDatePicker(
      context: contexto,
      initialDate: DateTime(2026, 10, 29),
      firstDate: DateTime(2026),
      lastDate: DateTime(2026, 12, 31),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.textContaining('outubro'), findsWidgets);
    // Cabeçalho dos dias da semana, a partir do domingo.
    final dias = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(dias.indexOf('D'), lessThan(dias.indexOf('S')));

    // Digitar a data também segue o formato brasileiro.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '05/11/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets('relógio em 24 horas, em português', (tester) async {
    await _abrirApp(tester);
    final contexto = _contexto(tester);
    expect(MaterialLocalizations.of(contexto).timeOfDayFormat(),
        TimeOfDayFormat.HH_colon_mm);

    showTimePicker(
        context: contexto, initialTime: const TimeOfDay(hour: 18, minute: 5));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('PM'), findsNothing);
  });
}
