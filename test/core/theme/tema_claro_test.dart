// Tema Claro como tema principal, com fundo sempre branco (2026-10-27,
// docs/features/theme-and-settings-menu.md).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/theme/app_palette.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';

void main() {
  test('fundo das telas e da Home é branco', () {
    expect(AppPalette.claro.background, Colors.white);
    expect(AppPalette.claro.homeBackdrop, Colors.white);
    expect(AppTheme.build(AppThemeMode.claro).scaffoldBackgroundColor,
        Colors.white);
  });

  test('campos e cartões continuam distinguíveis do fundo branco', () {
    expect(AppPalette.claro.surface, isNot(Colors.white),
        reason: 'campo preenchido branco sobre fundo branco some');
    expect(AppPalette.claro.cardBackground, isNot(Colors.white));
    expect(AppTheme.build(AppThemeMode.claro).inputDecorationTheme.fillColor,
        AppPalette.claro.surface);
  });
}
