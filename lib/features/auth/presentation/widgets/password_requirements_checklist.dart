import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../utils/cadastro_validators.dart';

/// Checklist compacto dos requisitos de senha (seção 11 do briefing) —
/// nunca depende só de cor: cada item troca de ícone (círculo vazio →
/// check) e não só de tom.
///
/// Quem decide se o checklist aparece é quem usa este widget (a tela: só
/// enquanto o campo de senha estiver focado ou a senha ainda não atender
/// aos requisitos) — este widget só desenha a lista em si.
class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({super.key, required this.senha});

  final String senha;

  @override
  Widget build(BuildContext context) {
    final itens = [
      ('9 ou mais caracteres', senhaTemTamanhoMinimo(senha)),
      ('Letra maiúscula', senhaTemMaiuscula(senha)),
      ('Letra minúscula', senhaTemMinuscula(senha)),
      ('Número', senhaTemNumero(senha)),
      ('Caractere especial', senhaTemCaractereEspecial(senha)),
    ];

    return Semantics(
      // Um único rótulo combinado é mais útil pra leitor de tela do que
      // 5 anúncios soltos de ícone+texto (evita ruído a cada tecla digitada).
      label: 'Requisitos da senha: ${itens.map((i) => '${i.$1}, '
          '${i.$2 ? 'atendido' : 'pendente'}').join('; ')}.',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 10,
          runSpacing: 2,
          children: [for (final item in itens) _Item(item.$1, item.$2)],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.label, this.atendido);

  final String label;
  final bool atendido;

  @override
  Widget build(BuildContext context) {
    final cor = atendido ? AppColors.success : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          atendido ? Icons.check_circle : Icons.circle_outlined,
          size: 14,
          color: cor,
        ),
        const SizedBox(width: 4),
        // Flexible (não Text direto): em telas estreitas, o Wrap que
        // envolve os itens pode sobrar menos espaço do que o texto
        // precisaria — sem isto o Row estoura em vez de encolher (mesmo
        // cuidado de VaccinePendingBadge na Home, ver
        // docs/features/tutor-home.md).
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: cor),
          ),
        ),
      ],
    );
  }
}
