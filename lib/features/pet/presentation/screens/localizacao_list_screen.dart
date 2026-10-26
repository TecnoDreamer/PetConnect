import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/localizacao_providers.dart';
import '../widgets/localizacao_tile.dart';

/// Registros de localização/avistamento de um pet (RF31, RF32).
class LocalizacaoListScreen extends ConsumerWidget {
  const LocalizacaoListScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizacoesAsync = ref.watch(localizacoesProvider(petId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Localização',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/pet/$petId/localizacao/nova'),
        backgroundColor: AppColors.brandDark,
        tooltip: 'Registrar avistamento',
        child: const Icon(Icons.add, color: AppColors.textOnBrand),
      ),
      body: SafeArea(
        child: localizacoesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Não foi possível carregar os registros.',
                style: TextStyle(color: AppColors.error)),
          ),
          data: (localizacoes) {
            Future<void> atualizar() async {
              ref.invalidate(localizacoesProvider(petId));
              await ref.read(localizacoesProvider(petId).future);
            }

            if (localizacoes.isEmpty) {
              return RefreshIndicator(
                onRefresh: atualizar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhum avistamento registrado ainda.\nToque em "+" para registrar um.',
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
                itemCount: localizacoes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    LocalizacaoTile(localizacao: localizacoes[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}
