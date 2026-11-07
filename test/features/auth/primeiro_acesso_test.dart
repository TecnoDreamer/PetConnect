// O primeiro acesso de cada instalação pede login; depois, a sessão fica
// guardada até "Sair da conta" (pedido do proprietário de 2026-11-04).
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/auth/application/primeiro_acesso.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> prefsCom(Map<String, Object> valores) async {
    SharedPreferences.setMockInitialValues(valores);
    return SharedPreferences.getInstance();
  }

  test('no primeiro acesso, encerra a sessão e grava a marca', () async {
    final prefs = await prefsCom({});
    var encerrou = 0;
    final acesso =
        PrimeiroAcesso(prefs: prefs, encerrarSessao: () async => encerrou++);

    await acesso.exigirLoginSeForOPrimeiro();

    expect(encerrou, 1);
    expect(prefs.getBool(PrimeiroAcesso.chave), isTrue);
  });

  test('nas aberturas seguintes, não encerra a sessão', () async {
    final prefs = await prefsCom({});
    var encerrou = 0;
    final acesso =
        PrimeiroAcesso(prefs: prefs, encerrarSessao: () async => encerrou++);

    await acesso.exigirLoginSeForOPrimeiro();
    await acesso.exigirLoginSeForOPrimeiro();
    await PrimeiroAcesso(prefs: prefs, encerrarSessao: () async => encerrou++)
        .exigirLoginSeForOPrimeiro();

    expect(encerrou, 1);
  });

  test('se o signOut falhar, não grava a marca e tenta de novo depois',
      () async {
    final prefs = await prefsCom({});
    var tentativas = 0;
    final acesso = PrimeiroAcesso(
      prefs: prefs,
      encerrarSessao: () async {
        tentativas++;
        if (tentativas == 1) throw Exception('falhou');
      },
    );

    await acesso.exigirLoginSeForOPrimeiro();
    expect(prefs.getBool(PrimeiroAcesso.chave), isNull);

    await acesso.exigirLoginSeForOPrimeiro();
    expect(tentativas, 2);
    expect(prefs.getBool(PrimeiroAcesso.chave), isTrue);
  });
}
