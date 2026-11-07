import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/br_date.dart';
import '../../domain/atividade_do_qr.dart';
import '../../domain/localizacao.dart';
import '../providers/abrir_link_provider.dart';
import '../providers/localizacao_providers.dart';
import '../widgets/avistamento_do_qr_tile.dart';
import '../widgets/localizacao_tile.dart';

/// Registros de localização/avistamento de um pet (RF31, RF32).
///
/// Junta os registros do próprio tutor com os relatos e acessos da página
/// pública do QR, que ficam na API (issue #37). Sem a API configurada, só os
/// registros do tutor.
class LocalizacaoListScreen extends ConsumerWidget {
  const LocalizacaoListScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final localizacoesAsync = ref.watch(localizacoesProvider(petId));
    final atividadeAsync = ref.watch(atividadeDoQrProvider(petId));
    final abrirLink = ref.watch(abrirLinkProvider);

    Future<void> atualizar() async {
      ref.invalidate(localizacoesProvider(petId));
      ref.invalidate(atividadeDoQrProvider(petId));
      await Future.wait([
        ref.read(localizacoesProvider(petId).future),
        ref
            .read(atividadeDoQrProvider(petId).future)
            .then<void>((_) {}, onError: (_) {}),
      ]);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text('Localização', style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/pet/$petId/localizacao/nova'),
        backgroundColor: colors.brandDark,
        tooltip: 'Registrar avistamento',
        child: Icon(Icons.add, color: colors.textOnBrand),
      ),
      body: SafeArea(
        child: localizacoesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('Não foi possível carregar os registros.',
                style: TextStyle(color: colors.error)),
          ),
          data: (localizacoes) {
            final atividade = atividadeAsync.valueOrNull;
            final registros = _juntar(localizacoes, atividade);

            final topo = <Widget>[
              if (atividade != null) AcessosDoQrCard(atividade: atividade),
              if (atividadeAsync.isLoading && atividade == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              if (atividadeAsync.hasError && !atividadeAsync.isLoading)
                _FalhaDoQr(
                    onTentar: () =>
                        ref.invalidate(atividadeDoQrProvider(petId))),
            ];

            if (registros.isEmpty) {
              return RefreshIndicator(
                onRefresh: atualizar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                  children: [
                    ...topo,
                    const SizedBox(height: 96),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nenhum avistamento registrado ainda.\nToque em "+" para registrar um.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textMuted),
                      ),
                    ),
                  ],
                ),
              );
            }

            final itens = <Widget>[
              ...topo,
              for (final r in registros)
                switch (r) {
                  _DoTutor(:final localizacao) =>
                    LocalizacaoTile(localizacao: localizacao),
                  _DoQr(:final avistamento) => AvistamentoDoQrTile(
                      avistamento: avistamento,
                      abrirMapa: abrirLink,
                    ),
                },
            ];

            return RefreshIndicator(
              onRefresh: atualizar,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                itemCount: itens.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => itens[index],
              ),
            );
          },
        ),
      ),
    );
  }
}

sealed class _Registro {
  const _Registro(this.quando);

  /// `null` quando o registro do tutor tem data em formato inesperado: vai
  /// para o fim.
  final DateTime? quando;
}

class _DoTutor extends _Registro {
  _DoTutor(this.localizacao) : super(parseBrDate(localizacao.data));

  final Localizacao localizacao;
}

class _DoQr extends _Registro {
  _DoQr(this.avistamento) : super(avistamento.quando);

  final AvistamentoDoQr avistamento;
}

/// Mais recentes primeiro. Com a API como fonte das localizações
/// (`USE_API_PETS`), o relato do QR já vem na lista do tutor: o mesmo id não
/// aparece duas vezes.
List<_Registro> _juntar(List<Localizacao> doTutor, AtividadeDoQr? atividade) {
  final ids = doTutor.map((l) => l.id).toSet();
  final registros = <_Registro>[
    ...doTutor.map(_DoTutor.new),
    ...?atividade?.avistamentos
        .where((a) => !ids.contains(a.id))
        .map(_DoQr.new),
  ];
  registros.sort((a, b) {
    final qa = a.quando, qb = b.quando;
    if (qa == null && qb == null) return 0;
    if (qa == null) return 1;
    if (qb == null) return -1;
    return qb.compareTo(qa);
  });
  return registros;
}

class _FalhaDoQr extends StatelessWidget {
  const _FalhaDoQr({required this.onTentar});

  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Não foi possível carregar os avisos do QR Code.',
              style: TextStyle(color: colors.error, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onTentar, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
