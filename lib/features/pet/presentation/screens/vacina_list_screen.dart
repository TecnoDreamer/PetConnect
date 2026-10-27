import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/vacina.dart';
import '../providers/vacina_providers.dart';
import '../widgets/vacina_tile.dart';

/// Carteira de vacina de um pet (RF20-RF23).
class VacinaListScreen extends ConsumerWidget {
  const VacinaListScreen({super.key, required this.petId});

  final String petId;

  Future<void> _confirmarExclusao(
      BuildContext context, WidgetRef ref, Vacina vacina) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir vacina'),
        content: Text(
            'Tem certeza que deseja excluir o registro de "${vacina.nome}"?'),
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

    await ref.read(vacinaRepositoryProvider).deleteVacina(petId, vacina.id);
    ref.invalidate(vacinasProvider(petId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final vacinasAsync = ref.watch(vacinasProvider(petId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text('Carteira de vacina',
            style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/pet/$petId/vacinas/nova'),
        backgroundColor: colors.brandDark,
        tooltip: 'Registrar vacina',
        child: Icon(Icons.add, color: colors.textOnBrand),
      ),
      body: SafeArea(
        child: vacinasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('Não foi possível carregar as vacinas.',
                style: TextStyle(color: context.colors.error)),
          ),
          data: (vacinas) {
            Future<void> atualizar() async {
              ref.invalidate(vacinasProvider(petId));
              await ref.read(vacinasProvider(petId).future);
            }

            if (vacinas.isEmpty) {
              return RefreshIndicator(
                onRefresh: atualizar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma vacina registrada ainda.\nToque em "+" para adicionar.',
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
                itemCount: vacinas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final vacina = vacinas[index];
                  return VacinaTile(
                    vacina: vacina,
                    onTap: () => context.push(
                        '/pet/$petId/vacinas/${vacina.id}/editar',
                        extra: vacina),
                    onDelete: () => _confirmarExclusao(context, ref, vacina),
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
