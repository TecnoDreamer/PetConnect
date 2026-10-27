import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/pet.dart';
import '../providers/galeria_providers.dart';
import '../providers/pet_providers.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/galeria_resumo.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pet_cover_image.dart';

/// Memorial de um pet falecido (ver docs/features/memorial-pet.md):
/// capa, foto, nome, informações básicas, homenagem e lembranças.
///
/// Não mostra nem carrega vacinas, consultas, histórico ou localização. A
/// única escrita possível daqui é adicionar fotos à galeria do pet. A rota é protegida
/// por `PetSituacaoGuard` (só pets falecidos do tutor autenticado).
class MemorialScreen extends ConsumerWidget {
  const MemorialScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final petAsync = ref.watch(petProvider(petId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Memorial'),
        actions: [
          IconButton(
            tooltip: 'Configurações do memorial',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/memorial/$petId/configuracoes'),
          ),
        ],
      ),
      body: SafeArea(
        child: petAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('Não foi possível carregar o memorial.',
                style: TextStyle(color: colors.error)),
          ),
          data: (pet) => pet == null
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Identidade(pet: pet),
                      const SizedBox(height: 20),
                      _InformacoesBasicas(pet: pet),
                      if (pet.homenagem != null &&
                          pet.homenagem!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _Homenagem(texto: pet.homenagem!),
                      ],
                      if (ref.watch(galeriaDisponivelProvider)) ...[
                        const SizedBox(height: 28),
                        GaleriaResumo(pet: pet),
                      ],
                      const SizedBox(height: 28),
                      MemorialGaleria(pet: pet),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Identidade extends StatelessWidget {
  const _Identidade({required this.pet});

  final Pet pet;

  static const _raioAvatar = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final periodo = [
      if (pet.dataNascimento.isNotEmpty) pet.dataNascimento,
      if (pet.dataFalecimento != null && pet.dataFalecimento!.isNotEmpty)
        pet.dataFalecimento!,
    ].join(' – ');

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            PetCoverImage(
              capaUrl: pet.capa,
              height: 140,
              borderRadius: BorderRadius.circular(24),
              alignmentY: pet.capaAlinhamentoY ?? 0,
            ),
            Positioned(
              bottom: -_raioAvatar,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.background,
                  shape: BoxShape.circle,
                ),
                child: PetAvatar(
                  fotoUrl: pet.foto,
                  radius: _raioAvatar,
                  nomeDoPet: pet.nome,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: _raioAvatar + 12),
        Text(
          'Em memória de',
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          pet.nome,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        if (periodo.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(periodo, style: TextStyle(color: colors.textMuted)),
        ],
      ],
    );
  }
}

class _InformacoesBasicas extends StatelessWidget {
  const _InformacoesBasicas({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final itens = [
      ('Espécie', pet.especie),
      ('Raça', pet.raca),
      ('Sexo', pet.genero),
      ('Cor', pet.cor),
    ].where((item) => item.$2.trim().isNotEmpty).toList();
    if (itens.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final (rotulo, valor) in itens)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child:
                        Text(rotulo, style: TextStyle(color: colors.textMuted)),
                  ),
                  Flexible(
                    child: Text(
                      valor,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
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

class _Homenagem extends StatelessWidget {
  const _Homenagem({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.textPrimary,
          fontStyle: FontStyle.italic,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Lembranças do pet: as imagens do próprio perfil (foto e capa). As fotos
/// da galeria aparecem acima, em [GaleriaResumo]; as anexadas ao histórico
/// médico são registros clínicos e ficam de fora do memorial.
class MemorialGaleria extends StatelessWidget {
  const MemorialGaleria({super.key, required this.pet});

  final Pet pet;

  static List<String> imagensDo(Pet pet) => {
        if (pet.foto != null && pet.foto!.isNotEmpty) pet.foto!,
        if (pet.capa != null && pet.capa!.isNotEmpty) pet.capa!,
      }.toList();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final imagens = imagensDo(pet);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lembranças',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (imagens.isEmpty)
          Text(
            'Ainda não há fotos de ${pet.nome}.',
            style: TextStyle(color: colors.textMuted),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (indice, url) in imagens.indexed)
                Semantics(
                  button: true,
                  label: 'Foto ${indice + 1} de ${pet.nome}. Toque para '
                      'ampliar.',
                  child: GestureDetector(
                    onTap: () => FullscreenImageViewer.open(
                      context,
                      imageUrl: url,
                      semanticLabel: 'Foto de ${pet.nome}',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        key: ValueKey('memorial-foto-$url'),
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            ColoredBox(color: colors.cardBackground),
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: colors.cardBackground,
                          child: Icon(Icons.broken_image_outlined,
                              color: colors.textMuted),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
