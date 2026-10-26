import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_mode.dart';

const _chaveTema = 'tema_app';

/// Sobrescrito em `main()` com a instância já carregada
/// (`SharedPreferences.getInstance()` é assíncrono — não dá pra resolver
/// isso dentro de um provider síncrono comum).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
      'sharedPreferencesProvider precisa ser sobrescrito em main().');
});

/// Preferência de aparência do tutor (RF de tema, 2026-09-13). Sem
/// preferência salva (ou com um valor inválido), o app abre no
/// [AppThemeMode.claro] — o tema principal desde 2026-10-27. Quem já
/// escolheu um modo explicitamente continua nele.
class ThemeModeController extends StateNotifier<AppThemeMode> {
  ThemeModeController(this._prefs) : super(_lerPreferencia(_prefs));

  final SharedPreferences _prefs;

  static AppThemeMode _lerPreferencia(SharedPreferences prefs) {
    final salvo = prefs.getString(_chaveTema);
    return AppThemeMode.values.firstWhere(
      (modo) => modo.name == salvo,
      orElse: () => AppThemeMode.claro,
    );
  }

  Future<void> definir(AppThemeMode modo) async {
    state = modo;
    await _prefs.setString(_chaveTema, modo.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, AppThemeMode>((ref) {
  return ThemeModeController(ref.watch(sharedPreferencesProvider));
});
