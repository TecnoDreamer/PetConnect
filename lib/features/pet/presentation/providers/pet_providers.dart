import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/api_pet_repository.dart';
import '../../data/firebase_pet_repository.dart';
import '../../domain/pet.dart';
import '../../domain/pet_repository.dart';

final petRepositoryProvider = Provider<PetRepository>((ref) {
  if (AppConfig.useApiForPets) {
    return ApiPetRepository(
      auth: ref.watch(firebaseAuthProvider),
      api: ref.watch(apiClientProvider),
    );
  }
  return FirebasePetRepository(firestore: ref.watch(firestoreProvider));
});

/// Pets do tutor autenticado (RF11). Vazio (sem emitir erro) enquanto
/// deslogado — a rota já redireciona para o login nesse caso.
///
/// Depende de [currentUsuarioProvider] (não de [authStateChangesProvider]
/// diretamente) porque `Usuario.id` já é o uid do Firebase Auth (ver
/// docs/modelo-dados-firestore.md) e é um tipo simples de fake em testes,
/// ao contrário do `User` do pacote firebase_auth.
///
/// Com [AppConfig.useApiForPets] a fonte é `GET /api/v1/pets` (emissão
/// única); as telas chamam `ref.invalidate(petsProvider)` após mutações e a
/// Home tem pull-to-refresh.
final petsProvider = StreamProvider<List<Pet>>((ref) {
  final usuario = ref.watch(currentUsuarioProvider).valueOrNull;
  if (usuario == null) return Stream.value(const []);
  return ref.watch(petRepositoryProvider).watchPets(usuario.id);
});

/// Um pet específico pelo id (RF15). `family` porque a tela de detalhe/edição
/// é reaberta com um id diferente a cada navegação.
final petProvider = StreamProvider.family<Pet?, String>((ref, petId) {
  return ref.watch(petRepositoryProvider).watchPet(petId);
});

/// Pets ativos do tutor (lista principal da Home). Derivado de
/// [petsProvider] — mesma consulta, sem buscar nada a mais para separar
/// ativos de falecidos.
final petsAtivosProvider = Provider<AsyncValue<List<Pet>>>((ref) {
  return ref
      .watch(petsProvider)
      .whenData((pets) => pets.where((pet) => !pet.falecido).toList());
});

/// Pets falecidos do tutor (seção Memorial). Mesma origem de
/// [petsAtivosProvider].
final petsFalecidosProvider = Provider<AsyncValue<List<Pet>>>((ref) {
  return ref
      .watch(petsProvider)
      .whenData((pets) => pets.where((pet) => pet.falecido).toList());
});
