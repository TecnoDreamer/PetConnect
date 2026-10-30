import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Idioma do app: português do Brasil, sempre, qualquer que seja o idioma
/// do celular (docs/features/idioma-portugues.md).
///
/// Vale para os textos que vêm do próprio Flutter: botões dos diálogos
/// ("Cancelar", "OK"), dicas dos botões ("Voltar"), o menu de copiar e
/// colar e os calendários e relógios. Neles, meses e dias da semana ficam
/// em português, a semana começa no domingo, a data digitada é dd/mm/aaaa
/// e a hora é em 24 h. Os textos das telas do PetConnect já são escritos
/// em português.
abstract final class IdiomaDoApp {
  static const locale = Locale('pt', 'BR');
  static const suportados = [locale];
  static const delegates = GlobalMaterialLocalizations.delegates;
}
