import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/historico_medico.dart';

class HistoricoTile extends StatelessWidget {
  const HistoricoTile(
      {super.key,
      required this.historico,
      required this.onTap,
      required this.onDelete});

  final HistoricoMedico historico;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      historico.data,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      historico.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textMuted, fontSize: 13),
                    ),
                    if (historico.anexos.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.attach_file,
                              size: 14, color: colors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${historico.anexos.length} anexo(s)',
                            style: TextStyle(
                                color: colors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colors.textMuted),
                tooltip: 'Excluir registro',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
