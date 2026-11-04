import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/api_atividade_do_qr_repository.dart';
import '../../data/api_localizacao_repository.dart';
import '../../data/firebase_localizacao_repository.dart';
import '../../domain/atividade_do_qr.dart';
import '../../domain/localizacao.dart';
import '../../domain/localizacao_repository.dart';

final localizacaoRepositoryProvider = Provider<LocalizacaoRepository>((ref) {
  if (AppConfig.useApiForLocalizacao) {
    return ApiLocalizacaoRepository(api: ref.watch(apiClientProvider));
  }
  return FirebaseLocalizacaoRepository(firestore: ref.watch(firestoreProvider));
});

/// Registros de localização de um pet (RF32). `family` porque cada perfil
/// de pet observa a própria lista.
///
/// Com [AppConfig.useApiForLocalizacao] a fonte é
/// `GET /api/v1/pets/{petId}/locations` (emissão única, inclui o histórico
/// migrado do Firestore); as telas chamam
/// `ref.invalidate(localizacoesProvider(petId))` após registrar um novo
/// avistamento e a lista tem pull-to-refresh.
final localizacoesProvider =
    StreamProvider.family<List<Localizacao>, String>((ref, petId) {
  return ref.watch(localizacaoRepositoryProvider).watchLocalizacoes(petId);
});

/// Relatos e acessos da página pública do QR (issue #37). Ficam na API, então
/// só existe com ela configurada (`USE_API_QR` ou `USE_API_PETS`); sem ela,
/// `null` e a aba mostra só os registros do próprio tutor.
final atividadeDoQrRepositoryProvider =
    Provider<AtividadeDoQrRepository?>((ref) {
  if (AppConfig.useApiForPets) {
    return ApiAtividadeDoQrRepository(
      api: ref.watch(apiClientProvider),
      porIdDoFirestore: false,
    );
  }
  if (AppConfig.useApiForQr) {
    return ApiAtividadeDoQrRepository(
      api: ref.watch(apiClientProvider),
      porIdDoFirestore: true,
    );
  }
  return null;
});

/// Busca única: a tela atualiza ao abrir, ao puxar para baixo e quando chega
/// um aviso do QR.
final atividadeDoQrProvider =
    FutureProvider.family<AtividadeDoQr?, String>((ref, petId) async {
  final repo = ref.watch(atividadeDoQrRepositoryProvider);
  if (repo == null) return null;
  return repo.buscar(petId);
});
