import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../data/api_usuario_repository.dart';
import '../../data/firebase_usuario_repository.dart';
import '../../data/provedores_sociais.dart';
import '../../domain/login_social.dart';
import '../../domain/usuario.dart';
import '../../domain/usuario_repository.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Cliente da API Spring. Anexa o Firebase ID Token do usuário logado.
final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final client = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    getToken: () async => auth.currentUser?.getIdToken(),
  );
  ref.onDispose(client.close);
  return client;
});

/// Google e Facebook (docs/features/login-social.md). Sem a configuração do
/// Console (Firebase, Google Cloud, Meta), os botões avisam que o login
/// ainda não está disponível em vez de quebrar.
final provedoresSociaisProvider =
    Provider<Map<ProvedorSocial, ProvedorDeCredencial>>((ref) => {
          ProvedorSocial.google: GoogleProvedorDeCredencial(
              serverClientId: AppConfig.googleServerClientId),
          ProvedorSocial.facebook: FacebookProvedorDeCredencial(),
        });

final usuarioRepositoryProvider = Provider<UsuarioRepository>((ref) {
  if (AppConfig.useApiForUsuario) {
    return ApiUsuarioRepository(
      auth: ref.watch(firebaseAuthProvider),
      api: ref.watch(apiClientProvider),
      provedores: ref.watch(provedoresSociaisProvider),
    );
  }
  return FirebaseUsuarioRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    provedores: ref.watch(provedoresSociaisProvider),
  );
});

/// Sessão do Firebase Auth (null = deslogado). Usado pelo guard de rotas.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Garante login explícito a cada abertura do app: mesmo com uma sessão do
/// Firebase Auth persistida no aparelho de uma vez anterior, o tutor deve
/// informar as credenciais de novo (decisão de produto pós-validação física
/// — por padrão o FirebaseAuth mantém a sessão entre reaberturas, o que
/// levaria direto pra Home sem pedir login).
///
/// Roda uma única vez, na [SplashScreen], e precisa terminar **antes** de
/// [authStateChangesProvider] ser lido pela primeira vez — senão a Home
/// chegaria a aparecer por um instante antes do redirect corrigir.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  try {
    await ref.watch(firebaseAuthProvider).signOut();
  } catch (_) {
    // Mesmo se o signOut falhar (ex.: sem rede no momento exato da
    // abertura), a splash não deve travar esperando por isso — ela decide
    // o destino pelo estado de auth de qualquer forma logo em seguida.
  }
});

/// Perfil do usuário logado, combinando com o estado de autenticação — null
/// enquanto deslogado ou se o perfil ainda não existir.
///
/// Com [AppConfig.useApiForUsuario], a fonte é `GET /api/v1/me` (emissão
/// única); telas que editam o perfil chamam `ref.invalidate` para recarregar.
final currentUsuarioProvider = StreamProvider<Usuario?>((ref) async* {
  final auth = ref.watch(firebaseAuthProvider);
  final repository = ref.watch(usuarioRepositoryProvider);

  await for (final user in auth.authStateChanges()) {
    if (user == null) {
      yield null;
    } else {
      yield* repository.watchUsuario(user.uid);
    }
  }
});
