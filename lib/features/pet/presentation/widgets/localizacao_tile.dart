import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/localizacao.dart';

class LocalizacaoTile extends StatelessWidget {
  const LocalizacaoTile({super.key, required this.localizacao});

  final Localizacao localizacao;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, color: colors.brandMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizacao.data,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(localizacao.descricao,
                    style: TextStyle(color: colors.textPrimary)),
                if (localizacao.contatoReportante != null &&
                    localizacao.contatoReportante!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Contato: ${localizacao.contatoReportante}',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
