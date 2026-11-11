import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/theme_providers.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/api_limpeza_na_api.dart';
import '../../domain/limpeza_na_api.dart';

/// Limpeza, na API, do que ela guarda de pets do Firestore e da conta
/// (LGPD). Só com pets no Firestore e a API ligada para o QR
/// (`USE_API_QR=true`): sem API não há o que limpar lá, e com
/// `USE_API_PETS=true` a exclusão na API já apaga em cascata.
final limpezaNaApiProvider = Provider<LimpezaNaApi?>((ref) {
  if (AppConfig.useApiForPets || !AppConfig.useApiForQr) return null;
  final auth = ref.watch(firebaseAuthProvider);
  return ApiLimpezaNaApi(
    api: ref.watch(apiClientProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    uidAtual: () => auth.currentUser?.uid,
  );
});
