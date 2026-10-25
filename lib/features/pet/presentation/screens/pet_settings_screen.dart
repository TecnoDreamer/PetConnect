import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/upload_error.dart';
import '../../../../core/widgets/settings_menu_tile.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/pet.dart';
import '../providers/anexo_providers.dart';
import '../providers/pet_providers.dart';
import '../widgets/cover_position_editor.dart';
import '../widgets/pet_cover_image.dart';

const _tamanhoMaximoCapa = 5 * 1024 * 1024; // 5MB — ver docs/seguranca.md.

/// Configurações de um pet específico — nunca do tutor. Corrige o bug em
/// que "Configurações" no perfil do pet abria a tela de conta do tutor
/// (prompt_correcao_configuracoes_perfil_pet.md, 2026-09-13): esta tela
/// recebe o [petId] e mantém esse contexto o tempo todo, então
/// "Configurações da Felícia" nunca mostra ou mexe nos dados do Aleks (ou
/// do tutor).
///
/// Editar e excluir, que antes ficavam expostos na tela principal do
/// perfil, moram só aqui agora. Menu padronizado (ver
/// docs/features/theme-and-settings-menu.md) — a seção de capa foge do
/// padrão ícone+título+chevron de propósito, por não ser uma navegação
/// simples (tem prévia visual e mais de uma ação).
class PetSettingsScreen extends ConsumerStatefulWidget {
  const PetSettingsScreen({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<PetSettingsScreen> createState() => _PetSettingsScreenState();
}

class _PetSettingsScreenState extends ConsumerState<PetSettingsScreen> {
  bool _enviandoCapa = false;
  bool _removendoCapa = false;
  bool _salvandoPosicao = false;
  bool _excluindo = false;
  String? _error;

  bool get _ocupadoComCapa =>
      _enviandoCapa || _removendoCapa || _salvandoPosicao;

  Future<void> _alterarCapa(Pet pet) async {
    final arquivo = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (arquivo == null) return;

    final bytes = await arquivo.readAsBytes();
    if (bytes.length > _tamanhoMaximoCapa) {
      setState(() => _error = 'A foto excede o tamanho máximo de 5MB.');
      return;
    }

    final uid = ref.read(currentUsuarioProvider).valueOrNull?.id;
    if (uid == null) return;

    setState(() {
      _error = null;
      _enviandoCapa = true;
    });

    final anexos = ref.read(anexoRepositoryProvider);
    final capaAntiga = pet.capa;
    late final String url;

    try {
      final path =
          'pets/capas/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      url = await anexos.upload(
          path: path, bytes: bytes, contentType: 'image/jpeg');
      // Foto nova recentraliza o alinhamento — a posição antiga não faz
      // sentido pra uma imagem diferente.
      await ref
          .read(petRepositoryProvider)
          .updatePet(pet.copyWith(capa: url, capaAlinhamentoY: 0));

      // Limpeza best-effort da capa antiga — não impede a troca se falhar
      // (mesmo comportamento tolerante já usado em histórico médico).
      if (capaAntiga != null && capaAntiga.isNotEmpty) {
        unawaited(anexos.delete(capaAntiga));
      }

      ref.invalidate(petProvider(pet.id));
      ref.invalidate(petsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _error = describirErroUpload(e, item: 'a capa'));
      }
      return;
    } finally {
      if (mounted) setState(() => _enviandoCapa = false);
    }

    // Convite direto pra já ajustar a posição da foto recém-enviada —
    // mesmo padrão de apps que têm editor de capa (Facebook/Instagram).
    // capaAlinhamentoY explícito aqui (não só no updatePet acima): sem
    // isso, o editor abriria com o alinhamento da capa ANTERIOR, já que
    // copyWith preserva o valor do `pet` local quando não informado.
    if (mounted) {
      await _ajustarPosicaoCapa(pet.copyWith(capa: url, capaAlinhamentoY: 0));
    }
  }

  Future<void> _ajustarPosicaoCapa(Pet pet) async {
    final capaAtual = pet.capa;
    if (capaAtual == null || capaAtual.isEmpty) return;

    final novoAlinhamento = await CoverPositionEditor.open(
      context,
      imageUrl: capaAtual,
      alinhamentoInicial: pet.capaAlinhamentoY ?? 0,
    );
    if (novoAlinhamento == null || !mounted) return; // voltou sem salvar

    setState(() {
      _error = null;
      _salvandoPosicao = true;
    });

    try {
      await ref
          .read(petRepositoryProvider)
          .updatePet(pet.copyWith(capaAlinhamentoY: novoAlinhamento));
      ref.invalidate(petProvider(pet.id));
      ref.invalidate(petsProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível salvar a posição da capa. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _salvandoPosicao = false);
    }
  }

  Future<void> _removerCapa(Pet pet) async {
    final capaAtual = pet.capa;
    if (capaAtual == null || capaAtual.isEmpty) return;

    setState(() {
      _error = null;
      _removendoCapa = true;
    });

    try {
      // String vazia (não null) limpa o campo de verdade — ver
      // UpdatePetRequest no backend (null = não altera).
      await ref.read(petRepositoryProvider).updatePet(pet.copyWith(capa: ''));
      unawaited(ref.read(anexoRepositoryProvider).delete(capaAtual));
      ref.invalidate(petProvider(pet.id));
      ref.invalidate(petsProvider);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Não foi possível remover a capa. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _removendoCapa = false);
    }
  }

  Future<void> _confirmarExclusao(Pet pet) async {
    final colors = context.colors;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir perfil do pet'),
        content: Text(
            'Excluir o perfil de ${pet.nome}? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Excluir', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );

    if (confirmou != true || _excluindo) return;

    setState(() => _excluindo = true);

    try {
      await ref.read(petRepositoryProvider).deletePet(pet.id);
      ref.invalidate(petsProvider);
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        setState(() => _excluindo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Não foi possível excluir o pet. Tente novamente.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petProvider(widget.petId));
    final pet = petAsync.valueOrNull;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(pet != null
            ? 'Configurações de ${pet.nome}'
            : 'Configurações do Pet'),
      ),
      body: SafeArea(
        child: petAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('Não foi possível carregar este pet.',
                style: TextStyle(color: colors.error)),
          ),
          data: (pet) {
            if (pet == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Pet não encontrado.',
                      style: TextStyle(color: colors.textMuted)),
                ),
              );
            }

            final temCapa = pet.capa != null && pet.capa!.isNotEmpty;

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const SettingsSectionHeader(title: 'Perfil'),
                SettingsMenuTile(
                  icon: Icons.edit_outlined,
                  title: 'Editar perfil',
                  onTap: () =>
                      context.push('/pet/${pet.id}/editar', extra: pet),
                ),
                const SettingsSectionHeader(title: 'Foto de capa'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PetCoverImage(
                      capaUrl: pet.capa,
                      height: 100,
                      alignmentY: pet.capaAlinhamentoY ?? 0,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, temCapa ? 8 : 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _ocupadoComCapa ? null : () => _alterarCapa(pet),
                          icon: _enviandoCapa
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.image_outlined),
                          label: Text(temCapa ? 'Alterar' : 'Adicionar capa'),
                        ),
                      ),
                      if (temCapa) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _ocupadoComCapa
                                ? null
                                : () => _removerCapa(pet),
                            icon: _removendoCapa
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: colors.error),
                                  )
                                : Icon(Icons.delete_outline,
                                    color: colors.error),
                            label: Text('Remover',
                                style: TextStyle(color: colors.error)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (temCapa)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: OutlinedButton.icon(
                      onPressed: _ocupadoComCapa
                          ? null
                          : () => _ajustarPosicaoCapa(pet),
                      icon: _salvandoPosicao
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.control_camera_outlined),
                      label: const Text('Ajustar posição'),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(_error!,
                        style: TextStyle(color: colors.error, fontSize: 13)),
                  ),
                if (ref.watch(petRepositoryProvider).suportaMemorial) ...[
                  const SettingsSectionHeader(title: 'Memorial'),
                  SettingsMenuTile(
                    icon: Icons.local_florist_outlined,
                    title: 'Registrar falecimento',
                    onTap: () => context.push('/pet/${pet.id}/falecimento'),
                  ),
                ],
                const SettingsSectionHeader(title: 'Conta'),
                SettingsMenuTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Excluir perfil do pet',
                  isDestructive: true,
                  isEnabled: !_excluindo,
                  trailing: _excluindo
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: colors.error),
                        )
                      : null,
                  onTap: () => _confirmarExclusao(pet),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
