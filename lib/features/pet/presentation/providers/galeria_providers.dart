import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/firebase_galeria_repository.dart';
import '../../domain/foto_pet.dart';
import '../../domain/galeria_repository.dart';
import 'anexo_providers.dart';

/// Galeria de fotos por pet (docs/features/galeria-fotos-pet.md). Os
/// arquivos vão pelo mesmo [anexoRepositoryProvider] das fotos de perfil.
final galeriaRepositoryProvider = Provider<GaleriaRepository>((ref) {
  return FirebaseGaleriaRepository(
    firestore: ref.watch(firestoreProvider),
    arquivos: ref.watch(anexoRepositoryProvider),
  );
});

/// Se a galeria aparece no app. Ver [AppConfig.galeriaFotos]: desligada
/// até o deploy das regras do Firestore, e oculta no modo API (os pets
/// ficam no MongoDB, que ainda não tem galeria).
final galeriaDisponivelProvider = Provider<bool>(
  (ref) => AppConfig.galeriaFotos && !AppConfig.useApiForPets,
);

class GaleriaEstado {
  const GaleriaEstado({
    this.fotos = const [],
    this.carregando = false,
    this.carregandoMais = false,
    this.temMais = false,
    this.erro = false,
  });

  final List<FotoPet> fotos;

  /// Primeira página.
  final bool carregando;
  final bool carregandoMais;
  final bool temMais;

  /// A última leitura falhou (primeira página ou seguinte).
  final bool erro;

  GaleriaEstado copyWith({
    List<FotoPet>? fotos,
    bool? carregando,
    bool? carregandoMais,
    bool? temMais,
    bool? erro,
  }) =>
      GaleriaEstado(
        fotos: fotos ?? this.fotos,
        carregando: carregando ?? this.carregando,
        carregandoMais: carregandoMais ?? this.carregandoMais,
        temMais: temMais ?? this.temMais,
        erro: erro ?? this.erro,
      );
}

/// Fotos carregadas de um pet, página por página. Compartilhado pela grade,
/// pelo visualizador e pelo resumo do Memorial, que leem a mesma lista.
class GaleriaController extends StateNotifier<GaleriaEstado> {
  GaleriaController(this._repositorio, this.petId)
      : super(const GaleriaEstado(carregando: true)) {
    recarregar();
  }

  final GaleriaRepository _repositorio;
  final String petId;

  Future<void> recarregar() async {
    state = state.copyWith(carregando: true, erro: false);
    try {
      final pagina = await _repositorio.listar(petId);
      if (!mounted) return;
      state = GaleriaEstado(fotos: pagina.fotos, temMais: pagina.temMais);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(carregando: false, erro: true);
    }
  }

  Future<void> carregarMais() async {
    if (state.carregando || state.carregandoMais || !state.temMais) return;
    if (state.fotos.isEmpty) return;
    state = state.copyWith(carregandoMais: true, erro: false);
    try {
      final pagina =
          await _repositorio.listar(petId, depoisDe: state.fotos.last);
      if (!mounted) return;
      final ids = {for (final foto in state.fotos) foto.id};
      state = state.copyWith(
        fotos: [
          ...state.fotos,
          ...pagina.fotos.where((foto) => !ids.contains(foto.id)),
        ],
        temMais: pagina.temMais,
        carregandoMais: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(carregandoMais: false, erro: true);
    }
  }

  /// Fotos recém-publicadas entram no topo, sem recarregar tudo.
  void inserir(List<FotoPet> novas) {
    if (novas.isEmpty) return;
    final ids = {for (final foto in novas) foto.id};
    state = state.copyWith(fotos: [
      ...novas.reversed,
      ...state.fotos.where((foto) => !ids.contains(foto.id)),
    ]);
  }

  /// Lança [FalhaAoExcluirFoto] (ou o erro do Firestore) se não excluir;
  /// nesse caso a foto continua na lista.
  Future<void> excluir(FotoPet foto) async {
    await _repositorio.excluir(foto);
    if (!mounted) return;
    state = state.copyWith(
      fotos: state.fotos.where((f) => f.id != foto.id).toList(),
    );
  }
}

final galeriaControllerProvider = StateNotifierProvider.autoDispose
    .family<GaleriaController, GaleriaEstado, String>((ref, petId) {
  return GaleriaController(ref.watch(galeriaRepositoryProvider), petId);
});
