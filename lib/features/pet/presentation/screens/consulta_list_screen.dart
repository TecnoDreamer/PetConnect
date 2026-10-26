import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/consulta.dart';
import '../providers/consulta_providers.dart';
import '../widgets/consulta_tile.dart';

/// Agendamento de consultas de um pet (RF27-RF30), com as consultas
/// separadas por status (RF28: futuras, concluídas e canceladas).
class ConsultaListScreen extends ConsumerWidget {
  const ConsultaListScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultasAsync = ref.watch(consultasProvider(petId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Consultas',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/pet/$petId/consultas/nova'),
        backgroundColor: AppColors.brandDark,
        tooltip: 'Agendar consulta',
        child: const Icon(Icons.add, color: AppColors.textOnBrand),
      ),
      body: SafeArea(
        child: consultasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Não foi possível carregar as consultas.',
                style: TextStyle(color: AppColors.error)),
          ),
          data: (consultas) {
            if (consultas.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(consultasProvider(petId));
                  await ref.read(consultasProvider(petId).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma consulta agendada ainda.\nToque em "+" para agendar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              );
            }

            final futuras = consultas
                .where((c) => c.status == ConsultaStatus.agendada)
                .toList();
            final concluidas = consultas
                .where((c) => c.status == ConsultaStatus.realizada)
                .toList();
            final canceladas = consultas
                .where((c) => c.status == ConsultaStatus.cancelada)
                .toList();

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(consultasProvider(petId));
                await ref.read(consultasProvider(petId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                children: [
                  if (futuras.isNotEmpty)
                    ..._secao(context, ref, 'Futuras', futuras),
                  if (concluidas.isNotEmpty)
                    ..._secao(context, ref, 'Concluídas', concluidas),
                  if (canceladas.isNotEmpty)
                    ..._secao(context, ref, 'Canceladas', canceladas),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _secao(BuildContext context, WidgetRef ref, String titulo,
      List<Consulta> consultas) {
    return [
      Text(
        titulo,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 15),
      ),
      const SizedBox(height: 8),
      for (final consulta in consultas) ...[
        ConsultaTile(
          consulta: consulta,
          onTap: () => context.push(
              '/pet/$petId/consultas/${consulta.id}/editar',
              extra: consulta),
          onMarcarRealizada: consulta.status == ConsultaStatus.agendada
              ? () => ref
                  .read(consultaRepositoryProvider)
                  .updateConsulta(petId,
                      consulta.copyWith(status: ConsultaStatus.realizada))
                  .then((_) => ref.invalidate(consultasProvider(petId)))
              : null,
          onCancelar: consulta.status == ConsultaStatus.agendada
              ? () => ref
                  .read(consultaRepositoryProvider)
                  .updateConsulta(petId,
                      consulta.copyWith(status: ConsultaStatus.cancelada))
                  .then((_) => ref.invalidate(consultasProvider(petId)))
              : null,
        ),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 12),
    ];
  }
}
