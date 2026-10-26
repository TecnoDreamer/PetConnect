// Testa a persistência da preferência de tema (RF de aparência,
// 2026-09-13): padrão inicial, persistência de cada modo e restauração
// depois de um "reinício" simulado (nova instância de SharedPreferences
// lendo o mesmo armazenamento).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';
import 'package:pet_connect/core/theme/theme_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> criarContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('sem preferência salva, começa no modo Claro (tema principal)',
      () async {
    final container = await criarContainer();
    expect(container.read(themeModeProvider), AppThemeMode.claro);
  });

  test('definir Escuro persiste, mesmo depois de "reabrir o app"', () async {
    final container = await criarContainer();
    await container
        .read(themeModeProvider.notifier)
        .definir(AppThemeMode.escuro);
    expect(container.read(themeModeProvider), AppThemeMode.escuro);

    // "Reabrir o app": nova instância de SharedPreferences (não é o mesmo
    // objeto em memória) lendo o mesmo armazenamento subjacente.
    final prefsDepoisDeReabrir = await SharedPreferences.getInstance();
    final containerDepoisDeReabrir = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefsDepoisDeReabrir),
    ]);
    addTearDown(containerDepoisDeReabrir.dispose);

    expect(
        containerDepoisDeReabrir.read(themeModeProvider), AppThemeMode.escuro);
  });

  test('definir Claro persiste', () async {
    final container = await criarContainer();
    await container
        .read(themeModeProvider.notifier)
        .definir(AppThemeMode.claro);

    final prefsDepois = await SharedPreferences.getInstance();
    final containerDepois = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefsDepois),
    ]);
    addTearDown(containerDepois.dispose);

    expect(containerDepois.read(themeModeProvider), AppThemeMode.claro);
  });

  test('definir Padrão persiste (mesmo sendo o valor inicial)', () async {
    final container = await criarContainer();
    await container
        .read(themeModeProvider.notifier)
        .definir(AppThemeMode.escuro);
    await container
        .read(themeModeProvider.notifier)
        .definir(AppThemeMode.padrao);

    final prefsDepois = await SharedPreferences.getInstance();
    final containerDepois = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefsDepois),
    ]);
    addTearDown(containerDepois.dispose);

    expect(containerDepois.read(themeModeProvider), AppThemeMode.padrao);
  });

  test('valor inválido salvo (versão antiga, corrompido) cai para Claro',
      () async {
    SharedPreferences.setMockInitialValues({'tema_app': 'valor-invalido'});
    final container = await criarContainer();
    expect(container.read(themeModeProvider), AppThemeMode.claro);
  });
}
