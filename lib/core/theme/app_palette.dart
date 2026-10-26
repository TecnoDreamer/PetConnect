import 'package:flutter/material.dart';

/// Tokens de cor que variam por modo de aparência (Padrão/Claro/Escuro).
/// Registrado como [ThemeExtension] em cada [ThemeData] — acessar sempre
/// via `context.colors`, nunca instanciando diretamente numa tela.
///
/// [AppColors] (o arquivo antigo) continua existindo e não muda: é a base
/// literal do modo Padrão, e ainda é usado nas telas que esta etapa não
/// migrou (ver docs/features/theme-and-settings-menu.md, "Hardcodes
/// restantes") — essas telas mantêm a aparência do modo Padrão sempre,
/// independente do tema escolhido.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.homeBackdrop,
    required this.surface,
    required this.cardBackground,
    required this.textPrimary,
    required this.textMuted,
    required this.textOnBrand,
    required this.brandDark,
    required this.brandMedium,
    required this.brandLight,
    required this.error,
    required this.success,
    required this.divider,
    required this.petCardBackgrounds,
    required this.petCardAccents,
    required this.genderFemaleForeground,
    required this.genderFemaleBackground,
  });

  final Color background;

  /// Fundo atrás do card flutuante da Home — mais escuro/contrastante que
  /// [cardBackground] nos modos claros, e o inverso no Escuro (o card fica
  /// mais claro que o fundo, pra continuar parecendo "elevado").
  final Color homeBackdrop;

  final Color surface;
  final Color cardBackground;
  final Color textPrimary;
  final Color textMuted;
  final Color textOnBrand;
  final Color brandDark;
  final Color brandMedium;
  final Color brandLight;
  final Color error;
  final Color success;
  final Color divider;

  /// Paleta cíclica dos cards de pet na Home e dos cards de funcionalidade
  /// no perfil do pet — sempre com o mesmo número de itens nas duas listas.
  final List<Color> petCardBackgrounds;
  final List<Color> petCardAccents;

  /// Badge de gênero "Fêmea" (home do tutor) — o de "Macho" reaproveita o
  /// azul cíclico já existente (`petCardAccents`/`petCardBackgrounds[3]`),
  /// mas não há nenhum tom de rosa na paleta ainda.
  final Color genderFemaleForeground;
  final Color genderFemaleBackground;

  static const padrao = AppPalette(
    background: Color(0xFFFBEADD),
    homeBackdrop: Color(0xFFEEF1FA),
    surface: Color(0xFFFFF8F0),
    cardBackground: Colors.white,
    textPrimary: Color(0xFF3E2415),
    textMuted: Color(0xFF9C7B5F),
    textOnBrand: Colors.white,
    brandDark: Color(0xFF3E2415),
    brandMedium: Color(0xFF5C3A24),
    brandLight: Color(0xFF7A5137),
    error: Color(0xFFB3261E),
    success: Color(0xFF2E7D32),
    divider: Color(0x1F3E2415),
    petCardBackgrounds: [
      Color(0xFFEDE7F6),
      Color(0xFFFFF3E0),
      Color(0xFFE8F5E9),
      Color(0xFFE3F2FD),
    ],
    petCardAccents: [
      Color(0xFF7E57C2),
      Color(0xFFFB8C00),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
    ],
    genderFemaleForeground: Color(0xFFC2185B),
    genderFemaleBackground: Color(0xFFFCE4EC),
  );

  // Tema principal do app (2026-10-27): fundo sempre branco. Como o fundo
  // é branco, campos e cartões usam um cinza bem claro — senão um campo
  // branco sobre fundo branco desaparece.
  static const claro = AppPalette(
    background: Colors.white,
    homeBackdrop: Colors.white,
    surface: Color(0xFFF4F4F2),
    cardBackground: Color(0xFFF6F6F4),
    textPrimary: Color(0xFF231A13),
    textMuted: Color(0xFF6E655D),
    textOnBrand: Colors.white,
    brandDark: Color(0xFF3E2415),
    brandMedium: Color(0xFF5C3A24),
    brandLight: Color(0xFF8A5C3E),
    error: Color(0xFFB3261E),
    success: Color(0xFF2E7D32),
    divider: Color(0x1F231A13),
    petCardBackgrounds: [
      Color(0xFFF1ECFA),
      Color(0xFFFFF4E5),
      Color(0xFFEAF7EC),
      Color(0xFFE7F1FC),
    ],
    petCardAccents: [
      Color(0xFF7E57C2),
      Color(0xFFFB8C00),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
    ],
    genderFemaleForeground: Color(0xFFC2185B),
    genderFemaleBackground: Color(0xFFFCE4EC),
  );

  static const escuro = AppPalette(
    background: Color(0xFF15100C),
    homeBackdrop: Color(0xFF120D0A),
    surface: Color(0xFF241C15),
    cardBackground: Color(0xFF241C15),
    textPrimary: Color(0xFFF3E9DF),
    textMuted: Color(0xFFB9A08A),
    textOnBrand: Colors.white,
    brandDark: Color(0xFFA47854),
    brandMedium: Color(0xFF8A6245),
    brandLight: Color(0xFFC9A67D),
    error: Color(0xFFFF6B5E),
    success: Color(0xFF6FCF7C),
    divider: Color(0x1FFFFFFF),
    petCardBackgrounds: [
      Color(0xFF2A2438),
      Color(0xFF332A1E),
      Color(0xFF1F2E22),
      Color(0xFF1E2733),
    ],
    petCardAccents: [
      Color(0xFFB39DDB),
      Color(0xFFFFB74D),
      Color(0xFF81C784),
      Color(0xFF64B5F6),
    ],
    genderFemaleForeground: Color(0xFFF48FB1),
    genderFemaleBackground: Color(0xFF3A2530),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? homeBackdrop,
    Color? surface,
    Color? cardBackground,
    Color? textPrimary,
    Color? textMuted,
    Color? textOnBrand,
    Color? brandDark,
    Color? brandMedium,
    Color? brandLight,
    Color? error,
    Color? success,
    Color? divider,
    List<Color>? petCardBackgrounds,
    List<Color>? petCardAccents,
    Color? genderFemaleForeground,
    Color? genderFemaleBackground,
  }) {
    return AppPalette(
      background: background ?? this.background,
      homeBackdrop: homeBackdrop ?? this.homeBackdrop,
      surface: surface ?? this.surface,
      cardBackground: cardBackground ?? this.cardBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textOnBrand: textOnBrand ?? this.textOnBrand,
      brandDark: brandDark ?? this.brandDark,
      brandMedium: brandMedium ?? this.brandMedium,
      brandLight: brandLight ?? this.brandLight,
      error: error ?? this.error,
      success: success ?? this.success,
      divider: divider ?? this.divider,
      petCardBackgrounds: petCardBackgrounds ?? this.petCardBackgrounds,
      petCardAccents: petCardAccents ?? this.petCardAccents,
      genderFemaleForeground:
          genderFemaleForeground ?? this.genderFemaleForeground,
      genderFemaleBackground:
          genderFemaleBackground ?? this.genderFemaleBackground,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> cl(List<Color> a, List<Color> b) =>
        List.generate(a.length, (i) => Color.lerp(a[i], b[i], t)!);

    return AppPalette(
      background: c(background, other.background),
      homeBackdrop: c(homeBackdrop, other.homeBackdrop),
      surface: c(surface, other.surface),
      cardBackground: c(cardBackground, other.cardBackground),
      textPrimary: c(textPrimary, other.textPrimary),
      textMuted: c(textMuted, other.textMuted),
      textOnBrand: c(textOnBrand, other.textOnBrand),
      brandDark: c(brandDark, other.brandDark),
      brandMedium: c(brandMedium, other.brandMedium),
      brandLight: c(brandLight, other.brandLight),
      error: c(error, other.error),
      success: c(success, other.success),
      divider: c(divider, other.divider),
      petCardBackgrounds: cl(petCardBackgrounds, other.petCardBackgrounds),
      petCardAccents: cl(petCardAccents, other.petCardAccents),
      genderFemaleForeground:
          c(genderFemaleForeground, other.genderFemaleForeground),
      genderFemaleBackground:
          c(genderFemaleBackground, other.genderFemaleBackground),
    );
  }
}

/// Acesso conveniente: `context.colors.textPrimary` em vez de
/// `Theme.of(context).extension<AppPalette>()!.textPrimary`.
extension AppPaletteContext on BuildContext {
  AppPalette get colors => Theme.of(this).extension<AppPalette>()!;
}
