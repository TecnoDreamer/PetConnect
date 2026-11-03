import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/atividade_do_qr.dart';

/// Relato recebido pela página pública do QR (issue #37). Deixa claro que o
/// ponto é o que o navegador de quem relatou informou, com a precisão dele,
/// e não a posição atual do pet.
class AvistamentoDoQrTile extends StatelessWidget {
  const AvistamentoDoQrTile({
    super.key,
    required this.avistamento,
    required this.abrirMapa,
  });

  final AvistamentoDoQr avistamento;

  /// Abre o ponto fora do app. Recebe o link e devolve se conseguiu.
  final Future<bool> Function(Uri link) abrirMapa;

  static final _quando = DateFormat("dd/MM/yyyy 'às' HH:mm");

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final a = avistamento;
    final origem = a.temLocalizacao
        ? 'Localização enviada por quem encontrou'
            '${a.precisaoMetros == null ? '' : ', com precisão de ${descreverPrecisao(a.precisaoMetros!)}'}'
        : 'Sem localização: relato em texto, não verificado';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            a.temLocalizacao ? Icons.my_location : Icons.chat_bubble_outline,
            color: colors.brandMedium,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avistamento pelo QR Code',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  _quando.format(a.quando),
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
                if (a.descricao != null) ...[
                  const SizedBox(height: 6),
                  Text(a.descricao!,
                      style: TextStyle(color: colors.textPrimary)),
                ],
                const SizedBox(height: 6),
                Text(origem,
                    style: TextStyle(color: colors.textMuted, fontSize: 12)),
                if (a.contato != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Contato: ${a.contato}',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
                if (a.linkDoMapa != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: ValueKey('mapa-${a.id}'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: colors.brandDark,
                      ),
                      onPressed: () async {
                        final abriu = await abrirMapa(a.linkDoMapa!);
                        if (!abriu && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Não foi possível abrir o mapa neste aparelho.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Abrir no mapa'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumo dos acessos à página do QR. Nunca chama acesso de avistamento.
class AcessosDoQrCard extends StatelessWidget {
  const AcessosDoQrCard({super.key, required this.atividade});

  final AtividadeDoQr atividade;

  static final _quando = DateFormat("dd/MM 'às' HH:mm");

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final n = atividade.acessosNosUltimos30Dias;
    final ultimo = atividade.ultimoAcesso;
    final resumo = n == 0
        ? 'Ninguém abriu a página do QR nos últimos 30 dias.'
        : 'Página do QR aberta $n ${n == 1 ? 'vez' : 'vezes'} nos últimos 30 dias'
            '${ultimo == null ? '.' : '. Último acesso em ${_quando.format(ultimo)}.'}';

    return Container(
      key: const ValueKey('acessos-do-qr'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.qr_code_2, color: colors.brandMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resumo, style: TextStyle(color: colors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  'Abrir a página não confirma que alguém viu o pet. A localização só aparece quando quem encontrou decide enviá-la.',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
