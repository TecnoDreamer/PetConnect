import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
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
                const Text('Excluir', style: TextStyle(color: AppColors.error)),
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
    final historicoAsync = ref.watch(historicoMedicoProvider(petId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Histórico médico',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/pet/$petId/historico/novo'),
        backgroundColor: AppColors.brandDark,
        tooltip: 'Registrar entrada',
        child: const Icon(Icons.add, color: AppColors.textOnBrand),
      ),
      body: SafeArea(
        child: historicoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Não foi possível carregar o histórico.',
                style: TextStyle(color: AppColors.error)),
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
                  children: const [
                    SizedBox(height: 120),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhum registro ainda.\nToque em "+" para adicionar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
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
