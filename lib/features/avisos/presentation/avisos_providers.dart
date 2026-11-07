import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../usuario/presentation/providers/auth_providers.dart';
import '../application/avisos_do_qr.dart';
import '../data/api_avisos_repository.dart';
import '../data/fcm_push_do_aparelho.dart';
import '../domain/aviso_do_qr.dart';

/// Avisos do QR por push (issue #36). Só existem com a API configurada
/// (`USE_API_QR` ou `USE_API_PETS`): é ela que envia o push. Sem ela, `null`
/// e o app não toca no Firebase Messaging.
final avisosRepositoryProvider = Provider<AvisosRepository?>((ref) {
  if (!AppConfig.useApiForPets && !AppConfig.useApiForQr) return null;
  return ApiAvisosRepository(
    api: ref.watch(apiClientProvider),
    porIdDoFirestore: !AppConfig.useApiForPets,
  );
});

final pushDoAparelhoProvider = Provider<PushDoAparelho?>((ref) {
  if (ref.watch(avisosRepositoryProvider) == null) return null;
  return FcmPushDoAparelho();
});

final avisosDoQrProvider = Provider<AvisosDoQr?>((ref) {
  final repo = ref.watch(avisosRepositoryProvider);
  final push = ref.watch(pushDoAparelhoProvider);
  if (repo == null || push == null) return null;
  final avisos = AvisosDoQr(
    push: push,
    repository: repo,
    petsNaApi: AppConfig.useApiForPets,
  );
  ref.onDispose(avisos.encerrar);
  return avisos;
});

/// Preferências de aviso de um pet, para a tela de compartilhamento.
final preferenciasDeAvisoProvider = FutureProvider.autoDispose
    .family<PreferenciasDeAviso?, String>((ref, petId) async {
  final repo = ref.watch(avisosRepositoryProvider);
  if (repo == null) return null;
  return repo.preferencias(petId);
});

/// Situação da permissão de notificação do sistema, `null` sem push.
final permissaoDeAvisoProvider =
    FutureProvider.autoDispose<PermissaoDeAviso?>((ref) async {
  final push = ref.watch(pushDoAparelhoProvider);
  if (push == null) return null;
  return push.permissao();
});
