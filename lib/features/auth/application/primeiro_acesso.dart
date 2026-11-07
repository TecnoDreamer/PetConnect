import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/theme_providers.dart';
import '../../usuario/presentation/providers/auth_providers.dart';

/// Exige login no primeiro acesso desta instalação do app (pedido do
/// proprietário de 2026-11-04). Depois dele, a sessão fica guardada no
/// aparelho até "Sair da conta".
///
/// Também vale para quem atualiza de uma versão que pedia login a cada
/// abertura: a sessão que ficou dela é encerrada uma vez, e o tutor entra de
/// novo.
///
/// A marca fica nas preferências do app, que o Android apaga ao desinstalar.
/// Se o Android restaurar um backup na reinstalação, a sessão e a marca
/// voltam juntas e o app entra direto.
class PrimeiroAcesso {
  PrimeiroAcesso({
    required SharedPreferences prefs,
    required Future<void> Function() encerrarSessao,
  })  : _prefs = prefs,
        _encerrarSessao = encerrarSessao;

  static const chave = 'sessao_primeiro_acesso_feito_v1';

  final SharedPreferences _prefs;
  final Future<void> Function() _encerrarSessao;

  /// Chamado pela splash antes de ler a sessão. Só encerra a sessão uma vez:
  /// a marca é gravada depois que o `signOut()` deu certo, e uma falha tenta
  /// de novo na próxima abertura em vez de travar a splash.
  Future<void> exigirLoginSeForOPrimeiro() async {
    if (_prefs.getBool(chave) == true) return;
    try {
      await _encerrarSessao();
      await _prefs.setBool(chave, true);
    } catch (_) {}
  }
}

final primeiroAcessoProvider = Provider<PrimeiroAcesso>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return PrimeiroAcesso(
    prefs: ref.watch(sharedPreferencesProvider),
    encerrarSessao: auth.signOut,
  );
});
