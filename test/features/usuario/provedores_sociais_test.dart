// Tradução das respostas do SDK do Google para os erros do domínio
// (docs/features/login-social.md), sem credenciais reais.
import 'package:flutter/services.dart';
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
}
