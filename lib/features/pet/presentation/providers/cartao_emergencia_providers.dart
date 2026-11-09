import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/firebase_cartao_emergencia_repository.dart';
import '../../domain/cartao_emergencia.dart';
import '../../domain/cartao_emergencia_repository.dart';

/// O Cartão de Emergência aparece no perfil do pet (issue #41). Desligado
/// até o deploy das regras; oculto no modo API, em que os pets não estão no
/// Firestore.
final cartaoEmergenciaDisponivelProvider = Provider<bool>(
  (ref) => AppConfig.cartaoEmergencia && !AppConfig.useApiForPets,
);

final cartaoEmergenciaRepositoryProvider =
    Provider<CartaoEmergenciaRepository>((ref) {
  return FirebaseCartaoEmergenciaRepository(
      firestore: ref.watch(firestoreProvider));
});

/// Cartão de um pet. `autoDispose`: os dados de saúde não ficam na memória
/// depois que a tela fecha. Depende do usuário logado, então trocar de conta
/// descarta a leitura anterior.
final cartaoEmergenciaProvider =
    StreamProvider.autoDispose.family<LeituraDoCartao, String>((ref, petId) {
  final uid =
      ref.watch(currentUsuarioProvider.select((s) => s.valueOrNull?.id));
  if (uid == null) return const Stream.empty();
  return ref.watch(cartaoEmergenciaRepositoryProvider).observar(petId);
});
