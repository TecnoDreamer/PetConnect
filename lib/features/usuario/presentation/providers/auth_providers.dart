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

/// Google (docs/features/login-social.md). Sem a configuração do Firebase
/// (cliente OAuth no google-services.json), o botão avisa que o login ainda
/// não está disponível em vez de quebrar.
final provedoresSociaisProvider =
    Provider<Map<ProvedorSocial, ProvedorDeCredencial>>((ref) => {
          ProvedorSocial.google: GoogleProvedorDeCredencial(
              serverClientId: AppConfig.googleServerClientId),
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
///
/// O FirebaseAuth guarda a sessão no aparelho: fechar e reabrir o app volta
/// direto para a Home. A sessão só termina em "Sair da conta", com
/// confirmação (decisão do proprietário de 2026-11-04, que substitui o login
/// obrigatório a cada abertura). O primeiro acesso de cada instalação pede
/// login (`PrimeiroAcesso`).
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
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
