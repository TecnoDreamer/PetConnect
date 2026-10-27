// Telas de vacinas, consultas, histórico e localização seguem o tema
// escolhido (Padrão, Claro, Escuro) — issue #56,
// docs/features/theme-and-settings-menu.md.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/theme/app_palette.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';
import 'package:pet_connect/features/pet/domain/consulta.dart';
import 'package:pet_connect/features/pet/domain/historico_medico.dart';
import 'package:pet_connect/features/pet/domain/localizacao.dart';
import 'package:pet_connect/features/pet/domain/vacina.dart';
import 'package:pet_connect/features/pet/presentation/providers/anexo_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/consulta_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/historico_medico_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/localizacao_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/vacina_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/consulta_form_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/consulta_list_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/historico_form_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/historico_list_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/localizacao_form_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/localizacao_list_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/vacina_form_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/vacina_list_screen.dart';
import 'package:pet_connect/features/pet/presentation/widgets/consulta_tile.dart';
import 'package:pet_connect/features/pet/presentation/widgets/historico_tile.dart';
import 'package:pet_connect/features/pet/presentation/widgets/localizacao_tile.dart';
import 'package:pet_connect/features/pet/presentation/widgets/vacina_tile.dart';

import '../../helpers/fonte_roboto.dart';
import 'fake_anexo_repository.dart';
import 'fake_historico_medico_repository.dart';

const _petId = 'pet-1';

const _paletas = {
  AppThemeMode.padrao: AppPalette.padrao,
  AppThemeMode.claro: AppPalette.claro,
  AppThemeMode.escuro: AppPalette.escuro,
};

final _overrides = [
  vacinasProvider.overrideWith((ref, petId) => Stream.value(const [
        Vacina(
            id: 'v1',
            nome: 'Antirrábica',
            dataAplicacao: '01/01/2026',
            proximaDose: '01/01/2027'),
      ])),
  consultasProvider.overrideWith((ref, petId) => Stream.value(const [
        Consulta(
            id: 'c1',
            data: '10/12/2030',
            veterinario: 'Dra. Ana',
            motivo: 'Check-up anual',
            status: ConsultaStatus.agendada),
      ])),
  historicoMedicoProvider.overrideWith((ref, petId) => Stream.value(const [
        HistoricoMedico(
            id: 'h1', data: '05/03/2026', descricao: 'Exame de sangue'),
      ])),
  localizacoesProvider.overrideWith((ref, petId) => Stream.value(const [
        Localizacao(id: 'l1', data: '02/02/2026', descricao: 'Praça central'),
      ])),
  historicoMedicoRepositoryProvider
      .overrideWithValue(FakeHistoricoMedicoRepository()),
  anexoRepositoryProvider.overrideWithValue(FakeAnexoRepository()),
];

/// Telas da área clínica, com o tile de lista que cada uma mostra (null nos
/// formulários).
final _telas = <String, (Widget, Type?)>{
  'lista de vacinas': (const VacinaListScreen(petId: _petId), VacinaTile),
  'lista de consultas': (const ConsultaListScreen(petId: _petId), ConsultaTile),
  'lista de histórico': (
    const HistoricoListScreen(petId: _petId),
    HistoricoTile
  ),
  'lista de localizações': (
    const LocalizacaoListScreen(petId: _petId),
    LocalizacaoTile
  ),
  'formulário de vacina': (const VacinaFormScreen(petId: _petId), null),
  'formulário de consulta': (const ConsultaFormScreen(petId: _petId), null),
  'formulário de histórico': (const HistoricoFormScreen(petId: _petId), null),
  'formulário de localização': (
    const LocalizacaoFormScreen(petId: _petId),
    null
  ),
};

Future<void> _abrir(WidgetTester tester, Widget tela, AppThemeMode modo,
    {Size tamanho = const Size(412, 915), double escalaFonte = 1}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
    overrides: _overrides,
    child: MaterialApp(
      theme: AppTheme.build(modo),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(escalaFonte)),
        child: child!,
      ),
      home: tela,
    ),
  ));
  await tester.pumpAndSettle();
}

/// Cor do cartão de um tile: os tiles usam `Material` ou `Container` com
/// `BoxDecoration` como raiz.
Color? _corDoCartao(WidgetTester tester, Type tile) {
  final raiz = tester.widget(find
      .descendant(
          of: find.byType(tile),
          matching: find.byWidgetPredicate((w) =>
              w is Material ||
              (w is Container && w.decoration is BoxDecoration)))
      .first);
  return raiz is Material
      ? raiz.color
      : ((raiz as Container).decoration as BoxDecoration).color;
}

void main() {
  setUpAll(carregarRoboto);

  for (final MapEntry(key: modo, value: paleta) in _paletas.entries) {
    group('tema ${modo.name}', () {
      for (final MapEntry(key: nome, value: (tela, tile)) in _telas.entries) {
        testWidgets('$nome usa as cores do tema', (tester) async {
          await _abrir(tester, tela, modo);
          expect(tester.takeException(), isNull);

          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          expect(scaffold.backgroundColor, paleta.background,
              reason: 'fundo da tela');
          final appBar = tester.widget<AppBar>(find.byType(AppBar));
          expect(appBar.backgroundColor, paleta.background);
          expect(appBar.iconTheme?.color, paleta.textPrimary);
          final titulo = tester.widget<Text>(find.descendant(
              of: find.byType(AppBar), matching: find.byType(Text)));
          expect(titulo.style?.color, paleta.textPrimary,
              reason: 'título da AppBar');

          if (tile != null) {
            expect(_corDoCartao(tester, tile), paleta.surface,
                reason: 'cartão do item');
          }
        });
      }
    });
  }

  testWidgets('tema Escuro: texto dos itens é claro sobre o cartão escuro',
      (tester) async {
    await _abrir(
        tester, const VacinaListScreen(petId: _petId), AppThemeMode.escuro);
    final nome = tester.widget<Text>(find.text('Antirrábica'));
    expect(nome.style?.color, AppPalette.escuro.textPrimary);
    expect(ThemeData.estimateBrightnessForColor(AppPalette.escuro.surface),
        Brightness.dark);
    expect(ThemeData.estimateBrightnessForColor(nome.style!.color!),
        Brightness.light);
  });

  testWidgets('consulta agendada: ações com as cores de sucesso e erro do tema',
      (tester) async {
    await _abrir(
        tester, const ConsultaListScreen(petId: _petId), AppThemeMode.escuro);
    final realizada = tester.widget<Text>(find.text('Marcar realizada'));
    expect(realizada.style?.color, AppPalette.escuro.success);
    final cancelar = tester.widget<Text>(find.text('Cancelar'));
    expect(cancelar.style?.color, AppPalette.escuro.error);
  });

  for (final MapEntry(key: nome, value: (tela, _)) in _telas.entries) {
    testWidgets('$nome: sem overflow em 360x800 com fonte 1.3 (Escuro)',
        (tester) async {
      await _abrir(tester, tela, AppThemeMode.escuro,
          tamanho: const Size(360, 800), escalaFonte: 1.3);
      expect(tester.takeException(), isNull);
    });
  }
}
