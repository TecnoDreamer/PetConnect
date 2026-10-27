import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/pet.dart';
import '../providers/galeria_providers.dart';
import '../providers/pet_providers.dart';
import '../widgets/foto_miniatura.dart';
import 'galeria_viewer_screen.dart';
import 'publicar_fotos_screen.dart';

/// Galeria particular de um pet: grade de miniaturas em 3 colunas, mais
/// recentes primeiro, carregando por páginas (docs/features/galeria-fotos-pet.md).
///
/// Vale para pet ativo e para pet no Memorial. A rota confere que o pet é
/// do tutor autenticado (PetSituacaoGuard sem exigir situação).
class GaleriaScreen extends ConsumerStatefulWidget {
  const GaleriaScreen({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<GaleriaScreen> createState() => _GaleriaScreenState();
}

class _GaleriaScreenState extends ConsumerState<GaleriaScreen> {
  final _rolagem = ScrollController();

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(_carregarMaisPerto);
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  void _carregarMaisPerto() {
    if (_rolagem.position.extentAfter < 600) {
      ref.read(galeriaControllerProvider(widget.petId).notifier).carregarMais();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A entrada some com a galeria desligada; isto cobre o link direto.
    if (!ref.watch(galeriaDisponivelProvider)) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Fotos')),
        body: Center(
          child: Text('A galeria de fotos ainda não está disponível.',
              style: TextStyle(color: colors.textMuted)),
        ),
      );
    }
    final pet = ref.watch(petProvider(widget.petId)).valueOrNull;
    final estado = ref.watch(galeriaControllerProvider(widget.petId));
    final controller =
        ref.read(galeriaControllerProvider(widget.petId).notifier);
    final temFotos = estado.fotos.isNotEmpty;
    // Em tela alta a primeira página pode não encher a grade; sem rolagem,
    // o listener nunca dispararia.
    if (estado.temMais && !estado.carregandoMais && !estado.erro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _rolagem.hasClients) _carregarMaisPerto();
      });
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(pet == null ? 'Fotos' : 'Fotos de ${pet.nome}'),
        actions: [
          if (pet != null)
            IconButton(
              tooltip: 'Adicionar fotos',
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: () => adicionarFotosAoPet(context, pet),
            ),
        ],
      ),
      floatingActionButton: pet != null && temFotos
          ? FloatingActionButton.extended(
              onPressed: () => adicionarFotosAoPet(context, pet),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Adicionar fotos'),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.recarregar,
          child: CustomScrollView(
            controller: _rolagem,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (estado.carregando && !temFotos)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (estado.erro && !temFotos)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Mensagem(
                    texto: 'Não foi possível carregar as fotos. Verifique sua '
                        'conexão.',
                    acao: 'Tentar de novo',
                    aoTocar: controller.recarregar,
                  ),
                )
              else if (!temFotos)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _GaleriaVazia(pet: pet),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.all(2),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: estado.fotos.length,
                    itemBuilder: (context, indice) {
                      final foto = estado.fotos[indice];
                      return FotoMiniatura(
                        key: ValueKey(foto.id),
                        foto: foto,
                        descricao: 'Foto ${indice + 1}'
                            '${pet == null ? '' : ' de ${pet.nome}'}'
                            '${foto.legenda == null ? '' : ': ${foto.legenda}'}',
                        aoTocar: () => GaleriaViewerScreen.abrir(
                          context,
                          petId: widget.petId,
                          indiceInicial: indice,
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: _RodapeDaGrade(
                    estado: estado,
                    aoTentarDeNovo: controller.carregarMais,
                  ),
                ),
                // Espaço para o botão flutuante não cobrir a última linha.
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GaleriaVazia extends StatelessWidget {
  const _GaleriaVazia({required this.pet});

  final Pet? pet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pet = this.pet;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 64, color: colors.brandMedium),
            const SizedBox(height: 16),
            Text(
              'Nenhuma foto ainda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pet == null
                  ? ''
                  : pet.falecido
                      ? 'Guarde aqui as lembranças de ${pet.nome}.'
                      : 'Guarde aqui os momentos de ${pet.nome}. Só você vê '
                          'estas fotos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted),
            ),
            if (pet != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => adicionarFotosAoPet(context, pet),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Adicionar primeira foto'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RodapeDaGrade extends StatelessWidget {
  const _RodapeDaGrade({required this.estado, required this.aoTentarDeNovo});

  final GaleriaEstado estado;
  final VoidCallback aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    if (estado.carregandoMais) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (estado.erro && estado.temMais) {
      return _Mensagem(
        texto: 'Não foi possível carregar mais fotos.',
        acao: 'Tentar de novo',
        aoTocar: aoTentarDeNovo,
      );
    }
    return const SizedBox.shrink();
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem(
      {required this.texto, required this.acao, required this.aoTocar});

  final String texto;
  final String acao;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(texto,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted)),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: aoTocar, child: Text(acao)),
        ],
      ),
    );
  }
}
