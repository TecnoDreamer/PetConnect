import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Campo de texto da tela de Cadastro (redesign de 2026-09-13, ver
/// docs/features/cadastro-redesign.md).
///
/// Usa `labelText` + `FloatingLabelBehavior.auto` (padrão de "label
/// flutuante" do Material) em vez de duplicar rótulo + exemplo dentro do
/// campo: parado e vazio, o rótulo fica na posição do texto (como um
/// hint); ao focar ou digitar, ele sobe para uma legenda pequena acima,
/// liberando o espaço de digitação — e volta à posição inicial se o campo
/// perder o foco vazio. Como é o próprio `labelText` do Flutter (não um
/// `hintText` escondido manualmente), o rótulo permanece disponível para
/// leitores de tela em qualquer estado, sem nenhum truque de semântica
/// próprio — ver seção 33/22 do documento-fonte: a adaptação de "some por
/// completo" para "flutua para legenda pequena" foi deliberada, priorizando
/// acessibilidade testada pelo próprio framework sobre a fidelidade pixel a
/// pixel ao texto do prompt (seção 41 do próprio documento já estabelece
/// essa ordem de prioridade).
///
/// É um widget "burro" de propósito: quem decide o `errorText` (e quando
/// mostrá-lo) é a tela — timing de validação (ao perder o foco, não a
/// cada tecla) fica todo em `CadastroScreen`.
class CadastroTextField extends StatelessWidget {
  const CadastroTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.inputFormatters,
    this.autofillHints,
    this.errorText,
    this.showSuccessIcon = false,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.textAlign = TextAlign.left,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final String? errorText;

  /// Ícone de sucesso discreto (usado em "Confirmar senha" quando as
  /// senhas coincidem) — ignorado se [suffixIcon] também for informado.
  final bool showSuccessIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final temErro = errorText != null;
    final corBorda = temErro
        ? AppColors.error
        : AppColors.brandLight.withValues(alpha: 0.35);

    OutlineInputBorder borda(Color cor, {double largura = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cor, width: largura),
        );

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      textAlign: textAlign,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        errorText: errorText,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon ??
            (showSuccessIcon && !temErro
                ? const Icon(Icons.check_circle,
                    color: AppColors.success, size: 20)
                : null),
        border: borda(corBorda),
        enabledBorder: borda(corBorda),
        focusedBorder: borda(temErro ? AppColors.error : AppColors.brandDark,
            largura: 1.5),
        // isDense + padding vertical enxuto: a tela precisa caber inteira
        // sem rolar mesmo em aparelhos comuns (360x800) — 5 campos são o
        // maior consumidor de altura da tela (seção 4 do briefing, ver
        // docs/features/cadastro-redesign.md).
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
