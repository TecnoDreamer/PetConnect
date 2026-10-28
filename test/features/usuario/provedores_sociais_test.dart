// Tradução das respostas dos SDKs do Google e do Facebook para os erros do
// domínio (docs/features/login-social.md), sem credenciais reais.
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pet_connect/features/usuario/data/provedores_sociais.dart';
import 'package:pet_connect/features/usuario/domain/login_social.dart';

class _FakeGoogle extends Fake implements GoogleSignIn {
  int inicializacoes = 0;
  Object? erroAoInicializar;
  bool suporta = true;
  Object? erroAoAutenticar;
  int saidas = 0;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    inicializacoes++;
    if (erroAoInicializar != null) throw erroAoInicializar!;
  }

  @override
  bool supportsAuthenticate() => suporta;

  @override
  Future<GoogleSignInAccount> authenticate(
      {List<String> scopeHint = const <String>[]}) async {
    throw erroAoAutenticar ??
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
  }

  @override
  Future<void> signOut() async => saidas++;
}

class _FakeFacebook extends Fake implements FacebookAuth {
  LoginResult? resultado;
  Object? erro;
  List<String>? permissoesPedidas;
  int saidas = 0;

  @override
  Future<LoginResult> login({
    List<String> permissions = const ['email', 'public_profile'],
    LoginBehavior loginBehavior = LoginBehavior.nativeWithFallback,
    LoginTracking loginTracking = LoginTracking.limited,
    String? nonce,
  }) async {
    permissoesPedidas = permissions;
    if (erro != null) throw erro!;
    return resultado!;
  }

  @override
  Future<void> logOut() async => saidas++;
}

void main() {
  group('Google', () {
    late _FakeGoogle sdk;
    late GoogleProvedorDeCredencial provedor;

    setUp(() {
      sdk = _FakeGoogle();
      provedor = GoogleProvedorDeCredencial(googleSignIn: sdk);
    });

    Future<Object?> erroAoEntrar() => provedor
        .obterCredencial()
        .then<Object?>((_) => null, onError: (Object e) => e);

    test('tutor fecha o seletor de conta: cancelado', () async {
      expect(await erroAoEntrar(), isA<LoginSocialCancelado>());
    });

    for (final codigo in [
      GoogleSignInExceptionCode.clientConfigurationError,
      GoogleSignInExceptionCode.providerConfigurationError,
      GoogleSignInExceptionCode.uiUnavailable,
    ]) {
      test('${codigo.name} (sem configuração no Console): indisponível',
          () async {
        sdk.erroAoAutenticar = GoogleSignInException(code: codigo);
        expect(await erroAoEntrar(), isA<LoginSocialIndisponivel>());
      });
    }

    test('interrompido (ex.: rede): falhou, dá para tentar de novo', () async {
      sdk.erroAoAutenticar = const GoogleSignInException(
          code: GoogleSignInExceptionCode.interrupted);
      expect(await erroAoEntrar(), isA<LoginSocialFalhou>());
    });

    test('aparelho sem suporte ao fluxo: indisponível', () async {
      sdk.suporta = false;
      expect(await erroAoEntrar(), isA<LoginSocialIndisponivel>());
    });

    test('inicializa uma vez só e tenta de novo se a inicialização falhou',
        () async {
      sdk.erroAoInicializar = PlatformException(code: 'sem-rede');
      expect(await erroAoEntrar(), isA<LoginSocialFalhou>());

      sdk.erroAoInicializar = null;
      await erroAoEntrar();
      await erroAoEntrar();
      expect(sdk.inicializacoes, 2);
    });

    test('sair antes de qualquer login não chama o SDK', () async {
      await provedor.sair();
      expect(sdk.saidas, 0);

      await erroAoEntrar();
      await provedor.sair();
      expect(sdk.saidas, 1);
    });
  });

  group('Facebook', () {
    late _FakeFacebook sdk;
    late FacebookProvedorDeCredencial provedor;

    setUp(() {
      sdk = _FakeFacebook();
      provedor = FacebookProvedorDeCredencial(facebookAuth: sdk);
    });

    Future<Object?> erroAoEntrar() => provedor
        .obterCredencial()
        .then<Object?>((_) => null, onError: (Object e) => e);

    test('sucesso: credencial do Facebook, pedindo só e-mail e perfil público',
        () async {
      sdk.resultado = LoginResult(
        status: LoginStatus.success,
        accessToken: ClassicToken(
          declinedPermissions: const [],
          grantedPermissions: const ['email', 'public_profile'],
          userId: 'fb-1',
          expires: DateTime(2030),
          tokenString: 'token-teste',
          applicationId: 'app-teste',
        ),
      );

      final credencial = await provedor.obterCredencial();

      expect(credencial.providerId, 'facebook.com');
      expect(sdk.permissoesPedidas, ['email', 'public_profile']);
    });

    test('cancelado pelo tutor', () async {
      sdk.resultado = LoginResult(status: LoginStatus.cancelled);
      expect(await erroAoEntrar(), isA<LoginSocialCancelado>());
    });

    test('falha do SDK ou login já em andamento: falhou', () async {
      for (final status in [
        LoginStatus.failed,
        LoginStatus.operationInProgress
      ]) {
        sdk.resultado = LoginResult(status: status);
        expect(await erroAoEntrar(), isA<LoginSocialFalhou>(),
            reason: '$status');
      }
    });

    test('sucesso sem token: falhou', () async {
      sdk.resultado = LoginResult(status: LoginStatus.success);
      expect(await erroAoEntrar(), isA<LoginSocialFalhou>());
    });

    test('SDK sem App ID no build: indisponível', () async {
      sdk.erro = PlatformException(code: 'FAILED');
      expect(await erroAoEntrar(), isA<LoginSocialIndisponivel>());
    });

    test('sair chama o logout do SDK', () async {
      await provedor.sair();
      expect(sdk.saidas, 1);
    });
  });
}
