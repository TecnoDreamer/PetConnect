import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/historico_medico.dart';
import '../providers/anexo_providers.dart';
import '../providers/historico_medico_providers.dart';
import '../widgets/historico_tile.dart';

/// Histórico médico de um pet (RF24-RF26).
class HistoricoListScreen extends ConsumerWidget {
  const HistoricoListScreen({super.key, required this.petId});

  final String petId;

  Future<void> _confirmarExclusao(
      BuildContext context, WidgetRef ref, HistoricoMedico historico) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir registro'),
        content: const Text(
            'Tem certeza que deseja excluir este registro de histórico médico?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                Text('Excluir', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    final anexoRepository = ref.read(anexoRepositoryProvider);
    for (final url in historico.anexos) {
      try {
        await anexoRepository.delete(url);
      } catch (_) {
        // Segue removendo o registro mesmo se algum anexo já não existir
        // mais no Storage.
      }
    }
    await ref
        .read(historicoMedicoRepositoryProvider)
        .deleteHistorico(petId, historico.id);
    ref.invalidate(historicoMedicoProvider(petId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final historicoAsync = ref.watch(historicoMedicoProvider(petId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text('Histórico médico',
            style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/pet/$petId/historico/novo'),
        backgroundColor: colors.brandDark,
        tooltip: 'Registrar entrada',
        child: Icon(Icons.add, color: colors.textOnBrand),
      ),
      body: SafeArea(
        child: historicoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('Não foi possível carregar o histórico.',
                style: TextStyle(color: context.colors.error)),
          ),
          data: (registros) {
            Future<void> atualizar() async {
              ref.invalidate(historicoMedicoProvider(petId));
              await ref.read(historicoMedicoProvider(petId).future);
            }

            if (registros.isEmpty) {
              return RefreshIndicator(
                onRefresh: atualizar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nenhum registro ainda.\nToque em "+" para adicionar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textMuted),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: atualizar,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                itemCount: registros.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final historico = registros[index];
                  return HistoricoTile(
                    historico: historico,
                    onTap: () => context.push(
                        '/pet/$petId/historico/${historico.id}/editar',
                        extra: historico),
                    onDelete: () => _confirmarExclusao(context, ref, historico),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
