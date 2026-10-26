import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_theme_mode.dart';

abstract final class AppTheme {
  /// Tema completo para um dos três modos (RF de aparência,
  /// 2026-09-13) — registra a [AppPalette] correspondente como
  /// [ThemeExtension], então qualquer tela migrada (`context.colors`)
  /// responde automaticamente à troca de tema.
  static ThemeData build(AppThemeMode mode) {
    final palette = switch (mode) {
      AppThemeMode.padrao => AppPalette.padrao,
      AppThemeMode.claro => AppPalette.claro,
      AppThemeMode.escuro => AppPalette.escuro,
    };
    final brilho =
        mode == AppThemeMode.escuro ? Brightness.dark : Brightness.light;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brilho,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.brandDark,
        brightness: brilho,
        primary: palette.brandDark,
        onPrimary: palette.textOnBrand,
        surface: palette.surface,
        error: palette.error,
      ),
      scaffoldBackgroundColor: palette.background,
      fontFamily: 'Roboto',
      extensions: [palette],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        systemOverlayStyle: brilho == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
      dialogTheme: DialogThemeData(backgroundColor: palette.cardBackground),
      bottomSheetTheme:
          BottomSheetThemeData(backgroundColor: palette.cardBackground),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.brandDark,
        contentTextStyle: TextStyle(color: palette.textOnBrand),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: palette.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.brandDark,
          foregroundColor: palette.textOnBrand,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.surface,
          foregroundColor: palette.textPrimary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.brandDark,
        ),
      ),
    );
  }

  /// Tema fixo das telas de autenticação (Login, Cadastro, Esqueci senha):
  /// a identidade original do app, independente da preferência do tutor —
  /// ver docs/decisions/0001-tema-fixo-autenticacao.md. Aplicado só à
  /// subárvore dessas telas, por `AuthThemeScope`.
  static ThemeData autenticacao() => build(AppThemeMode.padrao);

  /// Mantido por compatibilidade — usado em telas/testes anteriores a esta
  /// etapa. Equivale a `build(AppThemeMode.padrao)`; usa [AppColors]
  /// diretamente (não a paleta) porque telas que ainda não migraram para
  /// `context.colors` continuam lendo `AppColors` fixo — os dois têm que
  /// bater exatamente (ver auditoria em
  /// docs/features/theme-and-settings-menu.md).
  static ThemeData light() {
    assert(
      AppPalette.padrao.background == AppColors.background &&
          AppPalette.padrao.textPrimary == AppColors.textPrimary,
      'AppPalette.padrao se desalinhou de AppColors — telas não migradas '
      'vão parecer diferentes das migradas no modo Padrão.',
    );
    return build(AppThemeMode.padrao);
  }
}
