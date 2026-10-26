import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// Envolve uma tela de autenticação (Login, Cadastro, Esqueci senha) no
/// tema fixo de autenticação — a identidade original do app — em vez do
/// tema escolhido pelo tutor.
///
/// A preferência de tema do tutor continua salva e valendo nas telas
/// autenticadas; só esta subárvore ignora. Ver
/// docs/decisions/0001-tema-fixo-autenticacao.md.
class AuthThemeScope extends StatelessWidget {
  const AuthThemeScope({super.key, required this.child});

  final Widget child;

  static final _tema = AppTheme.autenticacao();

  @override
  Widget build(BuildContext context) {
    // A status bar das telas de autenticação tem fundo claro: com o tema
    // escuro, o AnnotatedRegion global (app.dart) deixaria os ícones brancos
    // sobre branco. Este, mais interno, prevalece enquanto a tela está
    // visível.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Theme(data: _tema, child: child),
    );
  }
}
