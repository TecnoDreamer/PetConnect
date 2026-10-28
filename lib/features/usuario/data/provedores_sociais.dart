import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/login_social.dart';

/// Obtém do provedor (Google, Facebook) a credencial que o Firebase Auth
/// aceita. Lança [LoginSocialCancelado], [LoginSocialIndisponivel] ou
/// [LoginSocialFalhou]; nunca expõe o token fora daqui.
abstract class ProvedorDeCredencial {
  ProvedorSocial get provedor;

  Future<AuthCredential> obterCredencial();

  /// Encerra a sessão do SDK do provedor, para o próximo login mostrar de
  /// novo a escolha de conta. Falhas são ignoradas.
  Future<void> sair();
}

/// Google Sign-In 7 (Credential Manager no Android). O `serverClientId` (ID
/// do cliente **web** do projeto) vem do `google-services.json` ou, se
/// informado, de `--dart-define=GOOGLE_SERVER_CLIENT_ID`.
class GoogleProvedorDeCredencial implements ProvedorDeCredencial {
  GoogleProvedorDeCredencial(
      {GoogleSignIn? googleSignIn, String? serverClientId})
      : _google = googleSignIn ?? GoogleSignIn.instance,
        _serverClientId = (serverClientId == null || serverClientId.isEmpty)
            ? null
            : serverClientId;

  final GoogleSignIn _google;
  final String? _serverClientId;
  Future<void>? _inicializacao;

  @override
  ProvedorSocial get provedor => ProvedorSocial.google;

  // `initialize` só pode rodar uma vez; se falhar, a próxima tentativa
  // inicializa de novo.
  Future<void> _inicializar() {
    return _inicializacao ??=
        _google.initialize(serverClientId: _serverClientId).catchError(
      (Object erro) {
        _inicializacao = null;
        throw erro;
      },
    );
  }

  @override
  Future<AuthCredential> obterCredencial() async {
    try {
      await _inicializar();
      if (!_google.supportsAuthenticate()) {
        throw const LoginSocialIndisponivel(ProvedorSocial.google);
      }
      final conta = await _google.authenticate();
      final idToken = conta.authentication.idToken;
      if (idToken == null) {
        throw const LoginSocialIndisponivel(ProvedorSocial.google);
      }
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      throw switch (e.code) {
        GoogleSignInExceptionCode.canceled =>
          const LoginSocialCancelado(ProvedorSocial.google),
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError ||
        GoogleSignInExceptionCode.uiUnavailable =>
          LoginSocialIndisponivel(ProvedorSocial.google, e.code),
        _ => LoginSocialFalhou(ProvedorSocial.google, e.code),
      };
    } on PlatformException catch (e) {
      throw LoginSocialFalhou(ProvedorSocial.google, e.code);
    }
  }

  @override
  Future<void> sair() async {
    try {
      if (_inicializacao == null) return;
      await _inicializacao;
      await _google.signOut();
    } catch (_) {}
  }
}

/// Facebook Login. Pede só `email` e `public_profile`. Sem o app do
/// Facebook instalado, o SDK abre o login no navegador.
class FacebookProvedorDeCredencial implements ProvedorDeCredencial {
  FacebookProvedorDeCredencial({FacebookAuth? facebookAuth})
      : _facebook = facebookAuth ?? FacebookAuth.instance;

  final FacebookAuth _facebook;

  @override
  ProvedorSocial get provedor => ProvedorSocial.facebook;

  @override
  Future<AuthCredential> obterCredencial() async {
    final LoginResult resultado;
    try {
      resultado =
          await _facebook.login(permissions: const ['email', 'public_profile']);
    } on PlatformException catch (e) {
      // Sem App ID / Client Token no build, o SDK nem chega a abrir.
      throw LoginSocialIndisponivel(ProvedorSocial.facebook, e.code);
    } on MissingPluginException catch (e) {
      throw LoginSocialIndisponivel(ProvedorSocial.facebook, e);
    }

    switch (resultado.status) {
      case LoginStatus.success:
        final token = resultado.accessToken?.tokenString;
        if (token == null || token.isEmpty) {
          throw const LoginSocialFalhou(ProvedorSocial.facebook);
        }
        return FacebookAuthProvider.credential(token);
      case LoginStatus.cancelled:
        throw const LoginSocialCancelado(ProvedorSocial.facebook);
      case LoginStatus.operationInProgress:
      case LoginStatus.failed:
        throw LoginSocialFalhou(ProvedorSocial.facebook, resultado.status);
    }
  }

  @override
  Future<void> sair() async {
    try {
      await _facebook.logOut();
    } catch (_) {}
  }
}
